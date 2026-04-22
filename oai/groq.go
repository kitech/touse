package oai


import (
	"context"
	"fmt"
	"os"
	"strings"
	"log"
	"net/http"
	"net/url"

	"github.com/sashabaranov/go-openai"
)

func GroqAi(apikey string, prompt string) (string, error) {
	// 1. Replace with a free provider key (e.g., Groq or OpenRouter)
	// config := openai.DefaultConfig("YOUR_FREE_API_KEY")
	config := openai.DefaultConfig(apikey)

	// 2. Point to the free provider's endpoint
	config.BaseURL = "https://groq.com"
	config.BaseURL = "https://api.groq.com/openai/v1"
	// fmt.Printf("%+v\n", config)

	pxyurl := os.Getenv("HTTP_PROXY") // http://ip:port
	if strings.HasPrefix(pxyurl, "http://") {
		pxyurl = pxyurl[7:]
	}
	if true && pxyurl != "" {
		transport := &http.Transport{
			Proxy: http.ProxyURL(&url.URL{
				Scheme: "http",
				// Host:   "127.0.0.1:9996",
				Host: pxyurl,
			}),
		}
		config.HTTPClient = &http.Client{Transport: transport}
	}

	client := openai.NewClientWithConfig(config)
	resp, err := client.CreateChatCompletion(
		context.Background(),
		openai.ChatCompletionRequest{
			// Model: "llama3-8b-8192", // Use a model supported by your free provider
			// Model: "llama-3.3-70b-versatile",
			// Model: "llama-3.1-8b-instant",
			Model: "openai/gpt-oss-120b",
			Messages: []openai.ChatCompletionMessage{
				// {Role: "user", Content: "Hello!"},
				{Role: "user", Content: prompt},
			},
			MaxTokens:   2048,
			TopP: 1, Temperature: 1,
			Stream: false,
		},
	)

	if err != nil {
		fmt.Printf("ChatCompletion error: %v\n", err)
		return "", err
	}

	rescc := resp.Choices[0].Message.Content
	log.Println(len(rescc), rescc, len(rescc))
	return rescc, nil
}
