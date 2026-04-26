#include "nixse.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/utsname.h>
#include <curl/curl.h>
#include <json-c/json.h>

#define HYDRA_URL "https://hydra.nixos.org"
#define SEARCH_URL_PREFIX "https://search.nixos.org/backend/latest-45-nixos-"

static size_t write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    char **buffer = (char **)userp;
    char *ptr = realloc(*buffer, strlen(*buffer) + realsize + 1);
    if (!ptr) {
        return 0;
    }
    *buffer = ptr;
    memcpy((*buffer) + strlen(*buffer), contents, realsize);
    (*buffer)[strlen(*buffer) + realsize] = '\0';
    return realsize;
}

static char *base64_encode(const char *input) {
    static const char b64_table[] = 
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    size_t input_len = strlen(input);
    size_t output_len = ((input_len + 2) / 3) * 4;
    char *output = malloc(output_len + 1);
    if (!output) return NULL;
    
    size_t i = 0, j = 0;
    while (i < input_len) {
        unsigned int octet_a = i < input_len ? (unsigned char)input[i++] : 0;
        unsigned int octet_b = i < input_len ? (unsigned char)input[i++] : 0;
        unsigned int octet_c = i < input_len ? (unsigned char)input[i++] : 0;
        
        unsigned int triple = (octet_a << 16) + (octet_b << 8) + octet_c;
        
        output[j++] = b64_table[(triple >> 18) & 0x3F];
        output[j++] = b64_table[(triple >> 12) & 0x3F];
        output[j++] = b64_table[(triple >> 6) & 0x3F];
        output[j++] = b64_table[triple & 0x3F];
    }
    
    size_t padding = input_len % 3;
    if (padding > 0) {
        for (size_t p = 0; p < 3 - padding; p++) {
            output[--j] = '=';
        }
    }
    output[j] = '\0';
    
    return output;
}

char *get_system_arch(void) {
    struct utsname uname_data;
    if (uname(&uname_data) != 0) {
        return strdup("x86_64-linux");
    }
    
    char *arch = strdup(uname_data.machine);
    char *sys = strdup(uname_data.sysname);
    
    if (strcmp(arch, "x86_64") == 0) free(arch), arch = strdup("x86_64");
    else if (strcmp(arch, "aarch64") == 0) free(arch), arch = strdup("aarch64");
    
    char *result = malloc(strlen(arch) + strlen(sys) + 2);
    sprintf(result, "%s-%s", arch, sys);
    
    free(arch);
    free(sys);
    return result;
}

char *make_auth_token(const char *username, const char *password) {
    size_t cred_len = strlen(username) + strlen(password) + 2;
    char *credentials = malloc(cred_len);
    sprintf(credentials, "%s:%s", username, password);
    
    char *encoded = base64_encode(credentials);
    free(credentials);
    
    size_t token_len = strlen(encoded) + 8;
    char *token = malloc(token_len);
    sprintf(token, "Basic %s", encoded);
    
    free(encoded);
    return token;
}

static char *http_post(const char *url, const char *post_data, const char *auth_token) {
    CURL *curl = curl_easy_init();
    if (!curl) return NULL;
    
    char *response = calloc(1, 1);
    
    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Accept: application/json");
    if (auth_token) {
        char auth_header[256];
        snprintf(auth_header, sizeof(auth_header), "Authorization: %s", auth_token);
        headers = curl_slist_append(headers, auth_header);
    }
    
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, post_data);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    
    CURLcode res = curl_easy_perform(curl);
    
    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
    
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    
    if (res != CURLE_OK || http_code != 200) {
        free(response);
        return NULL;
    }
    
    return response;
}

static char *http_get(const char *url) {
    CURL *curl = curl_easy_init();
    if (!curl) return NULL;
    
    char *response = calloc(1, 1);
    
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, NULL);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    
    CURLcode res = curl_easy_perform(curl);
    
    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
    
    curl_easy_cleanup(curl);
    
    if (res != CURLE_OK || http_code != 200) {
        free(response);
        return NULL;
    }
    
    return response;
}

static char *get_json_string(json_object *obj, const char *key) {
    json_object *val;
    if (json_object_object_get_ex(obj, key, &val)) {
        const char *str = json_object_get_string(val);
        return str ? strdup(str) : NULL;
    }
    return NULL;
}

