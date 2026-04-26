#include "nixse.h"
#include "nardl.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <curl/curl.h>

static void print_search_usage(const char *prog) {
    printf("Usage: %s search [options] <query>\n", prog);
    printf("\nOptions:\n");
    printf("  -a, --arch <arch>      Target architecture (default: auto)\n");
    printf("  -n, --num <num>        Number of results (default: 20, max: 50)\n");
    printf("  -p, --page <num>       Page number (default: 0)\n");
    printf("  -c, --channel <ch>     NixOS channel (default: unstable)\n");
    printf("  -P, --plain            Output only package names\n");
    printf("  -d, --details          Show store path\n");
    printf("  -h, --help             Show this help\n");
    printf("\nNote: Flags must appear before the query argument.\n");
}

static void print_download_usage(const char *prog) {
    printf("Usage: %s download <store_path> [options]\n", prog);
    printf("\nOptions:\n");
    printf("  -o, --output <file>    Output file (default: stdout)\n");
    printf("  -c, --cache <url>      Cache URL (default: https://cache.nixos.org)\n");
    printf("  -h, --help             Show this help\n");
}

static void print_usage(const char *prog) {
    printf("Usage: %s <command> [options]\n", prog);
    printf("\nCommands:\n");
    printf("  search, s    Search for Nix packages\n");
    printf("  download, dl Download NAR from binary cache\n");
    printf("  help, h      Show this help\n");
    printf("\nExamples:\n");
    printf("  %s search hello\n", prog);
    printf("  %s search -P -n 5 hello\n", prog);
    printf("  %s download /nix/store/xxx-hello-2.12.3\n", prog);
}

static int run_search(int argc, char *argv[]) {
    SearchOptions opts = {0};
    opts.num = 20;
    opts.page = 0;
    opts.channel = strdup("unstable");
    
    static struct option long_options[] = {
        {"arch", required_argument, 0, 'a'},
        {"num", required_argument, 0, 'n'},
        {"page", required_argument, 0, 'p'},
        {"channel", required_argument, 0, 'c'},
        {"plain", no_argument, 0, 'P'},
        {"details", no_argument, 0, 'd'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    int option_index = 0;
    
    while ((opt = getopt_long(argc, argv, "a:n:p:c:Pdh", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'a':
                free(opts.arch);
                opts.arch = strdup(optarg);
                break;
            case 'n':
                opts.num = atoi(optarg);
                break;
            case 'p':
                opts.page = atoi(optarg);
                break;
            case 'c':
                free(opts.channel);
                opts.channel = strdup(optarg);
                break;
            case 'P':
                opts.plain = 1;
                break;
            case 'd':
                opts.details = 1;
                break;
            case 'h':
                print_search_usage(argv[0]);
                return 0;
            default:
                print_search_usage(argv[0]);
                return 1;
        }
    }
    
    if (optind >= argc) {
        fprintf(stderr, "Error: query required\n");
        print_search_usage(argv[0]);
        return 1;
    }
    
    opts.query = strdup(argv[optind]);
    
    if (opts.num > 50) opts.num = 50;
    if (opts.num < 1) opts.num = 1;
    
    char *default_arch = get_system_arch();
    if (!opts.arch) {
        opts.arch = default_arch;
    } else {
        free(default_arch);
    }
    
    int result_count = 0;
    SearchResult *results = search_packages(&opts, &result_count);
    
    if (!results || result_count == 0) {
        printf("No results found.\n");
    } else {
        for (int i = 0; i < result_count; i++) {
            SearchResult *r = &results[i];
            
            char *store_path = NULL;
            if (opts.details) {
                store_path = get_store_path(r->attr_name, opts.arch, NULL);
            }
            
            if (opts.plain) {
                printf("%s %s\n", r->attr_name, r->pversion ? r->pversion : "");
            } else {
                printf("%s %s %s\n", r->attr_name, r->pversion ? r->pversion : "", r->system ? r->system : "");
                if (r->description) {
                    printf("    %s\n", r->description);
                }
                if (r->last_updated || (r->platforms && r->platforms_count > 0)) {
                    printf("    %s ", r->last_updated ? r->last_updated : "");
                    if (r->platforms && r->platforms_count > 0) {
                        for (int j = 0; j < r->platforms_count; j++) {
                            if (j > 0) printf(",");
                            printf("%s", r->platforms[j]);
                        }
                    }
                    printf("\n");
                }
                if (store_path) {
                    printf("    %s\n", store_path);
                }
            }
            
            free(store_path);
        }
    }
    
    free_search_results(results, result_count);
    free(opts.query);
    free(opts.arch);
    free(opts.channel);
    
    return 0;
}

static int run_download(int argc, char *argv[]) {
    DownloadOptions opts = {0};
    opts.cache_url = strdup("https://cache.nixos.org");
    
    static struct option long_options[] = {
        {"output", required_argument, 0, 'o'},
        {"cache", required_argument, 0, 'c'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    int option_index = 0;
    
    while ((opt = getopt_long(argc, argv, "o:c:h", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'o':
                free(opts.output);
                opts.output = strdup(optarg);
                break;
            case 'c':
                free(opts.cache_url);
                opts.cache_url = strdup(optarg);
                break;
            case 'h':
                print_download_usage(argv[0]);
                return 0;
            default:
                print_download_usage(argv[0]);
                return 1;
        }
    }
    
    if (optind >= argc) {
        fprintf(stderr, "Error: store path required\n");
        print_download_usage(argv[0]);
        return 1;
    }
    
    opts.store_path = strdup(argv[optind]);
    
    int ret = download_nar(&opts);
    
    free(opts.store_path);
    free(opts.output);
    free(opts.cache_url);
    
    return ret;
}

int main(int argc, char *argv[]) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }
    
    const char *subcmd = argv[1];
    int ret = 0;
    
    if (strcmp(subcmd, "search") == 0 || strcmp(subcmd, "s") == 0) {
        ret = run_search(argc - 1, argv + 1);
    } else if (strcmp(subcmd, "download") == 0 || strcmp(subcmd, "dl") == 0) {
        ret = run_download(argc - 1, argv + 1);
    } else if (strcmp(subcmd, "help") == 0 || strcmp(subcmd, "h") == 0 ||
               strcmp(subcmd, "--help") == 0 || strcmp(subcmd, "-h") == 0) {
        print_usage(argv[0]);
        ret = 0;
    } else {
        fprintf(stderr, "Unknown command: %s\n", subcmd);
        print_usage(argv[0]);
        ret = 1;
    }
    
    curl_global_cleanup();
    return ret;
}