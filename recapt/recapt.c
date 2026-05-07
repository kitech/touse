#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include "recapt.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <stdio.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static stbtt_fontinfo g_font;
static unsigned char *g_font_data;
static int g_font_loaded;
static float g_scale;

static unsigned int xorshift32(unsigned int *state) {
    unsigned int x = *state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *state = x;
    return x;
}

static int rand_range(unsigned int *rng, int min, int max) {
    if (max <= min) return min;
    return min + (int)(xorshift32(rng) % (unsigned int)(max - min + 1));
}

static float rand_float(unsigned int *rng, float min, float max) {
    unsigned int v = xorshift32(rng);
    float t = (float)v / 4294967295.0f;
    return min + t * (max - min);
}

static int utf8_decode(const unsigned char *s, unsigned int *cp) {
    if (s[0] < 0x80) {
        *cp = s[0];
        return 1;
    } else if ((s[0] & 0xE0) == 0xC0 && (s[1] & 0xC0) == 0x80) {
        *cp = ((s[0] & 0x1F) << 6) | (s[1] & 0x3F);
        return 2;
    } else if ((s[0] & 0xF0) == 0xE0 && (s[1] & 0xC0) == 0x80 && (s[2] & 0xC0) == 0x80) {
        *cp = ((s[0] & 0x0F) << 12) | ((s[1] & 0x3F) << 6) | (s[2] & 0x3F);
        return 3;
    } else if ((s[0] & 0xF8) == 0xF0 && (s[1] & 0xC0) == 0x80 && (s[2] & 0xC0) == 0x80 && (s[3] & 0xC0) == 0x80) {
        *cp = ((s[0] & 0x07) << 18) | ((s[1] & 0x3F) << 12) | ((s[2] & 0x3F) << 6) | (s[3] & 0x3F);
        return 4;
    }
    *cp = 0;
    return 0;
}

typedef struct {
    unsigned int codepoint;
    float advance;
    float x, y;
    int line;
} glyph_info_t;

typedef struct {
    unsigned int *cp;
    int count;
    int capacity;
} codepoint_array_t;

static void cp_array_init(codepoint_array_t *a) {
    a->cp = NULL; a->count = 0; a->capacity = 0;
}

static void cp_array_push(codepoint_array_t *a, unsigned int cp) {
    if (a->count >= a->capacity) {
        a->capacity = a->capacity ? a->capacity * 2 : 64;
        a->cp = (unsigned int*)realloc(a->cp, (size_t)a->capacity * sizeof(unsigned int));
    }
    a->cp[a->count++] = cp;
}

static void cp_array_free(codepoint_array_t *a) {
    free(a->cp); a->cp = NULL; a->count = 0; a->capacity = 0;
}

static int parse_utf8(const char *text, codepoint_array_t *out) {
    const unsigned char *s = (const unsigned char*)text;
    while (*s) {
        unsigned int cp;
        int n = utf8_decode(s, &cp);
        if (n == 0) return -1;
        cp_array_push(out, cp);
        s += n;
    }
    return 0;
}

typedef struct {
    glyph_info_t *items;
    int count;
    int capacity;
    int lines;
} glyph_array_t;

static void glyph_array_init(glyph_array_t *a) {
    a->items = NULL; a->count = 0; a->capacity = 0; a->lines = 0;
}

static void glyph_array_push(glyph_array_t *a, glyph_info_t g) {
    if (a->count >= a->capacity) {
        a->capacity = a->capacity ? a->capacity * 2 : 64;
        a->items = (glyph_info_t*)realloc(a->items, (size_t)a->capacity * sizeof(glyph_info_t));
    }
    a->items[a->count++] = g;
}

static void glyph_array_free(glyph_array_t *a) {
    free(a->items);
}

static float get_advance_px(unsigned int cp) {
    int advance;
    stbtt_GetCodepointHMetrics(&g_font, (int)cp, &advance, NULL);
    return (float)advance * g_scale;
}

static float get_kerning_px(unsigned int cp1, unsigned int cp2) {
    return (float)stbtt_GetCodepointKernAdvance(&g_font, (int)cp1, (int)cp2) * g_scale;
}

