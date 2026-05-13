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
	msetAuthURL     = "https://edge.microsoft.com/translate/auth"
	msetAPIBase     = "https://api.cognitive.microsofttranslator.com/translate"
	msetUA          = "msie 6"
	msetTokenFile   = "mset_apikey.txt"
)

type msetReq struct {
	Text string `json:"text"`
}

type msetRespError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type msetTranslation struct {
	Text string `json:"text"`
	To   string `json:"to"`
}

type msetResponse struct {
	Error        msetRespError    `json:"error"`
	Translations []msetTranslation `json:"translations"`
}

var msetHTTPClient *http.Client

func msetProxyClient() *http.Client {
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

func msetGetHTTPClient() *http.Client {
	if msetHTTPClient == nil {
		msetHTTPClient = msetProxyClient()
	}
	return msetHTTPClient
}

func msetAPIURL(tolang, fromlang string) string {
	fromlang = ""
	return fmt.Sprintf("%s?from=%s&to=%s&api-version=3.0&includeSentenceLength=true", msetAPIBase, fromlang, tolang)
}

func msetGetKey(renew bool) (string, error) {
	keyfile := filepath.Join(os.TempDir(), msetTokenFile)
	if !renew {
		data, err := os.ReadFile(keyfile)
		if err == nil && len(data) > 0 {
			return strings.TrimSpace(string(data)), nil
		}
	}
	req, err := http.NewRequest("GET", msetAuthURL, nil)
	if err != nil {
		return "", fmt.Errorf("mset_get_key: create request: %w", err)
	}
	req.Header.Set("User-Agent", msetUA)
	resp, err := msetGetHTTPClient().Do(req)
	if err != nil {
		return "", fmt.Errorf("mset_get_key: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("mset_get_key: http %d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("mset_get_key: read body: %w", err)
	}
	key := strings.TrimSpace(string(body))
	if key == "" {
		return "", fmt.Errorf("mset_get_key: empty token")
	}
	_ = os.WriteFile(keyfile, []byte(key), 0644)
	return key, nil
}

func MsetTranFull(tolang, fromlang string, texts ...string) ([]string, error) {
	if tolang == "" {
		return nil, fmt.Errorf("mset_tran_full: tolang is empty")
	}
	if len(texts) == 0 {
		return nil, fmt.Errorf("mset_tran_full: no texts")
	}

	apikey, err := msetGetKey(false)
	if err != nil {
		return nil, fmt.Errorf("mset_tran_full: get key: %w", err)
	}

	reqs := make([]msetReq, len(texts))
	for i, t := range texts {
		reqs[i] = msetReq{Text: t}
	}
	jsonBody, err := json.Marshal(reqs)
	if err != nil {
		return nil, fmt.Errorf("mset_tran_full: marshal: %w", err)
	}

	for retry := 0; retry <= 1; retry++ {
		apiURL := msetAPIURL(tolang, fromlang)
		req, err := http.NewRequest("POST", apiURL, strings.NewReader(string(jsonBody)))
		if err != nil {
			return nil, fmt.Errorf("mset_tran_full: create request: %w", err)
		}
		req.Header.Set("User-Agent", msetUA)
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+apikey)

		resp, err := msetGetHTTPClient().Do(req)
		if err != nil {
			return nil, fmt.Errorf("mset_tran_full: %w", err)
		}

		respBody, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return nil, fmt.Errorf("mset_tran_full: read body: %w", err)
		}

		// API returns array on success [{...}], single object on error {error:{...}}
		var r msetResponse
		bodyStr := strings.TrimSpace(string(respBody))
		if strings.HasPrefix(bodyStr, "[") {
			var arr []msetResponse
			if err := json.Unmarshal([]byte(bodyStr), &arr); err != nil {
				return nil, fmt.Errorf("mset_tran_full: decode array: %w", err)
			}
			if len(arr) > 0 {
				r = arr[0]
			}
		} else {
			if err := json.Unmarshal([]byte(bodyStr), &r); err != nil {
				return nil, fmt.Errorf("mset_tran_full: decode: %w", err)
			}
		}

		if r.Error.Code == 401001 {
			apikey, err = msetGetKey(true)
			if err != nil {
				return nil, fmt.Errorf("mset_tran_full: retry get key: %w", err)
			}
			continue
		} else if r.Error.Code != 0 {
			return nil, fmt.Errorf("mset_tran_full: api error %d: %s", r.Error.Code, r.Error.Message)
		}

		results := make([]string, len(r.Translations))
		for i, t := range r.Translations {
			results[i] = t.Text
		}
		return results, nil
	}
	return nil, fmt.Errorf("mset_tran_full: retry exhausted")
}

func MsetTran(text string) (string, error) {
	res, err := MsetTranFull("zh", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func MsetTranEn(text string) (string, error) {
	res, err := MsetTranFull("en", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func MsetGlobalCleanup() {
	msetHTTPClient = nil
}
