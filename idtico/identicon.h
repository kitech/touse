#ifndef IDENTICON_H
#define IDENTICON_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 生成 identicon PNG 文件
 * @param id       用户标识字符串（任意长度）
 * @param filename 输出 PNG 文件名
 * @return 0 成功，-1 失败
 */
int identicon_generate(const char *id, const char *filename);

/**
 * 生成 identicon 到内存缓冲区
 * @param id      用户标识
 * @param out_buf 输出缓冲区指针（需调用 free 释放）
 * @param out_len 输出长度
 * @return 0 成功，-1 失败
 */
int identicon_generate_to_buffer(const char *id, uint8_t **out_buf, size_t *out_len);

#ifdef __cplusplus
}
#endif

#endif /* IDENTICON_H */
