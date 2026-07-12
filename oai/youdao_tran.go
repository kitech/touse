// Reference: https://github.com/HaleShaw/uTools-Translate
// Youdao Web Translate (dict.youdao.com/webtranslate) - Free, no API key needed
package oai

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/md5"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	youdaoKeyURL     = "https://dict.youdao.com/webtranslate/key"
	youdaoAPIURL     = "https://dict.youdao.com/webtranslate"
	youdaoUA         = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
	youdaoKeyFile    = "youdao_web_key.txt"
	youdaoClient     = "fanyideskweb"
	youdaoProduct    = "webfanyi"
	youdaoSecretKey  = "asdjnjfenknafdfsdfsd"
	youdaoMaxLen     = 5000
)

type youdaoHTTPClient_ = *http.Client

var youdaoHTTPClient youdaoHTTPClient_

type youdaoKeyResponse struct {
	Data struct {
		SecretKey string `json:"secretKey"`
		AesKey    string `json:"aesKey"`
		AesIv     string `json:"aesIv"`
	} `json:"data"`
}

type youdaoKeyCache struct {
	SecretKey string `json:"secretKey"`
	AesKey    string `json:"aesKey"`
	AesIv     string `json:"aesIv"`
}

type youdaoTranResult struct {
	TranslateResult [][]struct {
		Src string `json:"src"`
		Tgt string `json:"tgt"`
	} `json:"translateResult"`
	Type string `json:"type"`
}

