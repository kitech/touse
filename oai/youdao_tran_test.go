package oai

import (
	"log"
	"strings"
	"testing"
)

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
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("youdao_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}
