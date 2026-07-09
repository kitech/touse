package oai

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

const (
	libreDefaultServer = "https://translate.fedilab.app"
	libreUA            = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
)

type libreSettings struct {
	CharLimit    int  `json:"charLimit"`
	KeyRequired  bool `json:"keyRequired"`
	APIKeys      bool `json:"apiKeys"`
	FrontTimeout int  `json:"frontendTimeout"`
}

type libreResponse struct {
	TranslatedText interface{} `json:"translatedText"`
}

var (
	libreHTTPClient  *http.Client
	libreCachedSets  *libreSettings
)

func libreGetServer() string {
	if v := os.Getenv("LIBRE_TRANSLATE_URL"); v != "" {
		return v
	}
	return libreDefaultServer
}

func libreGetAPIKey() string {
	return os.Getenv("LIBRE_API_KEY")
}

func libreGetHTTPClient() *http.Client {
	if libreHTTPClient == nil {
		pxyurl := os.Getenv("HTTP_PROXY")
		if strings.HasPrefix(pxyurl, "http://") {
			pxyurl = pxyurl[7:]
		}
		if pxyurl != "" {
			proxyURL, err := url.Parse("http://" + pxyurl)
			if err == nil {
				transport := &http.Transport{
					Proxy: http.ProxyURL(proxyURL),
				}
				libreHTTPClient = &http.Client{Transport: transport, Timeout: 30 * time.Second}
			}
		}
		if libreHTTPClient == nil {
			libreHTTPClient = &http.Client{Timeout: 30 * time.Second}
		}
	}
	return libreHTTPClient
}

func libreFetchSettings() (*libreSettings, error) {
	if libreCachedSets != nil {
		return libreCachedSets, nil
	}

	server := libreGetServer()
	req, err := http.NewRequest("GET", server+"/frontend/settings", nil)
	if err != nil {
		return nil, fmt.Errorf("libre_settings: create request: %w", err)
	}
	req.Header.Set("User-Agent", libreUA)
	resp, err := libreGetHTTPClient().Do(req)
	if err != nil {
		return nil, fmt.Errorf("libre_settings: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("libre_settings: read: %w", err)
	}
	var s libreSettings
	if err := json.Unmarshal(body, &s); err != nil {
		return nil, fmt.Errorf("libre_settings: decode: %w", err)
	}
	libreCachedSets = &s

	if s.KeyRequired && libreGetAPIKey() == "" {
		return nil, fmt.Errorf("libre_settings: server requires API key, set LIBRE_API_KEY")
	}

	return &s, nil
}

func LibreTranFull(tolang, fromlang string, texts ...string) ([]string, error) {
	if tolang == "" {
		return nil, fmt.Errorf("libre_tran_full: tolang is empty")
	}
	if len(texts) == 0 {
		return nil, fmt.Errorf("libre_tran_full: no texts")
	}

	settings, err := libreFetchSettings()
	if err != nil {
		return nil, fmt.Errorf("libre_tran_full: %w", err)
	}

	if settings.CharLimit > 0 {
		for _, t := range texts {
			if len(t) > settings.CharLimit {
				return nil, fmt.Errorf("libre_tran_full: text exceeds %d char limit", settings.CharLimit)
			}
		}
	}

	server := libreGetServer()
	bodyMap := map[string]interface{}{
		"q":      texts,
		"source": fromlang,
		"target": tolang,
		"format": "text",
	}
	if len(texts) == 1 {
		bodyMap["q"] = texts[0]
	}
	if key := libreGetAPIKey(); key != "" {
		bodyMap["api_key"] = key
	}
	jsonBody, err := json.Marshal(bodyMap)
	if err != nil {
		return nil, fmt.Errorf("libre_tran_full: marshal: %w", err)
	}

	req, err := http.NewRequest("POST", server+"/translate", strings.NewReader(string(jsonBody)))
	if err != nil {
		return nil, fmt.Errorf("libre_tran_full: create request: %w", err)
	}
	req.Header.Set("User-Agent", libreUA)
	req.Header.Set("Content-Type", "application/json")

	resp, err := libreGetHTTPClient().Do(req)
	if err != nil {
		return nil, fmt.Errorf("libre_tran_full: %w", err)
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("libre_tran_full: read body: %w", err)
	}

	if resp.StatusCode == 429 {
		return nil, fmt.Errorf("libre_tran_full: rate limited (429)")
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("libre_tran_full: http %d: %s", resp.StatusCode, string(respBody))
	}

	var r libreResponse
	if err := json.Unmarshal(respBody, &r); err != nil {
		return nil, fmt.Errorf("libre_tran_full: decode: %w", err)
	}

	switch v := r.TranslatedText.(type) {
	case string:
		return []string{v}, nil
	case []interface{}:
		results := make([]string, len(v))
		for i, s := range v {
			results[i] = fmt.Sprint(s)
		}
		return results, nil
	default:
		return nil, fmt.Errorf("libre_tran_full: unexpected response type %T", v)
	}
}

func LibreTran(text string) (string, error) {
	res, err := LibreTranFull("zh", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func LibreTranEn(text string) (string, error) {
	res, err := LibreTranFull("en", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func LibreGlobalCleanup() {
	libreHTTPClient = nil
	libreCachedSets = nil
}