static int layout_text(const codepoint_array_t *cps, int max_width, glyph_array_t *out) {
    const int padding = 10;
    int ascent, descent, lineGap;
    stbtt_GetFontVMetrics(&g_font, &ascent, &descent, &lineGap);
    float line_height = (float)(ascent - descent + lineGap) * g_scale;
    if (line_height < 1) line_height = (float)out->count * 0.3f;

    float x = (float)padding;
    float y = (float)(padding + (int)((float)ascent * g_scale));
    int line = 0;

    for (int i = 0; i < cps->count; i++) {
        unsigned int cp = cps->cp[i];

        if (cp == '\n') {
            x = (float)padding;
            y += line_height;
            line++;
            continue;
        }

        float advance = get_advance_px(cp);

        if (max_width > 0 && x + advance > max_width - padding && x > padding) {
            x = (float)padding;
            y += line_height;
            line++;
        }

        glyph_info_t gi;
        gi.codepoint = cp;
        gi.advance = advance;
        gi.x = x;
        gi.y = y;
        gi.line = line;
        glyph_array_push(out, gi);

        x += advance;
        if (i + 1 < cps->count) {
            x += get_kerning_px(cp, cps->cp[i + 1]);
        }
    }

    out->lines = line + 1;
    return 0;
}

static void composite_glyph(unsigned char *img, int img_w, int img_h,
                            const unsigned char *glyph, int gw, int gh,
                            int dx, int dy,
                            unsigned char cr, unsigned char cg, unsigned char cb) {
    for (int gy = 0; gy < gh; gy++) {
        for (int gx = 0; gx < gw; gx++) {
            int px = dx + gx;
            int py = dy + gy;
            if (px < 0 || px >= img_w || py < 0 || py >= img_h) continue;

            float a = glyph[gy * gw + gx] / 255.0f;
            if (a <= 0.0f) continue;

            int off = (py * img_w + px) * 3;
            img[off + 0] = (unsigned char)((float)img[off + 0] * (1.0f - a) + (float)cr * a);
            img[off + 1] = (unsigned char)((float)img[off + 1] * (1.0f - a) + (float)cg * a);
            img[off + 2] = (unsigned char)((float)img[off + 2] * (1.0f - a) + (float)cb * a);
        }
    }
}

static float lerp(float a, float b, float t) {
    return a + (b - a) * t;
}

static unsigned char sample_bilinear(const unsigned char *img, int w, int h, int ch,
                                      float sx, float sy, int c) {
    if (sx < 0) sx = 0;
    if (sx >= w - 1) sx = (float)(w - 1);
    if (sy < 0) sy = 0;
    if (sy >= h - 1) sy = (float)(h - 1);

    int ix = (int)sx;
    int iy = (int)sy;
    float fx = sx - (float)ix;
    float fy = sy - (float)iy;

    const unsigned char *p00 = &img[(iy * w + ix) * ch + c];
    const unsigned char *p10 = &img[(iy * w + (ix + 1)) * ch + c];
    const unsigned char *p01 = &img[((iy + 1) * w + ix) * ch + c];
    const unsigned char *p11 = &img[((iy + 1) * w + (ix + 1)) * ch + c];

    float v0 = lerp((float)p00[0], (float)p10[0], fx);
    float v1 = lerp((float)p01[0], (float)p11[0], fx);
    return (unsigned char)(lerp(v0, v1, fy) + 0.5f);
}

static void apply_wave(unsigned char *dst, const unsigned char *src,
                        int w, int h, int ch,
                        float amplitude, float freq_x, float freq_y, unsigned int seed) {
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            float dx = amplitude * sinf(2.0f * (float)M_PI * (float)y * freq_y / (float)(h + 1) + (float)(seed & 0xFF) * 0.1f);
            float dy = amplitude * cosf(2.0f * (float)M_PI * (float)x * freq_x / (float)(w + 1) + (float)((seed >> 8) & 0xFF) * 0.1f);
            float sx = (float)x + dx;
            float sy = (float)y + dy;

            int off_dst = (y * w + x) * ch;
            for (int c = 0; c < ch; c++) {
                dst[off_dst + c] = sample_bilinear(src, w, h, ch, sx, sy, c);
            }
        }
    }
}

