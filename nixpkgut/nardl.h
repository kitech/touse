#ifndef NARDL_H
#define NARDL_H

#include <stddef.h>

typedef struct {
    char *store_path;
    char *output;
    char *cache_url;
} DownloadOptions;

int download_nar(const DownloadOptions *opts);

#endif /* NARDL_H */