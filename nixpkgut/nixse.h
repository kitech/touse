#ifndef NIXSE_H
#define NIXSE_H

#include <stddef.h>

typedef struct {
    char *attr_name;
    char *pname;
    char *pversion;
    char *description;
    char *attr_set;
    char **platforms;
    int platforms_count;
    char *system;
    char *last_updated;
} SearchResult;

typedef struct {
    char *query;
    char *arch;
    int num;
    int page;
    char *channel;
    int plain;
    int details;
} SearchOptions;

typedef struct {
    char *path;
} HydraResponse;

char *get_system_arch(void);
char *make_auth_token(const char *username, const char *password);
SearchResult *search_packages(const SearchOptions *opts, int *result_count);
char *get_store_path(const char *attr, const char *arch, const char *jobset);
void free_search_results(SearchResult *results, int count);

#endif /* NIXSE_H */