static void draw_line(unsigned char *img, int w, int h,
                       int x0, int y0, int x1, int y1,
                       unsigned char r, unsigned char g, unsigned char b) {
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy, e2;

    while (1) {
        if (x0 >= 0 && x0 < w && y0 >= 0 && y0 < h) {
            int off = (y0 * w + x0) * 3;
            img[off + 0] = (unsigned char)(((int)img[off + 0] + (int)r) / 2);
            img[off + 1] = (unsigned char)(((int)img[off + 1] + (int)g) / 2);
            img[off + 2] = (unsigned char)(((int)img[off + 2] + (int)b) / 2);
        }
        if (x0 == x1 && y0 == y1) break;
        e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

static void draw_dot(unsigned char *img, int w, int h,
                      int cx, int cy, int radius,
                      unsigned char r, unsigned char g, unsigned char b) {
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            int px = cx + dx;
            int py = cy + dy;
            if (px < 0 || px >= w || py < 0 || py >= h) continue;
            if (dx * dx + dy * dy > radius * radius) continue;
            int off = (py * w + px) * 3;
            img[off + 0] = (unsigned char)(((int)img[off + 0] + (int)r) / 2);
            img[off + 1] = (unsigned char)(((int)img[off + 1] + (int)g) / 2);
            img[off + 2] = (unsigned char)(((int)img[off + 2] + (int)b) / 2);
        }
    }
}

struct mem_buffer {
    unsigned char *data;
    int size;
    int capacity;
};

static void mem_write_func(void *context, void *data, int size) {
    struct mem_buffer *buf = (struct mem_buffer*)context;
    if (buf->size + size > buf->capacity) {
        buf->capacity = buf->size + size + 65536;
        unsigned char *nd = (unsigned char*)realloc(buf->data, (size_t)buf->capacity);
        if (!nd) return;
        buf->data = nd;
    }
    memcpy(buf->data + buf->size, data, (size_t)size);
    buf->size += size;
}

int recapt_init(const char *font_path) {
    if (g_font_loaded) {
        free(g_font_data);
        g_font_data = NULL;
        g_font_loaded = 0;
    }

    FILE *fp = fopen(font_path, "rb");
    if (!fp) return -1;

    fseek(fp, 0, SEEK_END);
    long sz = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    if (sz <= 0) { fclose(fp); return -1; }

    g_font_data = (unsigned char*)malloc((size_t)sz);
    if (!g_font_data) { fclose(fp); return -1; }

    if (fread(g_font_data, 1, (size_t)sz, fp) != (size_t)sz) {
        free(g_font_data); g_font_data = NULL; fclose(fp); return -1;
    }
    fclose(fp);

    int offset = stbtt_GetFontOffsetForIndex(g_font_data, 0);
    if (!stbtt_InitFont(&g_font, g_font_data, offset)) {
        free(g_font_data); g_font_data = NULL; return -1;
    }

    g_font_loaded = 1;
    return 0;
}

