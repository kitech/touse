#ifndef RECAPT_H
#define RECAPT_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int font_size;
    int max_width;
    int difficulty;
    unsigned int seed;
} recapt_config_t;

int recapt_init(const char *font_path);
int recapt_generate(const char *text, recapt_config_t *cfg, const char *output_path);
unsigned char* recapt_generate_to_memory(const char *text, recapt_config_t *cfg, int *out_len);
void recapt_free(unsigned char *data);
recapt_config_t recapt_default_config(void);

#ifdef __cplusplus
}
#endif

#endif
