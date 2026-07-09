package oai

import (
	"log"
	"strings"
	"testing"
)

func Test111Libre(t *testing.T) {
	res, err := LibreTran("Hello, world!")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("libre_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111LibreEn(t *testing.T) {
	res, err := LibreTranEn("你好，世界")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("libre_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}

func Test111LibreFull(t *testing.T) {
	res, err := LibreTranFull("zh", "", "Good morning", "How are you?")
	if err != nil && strings.Contains(err.Error(), "no such host") {
		log.Println("libre_tran: network unavailable, skipping")
		return
	}
	log.Println(err, res)
}