unsigned char* recapt_generate_to_memory(const char *text, recapt_config_t *cfg, int *out_len) {
    if (!g_font_loaded || !text || !cfg || !out_len) return NULL;

    unsigned int rng = cfg->seed ? cfg->seed : (unsigned int)time(NULL);
    int diff = cfg->difficulty;
    if (diff < 1) diff = 1;
    if (diff > 5) diff = 5;

    int font_size = cfg->font_size > 0 ? cfg->font_size : 32;
    g_scale = stbtt_ScaleForPixelHeight(&g_font, (float)font_size);

    codepoint_array_t cps;
    cp_array_init(&cps);
    if (parse_utf8(text, &cps) != 0) { cp_array_free(&cps); return NULL; }

    glyph_array_t glyphs;
    glyph_array_init(&glyphs);

    int max_width = cfg->max_width > 0 ? cfg->max_width : 0;

    if (layout_text(&cps, max_width, &glyphs) != 0) {
        cp_array_free(&cps); glyph_array_free(&glyphs); return NULL;
    }

    if (glyphs.count == 0) {
        cp_array_free(&cps); glyph_array_free(&glyphs); return NULL;
    }

    int ascent, descent, lineGap;
    stbtt_GetFontVMetrics(&g_font, &ascent, &descent, &lineGap);
    float line_height = (float)(ascent - descent + lineGap) * g_scale;
    if (line_height < 1) line_height = (float)font_size * 1.3f;

    int img_w, img_h;
    if (max_width > 0) {
        img_w = max_width;
    } else {
        img_w = 0;
        float current_line_end = 10;
        for (int i = 0; i < glyphs.count; i++) {
            if (i > 0 && glyphs.items[i].line != glyphs.items[i - 1].line) {
                if ((int)current_line_end > img_w) img_w = (int)current_line_end;
                current_line_end = 10;
            }
            float end = glyphs.items[i].x + glyphs.items[i].advance;
            if (end > current_line_end) current_line_end = end;
        }
        if ((int)current_line_end > img_w) img_w = (int)current_line_end;
        img_w += 10;
    }

    img_h = (int)((float)(glyphs.lines) * line_height + 20.0f);
    if (img_h < font_size + 20) img_h = font_size + 20;

    unsigned char *img = (unsigned char*)calloc(1, (size_t)img_w * (size_t)img_h * 3);
    if (!img) { cp_array_free(&cps); glyph_array_free(&glyphs); return NULL; }

    for (int i = 0; i < img_w * img_h * 3; i++) {
        img[i] = (unsigned char)(245 + (int)(xorshift32(&rng) % 11));
    }

    float wave_amp[] = { 0.0f, 1.0f, 2.0f, 3.0f, 5.0f };
    int jitter[] = { 2, 3, 4, 5, 8 };
    int lines_min[] = { 0, 3, 6, 12, 18 };
    int lines_max[] = { 0, 6, 12, 18, 30 };
    int dots_min[] = { 0, 15, 30, 60, 120 };
    int dots_max[] = { 0, 30, 60, 120, 240 };

    for (int i = 0; i < glyphs.count; i++) {
        unsigned int cp = glyphs.items[i].codepoint;
        if (cp == ' ' || cp == '\n') continue;

        unsigned char cr = (unsigned char)rand_range(&rng, 20, 80);
        unsigned char cg = (unsigned char)rand_range(&rng, 20, 120);
        unsigned char cb = (unsigned char)rand_range(&rng, 20, 120);

        int jx = 0, jy = 0;
        if (jitter[diff - 1] > 0) {
            jx = rand_range(&rng, -jitter[diff - 1], jitter[diff - 1]);
            jy = rand_range(&rng, -jitter[diff - 1], jitter[diff - 1]);
        }

        int x0, y0, x1, y1;
        stbtt_GetCodepointBitmapBox(&g_font, (int)cp, g_scale, g_scale, &x0, &y0, &x1, &y1);
        int gw = x1 - x0;
        int gh = y1 - y0;
        if (gw <= 0 || gh <= 0) continue;

        unsigned char *gb = (unsigned char*)malloc((size_t)gw * (size_t)gh);
        if (!gb) continue;

        stbtt_MakeCodepointBitmap(&g_font, gb, gw, gh, gw, g_scale, g_scale, (int)cp);

        int dx = (int)(glyphs.items[i].x) + x0 + jx;
        int dy = (int)(glyphs.items[i].y) + y0 + jy;

        composite_glyph(img, img_w, img_h, gb, gw, gh, dx, dy, cr, cg, cb);
        free(gb);
    }

    if (wave_amp[diff - 1] > 0) {
        unsigned char *warped = (unsigned char*)malloc((size_t)img_w * (size_t)img_h * 3);
        if (warped) {
            float freq_x = 2.0f + rand_float(&rng, 0, 1.0f);
            float freq_y = 2.0f + rand_float(&rng, 0, 1.0f);
            apply_wave(warped, img, img_w, img_h, 3,
                       wave_amp[diff - 1], freq_x, freq_y, xorshift32(&rng));
            memcpy(img, warped, (size_t)img_w * (size_t)img_h * 3);
            free(warped);
        }
    }

    int nlines = rand_range(&rng, lines_min[diff - 1], lines_max[diff - 1]);
    for (int i = 0; i < nlines; i++) {
        unsigned char lr = (unsigned char)rand_range(&rng, 80, 200);
        unsigned char lg = (unsigned char)rand_range(&rng, 80, 200);
        unsigned char lb = (unsigned char)rand_range(&rng, 80, 200);
        draw_line(img, img_w, img_h,
                  rand_range(&rng, 0, img_w), rand_range(&rng, 0, img_h),
                  rand_range(&rng, 0, img_w), rand_range(&rng, 0, img_h),
                  lr, lg, lb);
    }

    int ndots = rand_range(&rng, dots_min[diff - 1], dots_max[diff - 1]);
    for (int i = 0; i < ndots; i++) {
        unsigned char dr = (unsigned char)rand_range(&rng, 100, 220);
        unsigned char dg = (unsigned char)rand_range(&rng, 100, 220);
        unsigned char db = (unsigned char)rand_range(&rng, 100, 220);
        draw_dot(img, img_w, img_h,
                 rand_range(&rng, 0, img_w), rand_range(&rng, 0, img_h),
                 rand_range(&rng, 1, 3), dr, dg, db);
    }

    struct mem_buffer buf;
    buf.data = NULL;
    buf.size = 0;
    buf.capacity = 0;

    stbi_write_png_to_func(mem_write_func, &buf, img_w, img_h, 3, img, img_w * 3);

    cp_array_free(&cps);
    glyph_array_free(&glyphs);
    free(img);

    if (!buf.data) return NULL;
    *out_len = buf.size;
    return buf.data;
}

