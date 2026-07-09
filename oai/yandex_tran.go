package oai

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const (
	yandexSIDURL  = "https://translate.yandex.net/website-widget/v1/widget.js?widgetId=ytWidget&pageLang=es&widgetTheme=light&autoMode=false"
	yandexAPIBase = "https://translate.yandex.net/api/v1/tr.json/translate"
	yandexUA      = "msie 6"
	yandexSIDFile = "yandex_sid.txt"
)

var yandexHTTPClient *http.Client

type yandexResponse struct {
	Lang string   `json:"lang"`
	Text []string `json:"text"`
}

func yandexProxyClient() *http.Client {
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

func yandexGetHTTPClient() *http.Client {
	if yandexHTTPClient == nil {
		yandexHTTPClient = yandexProxyClient()
	}
	return yandexHTTPClient
}

func yandexNormalizeLang(lang string) string {
	switch lang {
	case "zh-CN", "zh-TW":
		return "zh"
	case "fr-CA":
		return "fr"
	case "pt":
		return "pt-BR"
	case "pt-PT":
		return "pt"
	}
	return lang
}

func yandexGetSID(renew bool) (string, error) {
	sidfile := filepath.Join(os.TempDir(), yandexSIDFile)
	if !renew {
		data, err := os.ReadFile(sidfile)
		if err == nil && len(data) > 0 {
			return strings.TrimSpace(string(data)), nil
		}
	}

	req, err := http.NewRequest("GET", yandexSIDURL, nil)
	if err != nil {
		return "", fmt.Errorf("yandex_get_sid: create request: %w", err)
	}
	req.Header.Set("User-Agent", yandexUA)
	resp, err := yandexGetHTTPClient().Do(req)
	if err != nil {
		return "", fmt.Errorf("yandex_get_sid: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("yandex_get_sid: http %d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("yandex_get_sid: read body: %w", err)
	}

	re := regexp.MustCompile(`sid\:\s'([0-9a-f.]+)`)
	matches := re.FindStringSubmatch(string(body))
	if len(matches) < 2 {
		return "", fmt.Errorf("yandex_get_sid: sid not found in widget js")
	}
	sid := matches[1]
	_ = os.WriteFile(sidfile, []byte(sid), 0644)
	return sid, nil
}

func YandexTranFull(tolang, fromlang string, texts ...string) ([]string, error) {
	if tolang == "" {
		return nil, fmt.Errorf("yandex_tran_full: tolang is empty")
	}
	if len(texts) == 0 {
		return nil, fmt.Errorf("yandex_tran_full: no texts")
	}

	tolang = yandexNormalizeLang(tolang)
	if fromlang != "" {
		fromlang = yandexNormalizeLang(fromlang)
	}

	for retry := 0; retry <= 1; retry++ {
		sid, err := yandexGetSID(retry > 0)
		if err != nil {
			_ = os.Remove(filepath.Join(os.TempDir(), yandexSIDFile))
			return nil, fmt.Errorf("yandex_tran_full: get sid: %w", err)
		}

		apiURL := fmt.Sprintf("%s?srv=tr-url-widget&id=%s-0-0&format=html&lang=%s-%s",
			yandexAPIBase, sid, fromlang, tolang)
		for _, t := range texts {
			apiURL += "&text=" + url.QueryEscape(t)
		}

		req, err := http.NewRequest("GET", apiURL, nil)
		if err != nil {
			return nil, fmt.Errorf("yandex_tran_full: create request: %w", err)
		}
		req.Header.Set("User-Agent", yandexUA)

		resp, err := yandexGetHTTPClient().Do(req)
		if err != nil {
			return nil, fmt.Errorf("yandex_tran_full: %w", err)
		}

		respBody, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return nil, fmt.Errorf("yandex_tran_full: read body: %w", err)
		}

		if resp.StatusCode != 200 {
			_ = os.Remove(filepath.Join(os.TempDir(), yandexSIDFile))
			if retry == 0 {
				continue
			}
			return nil, fmt.Errorf("yandex_tran_full: http %d: %s", resp.StatusCode, string(respBody))
		}

		var r yandexResponse
		if err := json.Unmarshal(respBody, &r); err != nil {
			return nil, fmt.Errorf("yandex_tran_full: decode: %w", err)
		}

		if len(r.Text) == 0 {
			return nil, fmt.Errorf("yandex_tran_full: empty response")
		}

		return r.Text, nil
	}
	return nil, fmt.Errorf("yandex_tran_full: retry exhausted")
}

func YandexTran(text string) (string, error) {
	res, err := YandexTranFull("zh", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func YandexTranEn(text string) (string, error) {
	res, err := YandexTranFull("en", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func YandexGlobalCleanup() {
	yandexHTTPClient = nil
}
