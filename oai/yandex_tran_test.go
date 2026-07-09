package oai

import (
	"log"
	"strings"
	"testing"
)

func Test111Yandex(t *testing.T) {
	res, err := YandexTran("Hello, world!")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("yandex_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111YandexEn(t *testing.T) {
	res, err := YandexTranEn("你好，世界")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("yandex_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111YandexFull(t *testing.T) {
	res, err := YandexTranFull("zh", "", "Good morning", "How are you?")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("yandex_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}
