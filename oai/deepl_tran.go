package oai

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	deeplWarmURL    = "https://www.deepl.com/translator"
	deeplAPIBase    = "https://oneshot-free.www.deepl.com/v1/translate"
	deeplUA         = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
	deeplCookieFile = "deepl_cookies.txt"
)

type deeplAppInfo struct {
	OS          string `json:"os"`
	OSVersion   string `json:"os_version"`
	AppVersion  string `json:"app_version"`
	AppBuild    string `json:"app_build"`
	InstanceID  string `json:"instance_id"`
}

type deeplOneshotRequest struct {
	Text           []string      `json:"text"`
	TargetLang     string        `json:"target_lang"`
	SourceLang     string        `json:"source_lang,omitempty"`
	UsageType      string        `json:"usage_type"`
	AppInformation deeplAppInfo  `json:"app_information"`
}

type deeplTranslation struct {
	DetectedSourceLanguage string `json:"detected_source_language"`
	Text                   string `json:"text"`
}

type deeplOneshotResponse struct {
	Translations []deeplTranslation `json:"translations"`
}

var deeplHTTPClient *http.Client

func deeplProxyClient() *http.Client {
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
			return &http.Client{Transport: transport, Timeout: 30 * time.Second}
		}
	}
	return &http.Client{Timeout: 30 * time.Second}
}

func deeplGetHTTPClient() *http.Client {
	if deeplHTTPClient == nil {
		deeplHTTPClient = deeplProxyClient()
	}
	return deeplHTTPClient
}

var deeplLangMap = map[string]string{
	"zh":    "zh-Hans",
	"zh-CN": "zh-Hans",
	"zh-TW": "zh-Hant",
	"en":    "en-US",
	"pt":    "pt-PT",
	"pt-BR": "pt-BR",
	"pt-PT": "pt-PT",
}

func deeplNormalizeLang(lang string) string {
	if v, ok := deeplLangMap[lang]; ok {
		return v
	}
	return lang
}

func deeplGetCookies(renew bool) (string, error) {
	cf := filepath.Join(os.TempDir(), deeplCookieFile)
	if !renew {
		data, err := os.ReadFile(cf)
		if err == nil && len(data) > 0 {
			return strings.TrimSpace(string(data)), nil
		}
	}

	req, err := http.NewRequest("GET", deeplWarmURL, nil)
	if err != nil {
		return "", fmt.Errorf("deepl_get_cookies: create request: %w", err)
	}
	req.Header.Set("User-Agent", deeplUA)
	resp, err := deeplGetHTTPClient().Do(req)
	if err != nil {
		return "", fmt.Errorf("deepl_get_cookies: %w", err)
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)

	var parts []string
	for _, c := range resp.Cookies() {
		parts = append(parts, c.Name+"="+c.Value)
	}
	if len(parts) == 0 {
		return "", fmt.Errorf("deepl_get_cookies: no cookies received")
	}
	cookieStr := strings.Join(parts, "; ")
	_ = os.WriteFile(cf, []byte(cookieStr), 0644)
	return cookieStr, nil
}

func DeeplTranFull(tolang, fromlang string, texts ...string) ([]string, error) {
	if tolang == "" {
		return nil, fmt.Errorf("deepl_tran_full: tolang is empty")
	}
	if len(texts) == 0 {
		return nil, fmt.Errorf("deepl_tran_full: no texts")
	}

	tolang = deeplNormalizeLang(tolang)
	if fromlang != "" {
		fromlang = deeplNormalizeLang(fromlang)
	}

	for retry := 0; retry <= 1; retry++ {
		cookies, err := deeplGetCookies(retry > 0)
		if err != nil {
			if retry == 0 {
				continue
			}
			return nil, fmt.Errorf("deepl_tran_full: get cookies: %w", err)
		}

		body := deeplOneshotRequest{
			Text:       texts,
			TargetLang: tolang,
			SourceLang: fromlang,
			UsageType:  "Translate",
			AppInformation: deeplAppInfo{
				OS:         "brex_macOS",
				OSVersion:  "brex_chrome_130.0.0.0",
				AppVersion: "1.68.0",
				AppBuild:   "chrome_web_store",
				InstanceID: fmt.Sprintf("deepl-go-%d", time.Now().UnixNano()),
			},
		}
		jsonBody, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("deepl_tran_full: marshal: %w", err)
		}

		req, err := http.NewRequest("POST", deeplAPIBase, strings.NewReader(string(jsonBody)))
		if err != nil {
			return nil, fmt.Errorf("deepl_tran_full: create request: %w", err)
		}
		req.Header.Set("User-Agent", deeplUA)
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "None")
		req.Header.Set("Cookie", cookies)
		req.Header.Set("Accept", "*/*")

		resp, err := deeplGetHTTPClient().Do(req)
		if err != nil {
			return nil, fmt.Errorf("deepl_tran_full: %w", err)
		}

		respBody, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return nil, fmt.Errorf("deepl_tran_full: read body: %w", err)
		}

		if resp.StatusCode == 429 || resp.StatusCode == 403 {
			if retry == 0 {
				continue
			}
			return nil, fmt.Errorf("deepl_tran_full: http %d after retry", resp.StatusCode)
		}
		if resp.StatusCode != 200 {
			return nil, fmt.Errorf("deepl_tran_full: http %d: %s", resp.StatusCode, string(respBody))
		}

		var r deeplOneshotResponse
		if err := json.Unmarshal(respBody, &r); err != nil {
			return nil, fmt.Errorf("deepl_tran_full: decode: %w", err)
		}
		if len(r.Translations) == 0 {
			return nil, fmt.Errorf("deepl_tran_full: empty response")
		}

		results := make([]string, len(r.Translations))
		for i, t := range r.Translations {
			results[i] = t.Text
		}
		return results, nil
	}
	return nil, fmt.Errorf("deepl_tran_full: retry exhausted")
}

func DeeplTran(text string) (string, error) {
	res, err := DeeplTranFull("zh", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func DeeplTranEn(text string) (string, error) {
	res, err := DeeplTranFull("en", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func DeeplGlobalCleanup() {
	deeplHTTPClient = nil
}
