#ifndef HEADER_XMLC_CDATA
#define HEADER_XMLC_CDATA

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* CDATA 开头 "<![CDATA[" 9 字节；结尾 "]]>" 3 字节 */
#define XMLC_CDATA_OPEN  9
#define XMLC_CDATA_CLOSE 3

/* buf[pos] 处是否是 CDATA 开头（含边界检查） */
int xmlc_cdata_at(uint8_t const* buf, size_t len, size_t pos);

/* 扫描始于 pos 的 CDATA 段（调用方先用 xmlc_cdata_at 确认）。
 * 成功：*begin/*end = 内部内容字节（不含头尾），返回 "]]>" 之后的位置；
 * 未闭合返回 0。CDATA 内嵌套 "<![CDATA[" 按字面文本处理。 */
size_t xmlc_cdata_section(uint8_t const* buf, size_t len, size_t pos,
                          size_t* begin, size_t* end);

/* 可增长字节收集器：混合 text+CDATA 内容的合并缓冲 */
typedef struct {
	uint8_t* data;
	size_t   len;
	size_t   cap;
} xmlc_cdata_buf;

int  xmlc_cdata_buf_init(xmlc_cdata_buf* b, size_t hint);
int  xmlc_cdata_buf_append(xmlc_cdata_buf* b, uint8_t const* p, size_t n);
void xmlc_cdata_buf_dispose(xmlc_cdata_buf* b);

#ifdef __cplusplus
}
#endif

#endif
