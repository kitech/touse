package oai

import (
	"log"
	"strings"
	"testing"
)

func Test111Mset(t *testing.T) {
	res, err := MsetTran("Hello, world!")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("mset_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111MsetEn(t *testing.T) {
	res, err := MsetTranEn("你好，世界")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("mset_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111MsetFull(t *testing.T) {
	res, err := MsetTranFull("zh", "", "Good morning", "How are you?")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("mset_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}
