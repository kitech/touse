/* xmlc_cdata.c — xmlc 的 CDATA 段支持（上游 xml.c 明言永不支持，本地特性）。
 * 只提供原语：检测、段扫描、字节收集器；主解析流程在 xmlc.c 中调用。 */
#include "xmlc_cdata.h"

#include <stdlib.h>
#include <string.h>

static uint8_t const xmlc_cdata_open[XMLC_CDATA_OPEN] =
	{ '<','!','[','C','D','A','T','A','[' };
static uint8_t const xmlc_cdata_close[XMLC_CDATA_CLOSE] =
	{ ']',']','>' };

int xmlc_cdata_at(uint8_t const* buf, size_t len, size_t pos) {
	if (!buf || pos > len || len - pos < XMLC_CDATA_OPEN) {
		return 0;
	}
	return 0 == memcmp(&buf[pos], xmlc_cdata_open, XMLC_CDATA_OPEN);
}

size_t xmlc_cdata_section(uint8_t const* buf, size_t len, size_t pos,
                          size_t* begin, size_t* end) {
	if (!xmlc_cdata_at(buf, len, pos)) {
		return 0;
	}
	size_t inner = pos + XMLC_CDATA_OPEN;
	if (inner > len) {
		return 0;
	}
	for (size_t i = inner; i + XMLC_CDATA_CLOSE <= len; ++i) {
		if (0 == memcmp(&buf[i], xmlc_cdata_close, XMLC_CDATA_CLOSE)) {
			if (begin) {
				*begin = inner;
			}
			if (end) {
				*end = i;
			}
			return i + XMLC_CDATA_CLOSE;
		}
	}
	return 0;
}

int xmlc_cdata_buf_init(xmlc_cdata_buf* b, size_t hint) {
	if (hint < 64) {
		hint = 64;
	}
	b->data = malloc(hint);
	b->cap = b->data ? hint : 0;
	b->len = 0;
	return b->data ? 0 : -1;
}

int xmlc_cdata_buf_append(xmlc_cdata_buf* b, uint8_t const* p, size_t n) {
	if (!n) {
		return 0;
	}
	if (b->len + n > b->cap) {
		size_t cap = b->cap ? b->cap : 64;
		while (cap < b->len + n) {
			cap *= 2;
		}
		uint8_t* grown = realloc(b->data, cap);
		if (!grown) {
			return -1;
		}
		b->data = grown;
		b->cap = cap;
	}
	memcpy(&b->data[b->len], p, n);
	b->len += n;
	return 0;
}

void xmlc_cdata_buf_dispose(xmlc_cdata_buf* b) {
	free(b->data);
	b->data = 0;
	b->len = 0;
	b->cap = 0;
}
