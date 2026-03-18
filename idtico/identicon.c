#include "identicon.h"
#include "md5.h"
#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* 图像尺寸：每个格子 100x100 像素，总 500x500 */
#define CELL_SIZE 100
#define GRID_SIZE 5
#define IMG_WIDTH  (GRID_SIZE * CELL_SIZE)
#define IMG_HEIGHT (GRID_SIZE * CELL_SIZE)

/* HSL 转 RGB 辅助函数 */
static void hsl_to_rgb(double h, double s, double l, uint8_t *r, uint8_t *g, uint8_t *b) {
    double c = (1 - fabs(2 * l - 1)) * s;
    double hp = h / 60.0;
    double x = c * (1 - fabs(fmod(hp, 2) - 1));
    double r1, g1, b1;
    if (hp < 1)      { r1 = c; g1 = x; b1 = 0; }
    else if (hp < 2) { r1 = x; g1 = c; b1 = 0; }
    else if (hp < 3) { r1 = 0; g1 = c; b1 = x; }
    else if (hp < 4) { r1 = 0; g1 = x; b1 = c; }
    else if (hp < 5) { r1 = x; g1 = 0; b1 = c; }
    else             { r1 = c; g1 = 0; b1 = x; }
    double m = l - c/2;
    *r = (uint8_t)((r1 + m) * 255 + 0.5);
    *g = (uint8_t)((g1 + m) * 255 + 0.5);
    *b = (uint8_t)((b1 + m) * 255 + 0.5);
}

/* 从 MD5 摘要生成颜色 (RGB) */
static void get_color_from_digest(const uint8_t digest[16], uint8_t *r, uint8_t *g, uint8_t *b) {
    /* 取最后 7 个十六进制字符（即 28 位）用于 HSL */
    /* 实际 Go 实现中使用了更多位数，这里简化为：
       色相：使用 digest[12] 和 digest[13] 的一部分，映射到 0~360
       饱和度：使用 digest[14] 的高 4 位，映射到 0.4~1.0
       亮度：使用 digest[14] 的低 4 位，映射到 0.4~0.9
       更精确的实现可参考 Go 版本，但原理一致 */
    uint32_t hue_seed = (digest[12] << 8) | digest[13];
    double h = (hue_seed % 360) + (hue_seed / 360.0);  // 0~360
    double s = 0.4 + (digest[14] >> 4) / 15.0 * 0.6;   // 0.4~1.0
    double l = 0.4 + (digest[14] & 0x0F) / 15.0 * 0.5; // 0.4~0.9
    hsl_to_rgb(h, s, l, r, g, b);
}

/* 生成 5x3 的布尔网格（前景/背景） */
static void generate_pattern(const uint8_t digest[16], int pattern[5][3]) {
    /* 取前 15 个十六进制字符（即 60 位），每个字符 4 位，对应一个格子 */
    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 3; j++) {
            int idx = i * 3 + j;           // 0..14
            int byte_idx = idx / 2;         // 每个 digest 字节含两个十六进制字符
            int nibble = (idx % 2 == 0) ? (digest[byte_idx] >> 4) : (digest[byte_idx] & 0x0F);
            pattern[i][j] = (nibble % 2 == 0) ? 1 : 0;   // 偶数前景，奇数背景
        }
    }
}

/* 将 5x3 镜像为 5x5 */
static void mirror_pattern(int pattern_5x3[5][3], int pattern_5x5[5][5]) {
    for (int y = 0; y < 5; y++) {
        for (int x = 0; x < 5; x++) {
            if (x < 3)
                pattern_5x5[y][x] = pattern_5x3[y][x];
            else
                pattern_5x5[y][x] = pattern_5x3[y][4 - x];  // 镜像左边
        }
    }
}

/* 写入 PNG 文件 */
static int write_png(const char *filename, uint8_t *image, int width, int height) {
    FILE *fp = fopen(filename, "wb");
    if (!fp) return -1;

    png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) { fclose(fp); return -1; }

    png_infop info = png_create_info_struct(png);
    if (!info) { png_destroy_write_struct(&png, NULL); fclose(fp); return -1; }

    if (setjmp(png_jmpbuf(png))) {
        png_destroy_write_struct(&png, &info);
        fclose(fp);
        return -1;
    }

    png_init_io(png, fp);
    png_set_IHDR(png, info, width, height, 8, PNG_COLOR_TYPE_RGB,
                 PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
    png_write_info(png, info);

    /* 按行写入 */
    for (int y = 0; y < height; y++) {
        png_write_row(png, image + y * width * 3);
    }

    png_write_end(png, NULL);
    png_destroy_write_struct(&png, &info);
    fclose(fp);
    return 0;
}

/* 主生成函数（内部使用） */
static int identicon_generate_internal(const char *id, uint8_t **out_buf, size_t *out_len, const char *filename) {
    /* 1. 计算 MD5 */
    MD5_CTX ctx;
    uint8_t digest[16];
    MD5_Init(&ctx);
    MD5_Update(&ctx, (const uint8_t*)id, strlen(id));
    MD5_Final(digest, &ctx);

    /* 2. 获取前景颜色 */
    uint8_t fg_r, fg_g, fg_b;
    get_color_from_digest(digest, &fg_r, &fg_g, &fg_b);

    /* 3. 生成 5x3 图案并镜像为 5x5 */
    int pattern_5x3[5][3];
    int pattern[5][5];
    generate_pattern(digest, pattern_5x3);
    mirror_pattern(pattern_5x3, pattern);

    /* 4. 创建图像缓冲区（RGB 每像素3字节） */
    size_t img_size = IMG_WIDTH * IMG_HEIGHT * 3;
    uint8_t *image = (uint8_t*)malloc(img_size);
    if (!image) return -1;

    /* 填充图像 */
    for (int gy = 0; gy < 5; gy++) {
        for (int gx = 0; gx < 5; gx++) {
            int fill = pattern[gy][gx];  // 1=前景色，0=背景色（白色）
            for (int py = 0; py < CELL_SIZE; py++) {
                int y = gy * CELL_SIZE + py;
                for (int px = 0; px < CELL_SIZE; px++) {
                    int x = gx * CELL_SIZE + px;
                    int idx = (y * IMG_WIDTH + x) * 3;
                    if (fill) {
                        image[idx + 0] = fg_r;
                        image[idx + 1] = fg_g;
                        image[idx + 2] = fg_b;
                    } else {
                        image[idx + 0] = 0xFF;
                        image[idx + 1] = 0xFF;
                        image[idx + 2] = 0xFF;
                    }
                }
            }
        }
    }

    /* 5. 输出到文件或缓冲区 */
    int ret = 0;
    if (filename) {
        ret = write_png(filename, image, IMG_WIDTH, IMG_HEIGHT);
    } else if (out_buf && out_len) {
        /* 写入内存缓冲区：使用 libpng 的写入回调 */
        /* 简化起见，这里略去内存写入的实现，可参考 libpng 示例 */
        /* 实际实现可使用 png_set_write_fn 自定义写入函数 */
        ret = -1;  // 暂不支持内存版本，留作扩展
    }

    free(image);
    return ret;
}

/* 公开 API */
int identicon_generate(const char *id, const char *filename) {
    return identicon_generate_internal(id, NULL, NULL, filename);
}

int identicon_generate_to_buffer(const char *id, uint8_t **out_buf, size_t *out_len) {
    return identicon_generate_internal(id, out_buf, out_len, NULL);
}