int recapt_generate(const char *text, recapt_config_t *cfg, const char *output_path) {
    if (!g_font_loaded || !text || !cfg || !output_path) return -1;

    unsigned int rng = cfg->seed ? cfg->seed : (unsigned int)time(NULL);
    int diff = cfg->difficulty;
    if (diff < 1) diff = 1;
    if (diff > 5) diff = 5;

    int font_size = cfg->font_size > 0 ? cfg->font_size : 32;
    g_scale = stbtt_ScaleForPixelHeight(&g_font, (float)font_size);

    codepoint_array_t cps;
    cp_array_init(&cps);
    if (parse_utf8(text, &cps) != 0) { cp_array_free(&cps); return -1; }

    glyph_array_t glyphs;
    glyph_array_init(&glyphs);

    int max_width = cfg->max_width > 0 ? cfg->max_width : 0;

    if (layout_text(&cps, max_width, &glyphs) != 0) {
        cp_array_free(&cps); glyph_array_free(&glyphs); return -1;
    }

    if (glyphs.count == 0) {
        cp_array_free(&cps); glyph_array_free(&glyphs); return -1;
    }

    int ascent, descent, lineGap;
    stbtt_GetFontVMetrics(&g_font, &ascent, &descent, &lineGap);
    float line_height = (float)(ascent - descent + lineGap) * g_scale;
    if (line_height < 1) line_height = (float)font_size * 1.3f;

    int img_w, img_h;
    if (max_width > 0) {
        img_w = max_width;
    } else {
        img_w = 0;
        float current_line_end = 10;
        for (int i = 0; i < glyphs.count; i++) {
            if (i > 0 && glyphs.items[i].line != glyphs.items[i - 1].line) {
                if ((int)current_line_end > img_w) img_w = (int)current_line_end;
                current_line_end = 10;
            }
            float end = glyphs.items[i].x + glyphs.items[i].advance;
            if (end > current_line_end) current_line_end = end;
        }
        if ((int)current_line_end > img_w) img_w = (int)current_line_end;
        img_w += 10;
    }

    img_h = (int)((float)(glyphs.lines) * line_height + 20.0f);
    if (img_h < font_size + 20) img_h = font_size + 20;

    unsigned char *img = (unsigned char*)calloc(1, (size_t)img_w * (size_t)img_h * 3);
    if (!img) { cp_array_free(&cps); glyph_array_free(&glyphs); return -1; }

    for (int i = 0; i < img_w * img_h * 3; i++) {
        img[i] = (unsigned char)(245 + (int)(xorshift32(&rng) % 11));
    }

    float wave_amp[] = { 0.0f, 1.0f, 2.0f, 3.0f, 5.0f };
    int jitter[] = { 2, 3, 4, 5, 8 };
    int lines_min[] = { 0, 3, 6, 12, 18 };
    int lines_max[] = { 0, 6, 12, 18, 30 };
    int dots_min[] = { 0, 15, 30, 60, 120 };
    int dots_max[] = { 0, 30, 60, 120, 240 };

    for (int i = 0; i < glyphs.count; i++) {
        unsigned int cp = glyphs.items[i].codepoint;
        if (cp == ' ' || cp == '\n') continue;

        unsigned char cr = (unsigned char)rand_range(&rng, 20, 80);
        unsigned char cg = (unsigned char)rand_range(&rng, 20, 120);
        unsigned char cb = (unsigned char)rand_range(&rng, 20, 120);

        int jx = 0, jy = 0;
        if (jitter[diff - 1] > 0) {
            jx = rand_range(&rng, -jitter[diff - 1], jitter[diff - 1]);
            jy = rand_range(&rng, -jitter[diff - 1], jitter[diff - 1]);
        }

        int x0, y0, x1, y1;
        stbtt_GetCodepointBitmapBox(&g_font, (int)cp, g_scale, g_scale, &x0, &y0, &x1, &y1);
        int gw = x1 - x0;
        int gh = y1 - y0;
        if (gw <= 0 || gh <= 0) continue;

        unsigned char *gb = (unsigned char*)malloc((size_t)gw * (size_t)gh);
        if (!gb) continue;

        stbtt_MakeCodepointBitmap(&g_font, gb, gw, gh, gw, g_scale, g_scale, (int)cp);

        int dx = (int)(glyphs.items[i].x) + x0 + jx;
        int dy = (int)(glyphs.items[i].y) + y0 + jy;

        composite_glyph(img, img_w, img_h, gb, gw, gh, dx, dy, cr, cg, cb);
        free(gb);
    }

    if (wave_amp[diff - 1] > 0) {
        unsigned char *warped = (unsigned char*)malloc((size_t)img_w * (size_t)img_h * 3);
        if (warped) {
            float freq_x = 2.0f + rand_float(&rng, 0, 1.0f);
            float freq_y = 2.0f + rand_float(&rng, 0, 1.0f);
            apply_wave(warped, img, img_w, img_h, 3,
                       wave_amp[diff - 1], freq_x, freq_y, xorshift32(&rng));
            memcpy(img, warped, (size_t)img_w * (size_t)img_h * 3);
            free(warped);
        }
    }

    int nlines = rand_range(&rng, lines_min[diff - 1], lines_max[diff - 1]);
    for (int i = 0; i < nlines; i++) {
        unsigned char lr = (unsigned char)rand_range(&rng, 80, 200);
        unsigned char lg = (unsigned char)rand_range(&rng, 80, 200);
        unsigned char lb = (unsigned char)rand_range(&rng, 80, 200);
        draw_line(img, img_w, img_h,
                  rand_range(&rng, 0, img_w), rand_range(&rng, 0, img_h),
                  rand_range(&rng, 0, img_w), rand_range(&rng, 0, img_h),
                  lr, lg, lb);
    }

    int ndots = rand_range(&rng, dots_min[diff - 1], dots_max[diff - 1]);
    for (int i = 0; i < ndots; i++) {
        unsigned char dr = (unsigned char)rand_range(&rng, 100, 220);
        unsigned char dg = (unsigned char)rand_range(&rng, 100, 220);
        unsigned char db = (unsigned char)rand_range(&rng, 100, 220);
        draw_dot(img, img_w, img_h,
                 rand_range(&rng, 0, img_w), rand_range(&rng, 0, img_h),
                 rand_range(&rng, 1, 3), dr, dg, db);
    }

    int ret = stbi_write_png(output_path, img_w, img_h, 3, img, img_w * 3);

    cp_array_free(&cps);
    glyph_array_free(&glyphs);
    free(img);

    return ret ? 0 : -1;
}

void recapt_free(unsigned char *data) {
    free(data);
}

recapt_config_t recapt_default_config(void) {
    recapt_config_t cfg;
    cfg.font_size = 32;
    cfg.max_width = 0;
    cfg.difficulty = 3;
    cfg.seed = 0;
    return cfg;
}
