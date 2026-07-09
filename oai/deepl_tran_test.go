package oai

import (
	"log"
	"strings"
	"testing"
)

func Test111Deepl(t *testing.T) {
	res, err := DeeplTran("Hello, world!")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("deepl_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111DeeplEn(t *testing.T) {
	res, err := DeeplTranEn("你好，世界")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("deepl_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111DeeplFull(t *testing.T) {
	res, err := DeeplTranFull("zh", "", "Good morning", "How are you?")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("deepl_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}
