#ifndef MSET_TRAN_H
#define MSET_TRAN_H

#include <stddef.h>

typedef struct {
    char **items;
    size_t count;
} oai_mset_string_arr;

int oai_mset_tran(const char *text, const char *to_lang, char **result);
int oai_mset_tran_en(const char *text, char **result);
int oai_mset_tran_full(const char *to_lang, const char *from_lang,
                       const char **texts, size_t text_count,
                       oai_mset_string_arr *out);
void oai_mset_free_string_arr(oai_mset_string_arr *arr);
void oai_mset_global_cleanup(void);
const char* oai_mset_get_last_error(void);

#endif