static char **get_json_string_array(json_object *obj, const char *key, int *count) {
    json_object *arr;
    if (!json_object_object_get_ex(obj, key, &arr)) {
        *count = 0;
        return NULL;
    }
    
    int len = json_object_array_length(arr);
    char **result = malloc(len * sizeof(char *));
    *count = len;
    
    for (int i = 0; i < len; i++) {
        json_object *item = json_object_array_get_idx(arr, i);
        const char *str = json_object_get_string(item);
        result[i] = str ? strdup(str) : NULL;
    }
    
    return result;
}

SearchResult *search_packages(const SearchOptions *opts, int *result_count) {
    const char *username = "aWVSALXpZv";
    const char *password = "X8gPHnzL52wFEekuxsfQ9cSh";
    
    char *auth_token = make_auth_token(username, password);
    
    char url[256];
    const char *channel = opts->channel ? opts->channel : "unstable";
    snprintf(url, sizeof(url), "%s%s/_search", SEARCH_URL_PREFIX, channel);
    
    int from = opts->page * opts->num;
    
    char post_data[512];
    snprintf(post_data, sizeof(post_data),
        "{\"query\":{\"multi_match\":{\"query\":\"%s\",\"fields\":[\"package_attr_name^9\",\"package_pname^6\",\"package_description\"],\"type\":\"cross_fields\"}},\"size\":%d,\"from\":%d}",
        opts->query, opts->num, from);
    
    char *response = http_post(url, post_data, auth_token);
    free(auth_token);
    
    if (!response) {
        *result_count = 0;
        return NULL;
    }
    
    json_object *root = json_tokener_parse(response);
    free(response);
    
    if (!root) {
        *result_count = 0;
        return NULL;
    }
    
    json_object *hits_obj;
    if (!json_object_object_get_ex(root, "hits", &hits_obj)) {
        json_object_put(root);
        *result_count = 0;
        return NULL;
    }
    
    json_object *hits_array;
    if (!json_object_object_get_ex(hits_obj, "hits", &hits_array)) {
        json_object_put(root);
        *result_count = 0;
        return NULL;
    }
    
    int count = json_object_array_length(hits_array);
    SearchResult *results = malloc(count * sizeof(SearchResult));
    
    for (int i = 0; i < count; i++) {
        json_object *hit = json_object_array_get_idx(hits_array, i);
        json_object *source;
        if (!json_object_object_get_ex(hit, "_source", &source)) continue;
        
        results[i].attr_name = get_json_string(source, "package_attr_name");
        results[i].pname = get_json_string(source, "package_pname");
        results[i].pversion = get_json_string(source, "package_pversion");
        results[i].description = get_json_string(source, "package_description");
        results[i].attr_set = get_json_string(source, "package_attr_set");
        results[i].platforms = get_json_string_array(source, "package_platforms", &results[i].platforms_count);
        results[i].system = get_json_string(source, "package_system");
        results[i].last_updated = get_json_string(source, "package_last_updated");
    }
    
    json_object_put(root);
    *result_count = count;
    return results;
}

char *get_store_path(const char *attr, const char *arch, const char *jobset) {
    const char *js = jobset ? jobset : "unstable";
    
    char url[512];
    snprintf(url, sizeof(url), "%s/job/nixpkgs/%s/%s.%s/latest-finished",
             HYDRA_URL, js, attr, arch ? arch : "x86_64-linux");
    
    char *response = http_get(url);
    if (!response) return NULL;
    
    json_object *root = json_tokener_parse(response);
    free(response);
    
    if (!root) return NULL;
    
    json_object *buildoutputs;
    if (!json_object_object_get_ex(root, "buildoutputs", &buildoutputs)) {
        json_object_put(root);
        return NULL;
    }
    
    json_object *out;
    if (!json_object_object_get_ex(buildoutputs, "out", &out)) {
        json_object_put(root);
        return NULL;
    }
    
    json_object *path;
    if (!json_object_object_get_ex(out, "path", &path)) {
        json_object_put(root);
        return NULL;
    }
    
    const char *path_str = json_object_get_string(path);
    char *result = path_str ? strdup(path_str) : NULL;
    
    json_object_put(root);
    return result;
}

void free_search_results(SearchResult *results, int count) {
    if (!results) return;
    
    for (int i = 0; i < count; i++) {
        free(results[i].attr_name);
        free(results[i].pname);
        free(results[i].pversion);
        free(results[i].description);
        free(results[i].attr_set);
        if (results[i].platforms) {
            for (int j = 0; j < results[i].platforms_count; j++) {
                free(results[i].platforms[j]);
            }
            free(results[i].platforms);
        }
        free(results[i].system);
        free(results[i].last_updated);
    }
    free(results);
}