package oai

import (
	"log"
	"strings"
	"testing"
)

func youdaoSkip(err error) {
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("youdao_tran: network unavailable, skipping")
	}
}

func Test111Youdao(t *testing.T) {
	res, err := YoudaoTran("Hello, world!")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("youdao_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111YoudaoEn(t *testing.T) {
	res, err := YoudaoTranEn("你好，世界")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("youdao_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111YoudaoFull(t *testing.T) {
	res, err := YoudaoTranFull("zh", "", "Good morning", "How are you?")
	youdaoSkip(err)
	log.Println(err, res)
}

func Test111YoudaoMultiLine(t *testing.T) {
	res, err := YoudaoTranFull("zh", "", "Hello\nHow are you\nGood night")
	youdaoSkip(err)
	if err != nil {
		t.Fatal(err)
	}
	log.Println(res)
	if got := strings.Count(res[0], "\n"); got != 2 {
		t.Fatalf("want 2 newlines kept, got %d (%q)", got, res[0])
	}
}

func Test111YoudaoType(t *testing.T) {
	res, srclang, err := YoudaoTranFullType("zh", "", "Good morning")
	youdaoSkip(err)
	if err != nil {
		t.Fatal(err)
	}
	log.Println(res, srclang)
	if srclang != "en" {
		t.Fatalf("want src lang en, got %q", srclang)
	}
}

// 20000 runes 上下：验证单请求路径（youdaoMaxLen 18000 以上不该切块）
func Test111YoudaoLong(t *testing.T) {
	long := strings.Repeat("The quick brown fox jumps over the lazy dog. ", 500)
	if n := len([]rune(long)); n < 20000 {
		t.Fatalf("test input too short: %d runes", n)
	}
	res, err := YoudaoTranFull("zh", "", long)
	youdaoSkip(err)
	if err != nil {
		t.Fatal(err)
	}
	log.Println("input runes:", len([]rune(long)), "output runes:", len([]rune(res[0])))
	if len([]rune(res[0])) < 100 {
		t.Fatalf("translate too short: %d runes", len([]rune(res[0])))
	}
}

// 远超单请求上限：验证 youdaoSplitText 切块路径仍被覆盖
func Test111YoudaoChunked(t *testing.T) {
	long := strings.Repeat("The quick brown fox jumps over the lazy dog. ", 1300)
	if n := len([]rune(long)); n <= youdaoMaxLen {
		t.Fatalf("test input must exceed chunk size: %d <= %d", n, youdaoMaxLen)
	}
	res, err := YoudaoTranFull("zh", "", long)
	youdaoSkip(err)
	if err != nil {
		t.Fatal(err)
	}
	log.Println("input runes:", len([]rune(long)), "output runes:", len([]rune(res[0])))
	if len([]rune(res[0])) < 100 {
		t.Fatalf("chunked translate too short: %d runes", len([]rune(res[0])))
	}
}
