package oai

import (
	"log"
	"strings"
	"testing"
)

func Test111Google(t *testing.T) {
	res, err := GoogleTran("Hello, world!")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("google_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111GoogleEn(t *testing.T) {
	res, err := GoogleTranEn("你好，世界")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("google_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111GoogleFull(t *testing.T) {
	res, err := GoogleTranFull("zh", "", "Good morning", "How are you?")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("google_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}
