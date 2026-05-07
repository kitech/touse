#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <inttypes.h>

#define DEFAULT_MIN_LEN 4
#define CHUNK_SIZE 8192

/* 默认回调：直接输出字符串到 stdout */
static void default_string_callback(const char *str, size_t len, void *userdata) {
    (void)userdata;
    fwrite(str, 1, len, stdout);
    putchar('\n');
}

/* 
 * 扫描二进制文件，提取连续可打印 ASCII 字符序列（长度 >= min_len）。
 * 每当一个序列结束时（遇到不可打印字符或文件尾），调用 callback(str, len, userdata)。
 * callback 接收的 str 指向一个临时缓冲区，仅在回调期间有效，无需额外分配内存。
 * 若 callback == NULL，则使用默认回调（打印到 stdout）。
 * max_bytes: 最多读取的字节数，0 表示无限制。
 */
void scan_for_strings(const char *binpath, size_t min_len, size_t max_bytes,
                        void (*callback)(const char *str, size_t len, void *userdata),
                        void *userdata) {
    FILE *fp = fopen(binpath, "rb");
    if (!fp) {
        fprintf(stderr, "scan_strings: cannot open '%s': %s\n", binpath, strerror(errno));
        return;
    }
    if (!callback) callback = default_string_callback;

    if (max_bytes == 0) max_bytes = SIZE_MAX;

    char buf[CHUNK_SIZE];
    size_t len = 0, total_read = 0;
    int c;
    while ((c = fgetc(fp)) != EOF && total_read < max_bytes) {
        total_read++;
        if (c >= 32 && c <= 126) {
            if (len < sizeof(buf) - 1) buf[len++] = (char)c;
        } else {
            if (len >= min_len) callback(buf, len, userdata);
            len = 0;
        }
    }
    if (len >= min_len) callback(buf, len, userdata);
    fclose(fp);
}

/* 示例用法（命令行工具） */
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <binary-file> [min-len] [max-bytes]\n", argv[0]);
        return 1;
    }
    size_t min_len = (argc >= 3) ? atoi(argv[2]) : DEFAULT_MIN_LEN;
    if (min_len == 0) min_len = DEFAULT_MIN_LEN;

    size_t max_bytes = 0;
    if (argc >= 4) {
        max_bytes = strtoumax(argv[3], NULL, 0);
        if (max_bytes <= 0) max_bytes = 0;
    }

    scan_for_strings(argv[1], min_len, max_bytes, NULL, NULL);
    return 0;
}