func youdaoProxyClient() *http.Client {
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

func youdaoGetHTTPClient() *http.Client {
	if youdaoHTTPClient == nil {
		youdaoHTTPClient = youdaoProxyClient()
	}
	return youdaoHTTPClient
}

func youdaoNormalizeLang(lang string) string {
	switch lang {
	case "zh", "zh-CN":
		return "zh-CHS"
	case "zh-TW":
		return "zh-CHT"
	}
	return lang
}

func youdaoMD5(str string) string {
	h := md5.Sum([]byte(str))
	return fmt.Sprintf("%x", h)
}

func youdaoGetKey(renew bool) (*youdaoKeyCache, error) {
	keyfile := filepath.Join(os.TempDir(), youdaoKeyFile)
	if !renew {
		data, err := os.ReadFile(keyfile)
		if err == nil && len(data) > 0 {
			var cache youdaoKeyCache
			if json.Unmarshal(data, &cache) == nil && cache.AesKey != "" {
				return &cache, nil
			}
		}
	}

	mysticTime := strconv.FormatInt(time.Now().UnixMilli(), 10)
	signStr := fmt.Sprintf("client=%s&mysticTime=%s&product=%s&key=%s",
		youdaoClient, mysticTime, youdaoProduct, youdaoSecretKey)
	sign := youdaoMD5(signStr)

	params := url.Values{}
	params.Set("keyid", "webfanyi-key-getter")
	params.Set("pointParam", "client,mysticTime,product")
	params.Set("client", youdaoClient)
	params.Set("product", youdaoProduct)
	params.Set("mysticTime", mysticTime)
	params.Set("sign", sign)

	reqURL := youdaoKeyURL + "?" + params.Encode()
	req, err := http.NewRequest("GET", reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("youdao_get_key: create request: %w", err)
	}
	req.Header.Set("User-Agent", youdaoUA)
	req.Header.Set("Referer", "https://fanyi.youdao.com/")

	resp, err := youdaoGetHTTPClient().Do(req)
	if err != nil {
		return nil, fmt.Errorf("youdao_get_key: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("youdao_get_key: http %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("youdao_get_key: read body: %w", err)
	}

	var keyResp youdaoKeyResponse
	if err := json.Unmarshal(body, &keyResp); err != nil {
		return nil, fmt.Errorf("youdao_get_key: decode: %w", err)
	}
	if keyResp.Data.AesKey == "" {
		return nil, fmt.Errorf("youdao_get_key: empty aes key")
	}

	cache := &youdaoKeyCache{
		SecretKey: keyResp.Data.SecretKey,
		AesKey:    keyResp.Data.AesKey,
		AesIv:     keyResp.Data.AesIv,
	}

	cacheData, _ := json.Marshal(cache)
	_ = os.WriteFile(keyfile, cacheData, 0644)

	return cache, nil
}

func youdaoDecryptText(encrypted string, aesKeyB64, aesIvB64 string) (string, error) {
	txt := strings.ReplaceAll(encrypted, "-", "+")
	txt = strings.ReplaceAll(txt, "_", "/")

	ciphertext, err := base64.StdEncoding.DecodeString(txt)
	if err != nil {
		return "", fmt.Errorf("youdao_decrypt: base64 decode: %w", err)
	}

	// Reference: https://github.com/HaleShaw/uTools-Translate/blob/main/preload.js
	// AES_CBC_Decrypt uses CryptoJS.MD5(secretKey) as key, CryptoJS.MD5(iv) as iv
	keyHash := md5.Sum([]byte(aesKeyB64))
	ivHash := md5.Sum([]byte(aesIvB64))
	key := keyHash[:]
	iv := ivHash[:]

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", fmt.Errorf("youdao_decrypt: new cipher: %w", err)
	}

	if len(ciphertext) < aes.BlockSize {
		return "", fmt.Errorf("youdao_decrypt: ciphertext too short")
	}

	mode := cipher.NewCBCDecrypter(block, iv)
	mode.CryptBlocks(ciphertext, ciphertext)

	// remove PKCS7 padding
	if len(ciphertext) > 0 {
		padding := int(ciphertext[len(ciphertext)-1])
		if padding >= 1 && padding <= aes.BlockSize && padding <= len(ciphertext) {
			valid := true
			for i := len(ciphertext) - padding; i < len(ciphertext); i++ {
				if ciphertext[i] != byte(padding) {
					valid = false
					break
				}
			}
			if valid {
				ciphertext = ciphertext[:len(ciphertext)-padding]
			}
		}
	}

	return string(ciphertext), nil
}

func youdaoBuildTranParams(text string, keys *youdaoKeyCache) url.Values {
	mysticTime := strconv.FormatInt(time.Now().UnixMilli(), 10)
	signStr := fmt.Sprintf("client=%s&mysticTime=%s&product=%s&key=%s",
		youdaoClient, mysticTime, youdaoProduct, keys.SecretKey)
	sign := youdaoMD5(signStr)

	params := url.Values{}
	params.Set("i", text)
	params.Set("from", "auto")
	params.Set("to", "auto")
	params.Set("keyid", "webfanyi")
	params.Set("appVersion", "1.0.0")
	params.Set("vendor", "web")
	params.Set("pointParam", "client,mysticTime,product")
	params.Set("keyfrom", "fanyi.web")
	params.Set("client", youdaoClient)
	params.Set("product", youdaoProduct)
	params.Set("mysticTime", mysticTime)
	params.Set("sign", sign)
	return params
}

func YoudaoTranFull(tolang, fromlang string, texts ...string) ([]string, error) {
	if tolang == "" {
		return nil, fmt.Errorf("youdao_tran_full: tolang is empty")
	}
	if len(texts) == 0 {
		return nil, fmt.Errorf("youdao_tran_full: no texts")
	}

	tolang = youdaoNormalizeLang(tolang)
	if fromlang != "" {
		fromlang = youdaoNormalizeLang(fromlang)
	}

	for retry := 0; retry <= 1; retry++ {
		keys, err := youdaoGetKey(retry > 0)
		if err != nil {
			return nil, fmt.Errorf("youdao_tran_full: get key: %w", err)
		}

		for _, text := range texts {
			if len([]rune(text)) > youdaoMaxLen {
				return nil, fmt.Errorf("youdao_tran_full: text too long (%d > %d)", len([]rune(text)), youdaoMaxLen)
			}
		}

		allResults := []string{}
		for _, text := range texts {
			params := youdaoBuildTranParams(text, keys)

			// override from/to if specified
			if fromlang != "" {
				params.Set("from", fromlang)
			}
			if tolang != "" {
				params.Set("to", tolang)
			}

			bodyStr := params.Encode()
			req, err := http.NewRequest("POST", youdaoAPIURL, strings.NewReader(bodyStr))
			if err != nil {
				return nil, fmt.Errorf("youdao_tran_full: create request: %w", err)
			}
			req.Header.Set("User-Agent", youdaoUA)
			req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
			req.Header.Set("Referer", "https://fanyi.youdao.com/")
			req.Header.Set("Cookie", "OUTFOX_SEARCH_USER_ID=0@127.0.0.1")

			resp, err := youdaoGetHTTPClient().Do(req)
			if err != nil {
				return nil, fmt.Errorf("youdao_tran_full: %w", err)
			}

			respBody, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil {
				return nil, fmt.Errorf("youdao_tran_full: read body: %w", err)
			}

			if resp.StatusCode != 200 {
				if retry == 0 {
					_ = os.Remove(filepath.Join(os.TempDir(), youdaoKeyFile))
					continue
				}
				return nil, fmt.Errorf("youdao_tran_full: http %d: %s", resp.StatusCode, string(respBody))
			}

			plainText, err := youdaoDecryptText(string(respBody), keys.AesKey, keys.AesIv)
			if err != nil {
				if retry == 0 {
					_ = os.Remove(filepath.Join(os.TempDir(), youdaoKeyFile))
					continue
				}
				return nil, fmt.Errorf("youdao_tran_full: decrypt: %w", err)
			}

			var result youdaoTranResult
			if err := json.Unmarshal([]byte(plainText), &result); err != nil {
				return nil, fmt.Errorf("youdao_tran_full: decode: %w", err)
			}

			if len(result.TranslateResult) == 0 || len(result.TranslateResult[0]) == 0 {
				return nil, fmt.Errorf("youdao_tran_full: empty translate result")
			}

			var sb strings.Builder
			for _, seg := range result.TranslateResult[0] {
				sb.WriteString(seg.Tgt)
			}
			allResults = append(allResults, sb.String())
		}

		return allResults, nil
	}
	return nil, fmt.Errorf("youdao_tran_full: retry exhausted")
}

func YoudaoTran(text string) (string, error) {
	res, err := YoudaoTranFull("zh", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func YoudaoTranEn(text string) (string, error) {
	res, err := YoudaoTranFull("en", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func YoudaoGlobalCleanup() {
	youdaoHTTPClient = nil
	_ = os.Remove(filepath.Join(os.TempDir(), youdaoKeyFile))
}
