#include "recapt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void print_usage(const char *prog) {
    fprintf(stderr, "Usage: %s [options] <text> <output.png>\n", prog);
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "  -f <path>     Font file path (required)\n");
    fprintf(stderr, "  -s <size>     Font size in pixels (default: 32)\n");
    fprintf(stderr, "  -w <width>    Maximum image width for auto-wrap (default: 0 = auto)\n");
    fprintf(stderr, "  -d <level>    Difficulty 1-5 (default: 3)\n");
    fprintf(stderr, "  -S <seed>     Random seed (default: 0 = auto)\n");
    fprintf(stderr, "  -h            Show this help\n");
}

int main(int argc, char **argv) {
    const char *font_path = NULL;
    const char *text = NULL;
    const char *output_path = NULL;
    recapt_config_t cfg = recapt_default_config();

    for (int i = 1; i < argc; i++) {
        if (argv[i][0] == '-') {
            switch (argv[i][1]) {
            case 'f':
                if (++i >= argc) { fprintf(stderr, "-f needs arg\n"); return 1; }
                font_path = argv[i];
                break;
            case 's':
                if (++i >= argc) { fprintf(stderr, "-s needs arg\n"); return 1; }
                cfg.font_size = atoi(argv[i]);
                break;
            case 'w':
                if (++i >= argc) { fprintf(stderr, "-w needs arg\n"); return 1; }
                cfg.max_width = atoi(argv[i]);
                break;
            case 'd':
                if (++i >= argc) { fprintf(stderr, "-d needs arg\n"); return 1; }
                cfg.difficulty = atoi(argv[i]);
                break;
            case 'S':
                if (++i >= argc) { fprintf(stderr, "-S needs arg\n"); return 1; }
                cfg.seed = (unsigned int)atoi(argv[i]);
                break;
            case 'h':
                print_usage(argv[0]);
                return 0;
            default:
                fprintf(stderr, "Unknown option: %s\n", argv[i]);
                return 1;
            }
        } else {
            if (!text) text = argv[i];
            else if (!output_path) output_path = argv[i];
        }
    }

    if (!font_path) {
        fprintf(stderr, "Error: -f <font> is required\n");
        print_usage(argv[0]);
        return 1;
    }
    if (!text || !output_path) {
        fprintf(stderr, "Error: need <text> and <output.png>\n");
        print_usage(argv[0]);
        return 1;
    }

    if (recapt_init(font_path) != 0) {
        fprintf(stderr, "Failed to load font: %s\n", font_path);
        return 1;
    }

    int ret = recapt_generate(text, &cfg, output_path);
    if (ret != 0) {
        fprintf(stderr, "Failed to generate captcha\n");
        return 1;
    }

    printf("Captcha saved to %s (%s)\n", output_path, text);
    printf("  font_size=%d  max_width=%d  difficulty=%d  seed=%u\n",
           cfg.font_size, cfg.max_width, cfg.difficulty, cfg.seed);
    return 0;
}
