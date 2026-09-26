// 有道网页翻译（dict.youdao.com/webtranslate），免注册、免 key。
// 参数与算法出处，2026-09-26 全部实测跑通：
//   - keyid / 产品密钥 / 固定参数 / appVersion：取自线上 app bundle
//     https://shared.ydstatic.com/dict/translation-website/<版本>/js/app.<hash>.js
//     （当前 1.0.7，内含 keyid="webfanyi-key-getter-2025"、密钥 yU5nT5dK3eZ1pI4j）
//   - 备选链路，本文件未实现，留作接口被废时的参考：
//     新一代（SSE 流式，带 ydtoken）：
//     https://dict-trans.youdao.com/translate/key 与 /webtranslate/sse
//     keyid=translate-webfanyi-webmain，密钥 kSy5gtKA4yRUxAVPJPrdYKZ0jBKyd3t1
//     AI 翻译：https://luna-ai.youdao.com/translate_llm/secret + /translate_llm/v3/chat
//     keyid=ai-translate-llm，密钥 LqMQV3ZdE2X6DYYyc6TNsVbHgCGk7XzG
//
// 关键参考项目：
//   - keyid/密钥的抓取与轮换分析：https://himpqblog.cn/index.php/archives/827
//   - AES-128-CBC 解密（key=MD5(aesKey)、iv=MD5(aesIv)）：https://www.52pojie.cn/thread-1902605-1-1.html
//   - preload.js 里的 CryptoJS 用法：https://github.com/HaleShaw/uTools-Translate
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
	youdaoWarmURL    = "https://fanyi.youdao.com/"
	youdaoUA         = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
	youdaoReferer    = "https://fanyi.youdao.com/"
	youdaoKeyFile    = "youdao_web_key.txt"
	youdaoClient     = "fanyideskweb"
	youdaoProduct    = "webfanyi"
	youdaoAppVersion = "12.0.0"
	youdaoUserID     = "OUTFOX_SEARCH_USER_ID"
	youdaoFakeCookie = "OUTFOX_SEARCH_USER_ID=0@127.0.0.1"

	// 单次请求的切块阈值（rune 数）。实测有道 web 接口单请求硬上限为 20000 字符：
	// 19988 字符 code=0 完整、20046 字符 code=20 被拒，中英文边界一致（19989 通 /
	// 20097 拒），所以这是纯字符数限制、与语种无关；超限时服务端直接回空结果
	// （code 20），不是截断也不是报错文本。
	// 取 18000 是留约 10% 余量避开边界抖动；超过本值的输入由 youdaoSplitText 切块。
	// 单发 17871 字符实测 0.45s，拆 4×5000 要 1.37s，故不再用 5000 这种保守值。
	youdaoMaxLen = 18000
)

// product keyid/secret pairs, newest first; webfanyi-key-getter is the 2023 legacy pair
var youdaoKeyPairs = []struct {
	KeyID     string
	SecretKey string
}{
	{"webfanyi-key-getter-2025", "yU5nT5dK3eZ1pI4j"},
	{"webfanyi-key-getter", "asdjnjfenknafdfsdfsd"},
}

var youdaoHTTPClient *http.Client

type youdaoKeyResponse struct {
	Data struct {
		SecretKey string `json:"secretKey"`
		AesKey    string `json:"aesKey"`
		AesIv     string `json:"aesIv"`
	} `json:"data"`
}

// 注意：缓存里的 cookie 没有失效期，缓存文件放久了会一直喂过期的
// OUTFOX_SEARCH_USER_ID。此时有道对每次请求都回 code 50，且光换 key 救不回来
// （key 会变，cookie 不会变）。实测对照：不带 cookie 连打 8 次，8/8 都是 code 50。
// 真出现时怎么修：加一个 Time 字段，缓存超过约 30 分钟就重新预热 cookie。
type youdaoKeyCache struct {
	SecretKey string `json:"secretKey"`
	AesKey    string `json:"aesKey"`
	AesIv     string `json:"aesIv"`
	Cookie    string `json:"cookie"`
}

// 本接口的 code 没有公开文档，值为实测所得：0 成功、20 超过单请求 20000 字符上限、
// 40 过长/不可译、50 风控拒。
// 别与官方 openapi 的 errorMessage(11/12/14/30/31) 混用，那是另一套错误码
// （对照 https://ai.youdao.com/DOCSIRMA/html/trans/api/wyfy/index.html）。
type youdaoTranResult struct {
	Code            int `json:"code"`
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

func youdaoCachePath() string {
	return filepath.Join(os.TempDir(), youdaoKeyFile)
}

func youdaoInvalidateCache() {
	_ = os.Remove(youdaoCachePath())
}

// 没有真实的 OUTFOX_SEARCH_USER_ID cookie 时有道会直接拒掉（code 50），这不是频率限制。
// 实测 2026-09-26：预热 cookie 后串行 200 次、并发 30 次（5 线程）全部 code 0，一次限流
// 都没碰到；完全不预热 cookie 的对照组 8/8 全是 code 50。
func youdaoWarmCookie() string {
	req, err := http.NewRequest("GET", youdaoWarmURL, nil)
	if err != nil {
		return youdaoFakeCookie
	}
	req.Header.Set("User-Agent", youdaoUA)
	resp, err := youdaoGetHTTPClient().Do(req)
	if err != nil {
		return youdaoFakeCookie
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	for _, c := range resp.Cookies() {
		if c.Name == youdaoUserID && c.Value != "" {
			return c.Name + "=" + c.Value
		}
	}
	return youdaoFakeCookie
}

func youdaoGetKey(renew bool) (*youdaoKeyCache, error) {
	keyfile := youdaoCachePath()
	if !renew {
		data, err := os.ReadFile(keyfile)
		if err == nil && len(data) > 0 {
			var cache youdaoKeyCache
			if json.Unmarshal(data, &cache) == nil && cache.AesKey != "" {
				return &cache, nil
			}
		}
	}

	cookie := youdaoWarmCookie()
	mysticTime := strconv.FormatInt(time.Now().UnixMilli(), 10)

	for _, pair := range youdaoKeyPairs {
		signStr := fmt.Sprintf("client=%s&mysticTime=%s&product=%s&key=%s",
			youdaoClient, mysticTime, youdaoProduct, pair.SecretKey)
		sign := youdaoMD5(signStr)

		params := url.Values{}
		params.Set("keyid", pair.KeyID)
		params.Set("pointParam", "client,mysticTime,product")
		params.Set("client", youdaoClient)
		params.Set("product", youdaoProduct)
		params.Set("mysticTime", mysticTime)
		params.Set("sign", sign)

		req, err := http.NewRequest("GET", youdaoKeyURL+"?"+params.Encode(), nil)
		if err != nil {
			return nil, fmt.Errorf("youdao_get_key: create request: %w", err)
		}
		req.Header.Set("User-Agent", youdaoUA)
		req.Header.Set("Referer", youdaoReferer)
		req.Header.Set("Cookie", cookie)

		resp, err := youdaoGetHTTPClient().Do(req)
		if err != nil {
			return nil, fmt.Errorf("youdao_get_key: %w", err)
		}
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return nil, fmt.Errorf("youdao_get_key: read body: %w", err)
		}
		if resp.StatusCode != 200 {
			continue
		}

		var keyResp youdaoKeyResponse
		if err := json.Unmarshal(body, &keyResp); err != nil {
			continue
		}
		if keyResp.Data.AesKey == "" {
			continue
		}

		cache := &youdaoKeyCache{
			SecretKey: keyResp.Data.SecretKey,
			AesKey:    keyResp.Data.AesKey,
			AesIv:     keyResp.Data.AesIv,
			Cookie:    cookie,
		}
		if cacheData, err := json.Marshal(cache); err == nil {
			_ = os.WriteFile(keyfile, cacheData, 0644)
		}
		return cache, nil
	}
	return nil, fmt.Errorf("youdao_get_key: no usable keyid (tried %d)", len(youdaoKeyPairs))
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
	params.Set("appVersion", youdaoAppVersion)
	params.Set("vendor", "web")
	params.Set("pointParam", "client,mysticTime,product")
	params.Set("keyfrom", "fanyi.web")
	params.Set("client", youdaoClient)
	params.Set("product", youdaoProduct)
	params.Set("mysticTime", mysticTime)
	params.Set("sign", sign)
	params.Set("mid", "1")
	params.Set("screen", "1")
	params.Set("model", "1")
	params.Set("network", "wifi")
	params.Set("abtest", "0")
	params.Set("yduuid", "abcdefg")
	params.Set("dictResult", "true")
	return params
}

// translateResult holds one inner array per input line and each tgt keeps its own
// trailing newline, so lines must be concatenated with "" (not "\n").
func youdaoJoinLines(result *youdaoTranResult) string {
	var sb strings.Builder
	for _, line := range result.TranslateResult {
		for _, seg := range line {
			sb.WriteString(seg.Tgt)
		}
	}
	return sb.String()
}

// type looks like "en2zh-CHS"
func youdaoSrcLang(typeStr string) string {
	if i := strings.Index(typeStr, "2"); i > 0 {
		return typeStr[:i]
	}
	return ""
}

var youdaoSplitMarks = map[rune]bool{
	'\n': true, '。': true, '！': true, '？': true, '；': true,
	'.': true, '!': true, '?': true, ';': true,
}

// cuts keep the punctuation in the chunk, so joining chunks with "" restores the text
func youdaoSplitText(text string, limit int) []string {
	runes := []rune(text)
	if len(runes) <= limit {
		return []string{text}
	}
	chunks := []string{}
	for start := 0; start < len(runes); {
		if len(runes)-start <= limit {
			chunks = append(chunks, string(runes[start:]))
			break
		}
		cut, best := start+limit, -1
		for m := start + limit/2; m < cut; m++ {
			if youdaoSplitMarks[runes[m]] {
				best = m
			}
		}
		if best > start {
			cut = best + 1
		}
		chunks = append(chunks, string(runes[start:cut]))
		start = cut
	}
	return chunks
}

func youdaoTranOnce(tolang, fromlang string, keys *youdaoKeyCache, text string) (*youdaoTranResult, error) {
	params := youdaoBuildTranParams(text, keys)
	if fromlang != "" {
		params.Set("from", fromlang)
	}
	if tolang != "" {
		params.Set("to", tolang)
	}

	req, err := http.NewRequest("POST", youdaoAPIURL, strings.NewReader(params.Encode()))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("User-Agent", youdaoUA)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Referer", youdaoReferer)
	if keys.Cookie != "" {
		req.Header.Set("Cookie", keys.Cookie)
	}

	resp, err := youdaoGetHTTPClient().Do(req)
	if err != nil {
		return nil, fmt.Errorf("request: %w", err)
	}
	respBody, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("http %d: %s", resp.StatusCode, string(respBody))
	}

	plainText, err := youdaoDecryptText(string(respBody), keys.AesKey, keys.AesIv)
	if err != nil {
		return nil, fmt.Errorf("decrypt: %w", err)
	}
	var result youdaoTranResult
	if err := json.Unmarshal([]byte(plainText), &result); err != nil {
		return nil, fmt.Errorf("decode: %w", err)
	}
	return &result, nil
}

func YoudaoTranFullType(tolang, fromlang string, texts ...string) ([]string, string, error) {
	if tolang == "" {
		return nil, "", fmt.Errorf("youdao_tran_full: tolang is empty")
	}
	if len(texts) == 0 {
		return nil, "", fmt.Errorf("youdao_tran_full: no texts")
	}

	tolang = youdaoNormalizeLang(tolang)
	if fromlang != "" {
		fromlang = youdaoNormalizeLang(fromlang)
	}

	results := make([]string, 0, len(texts))
	srclang := ""

	// 当前的三个限制，2026-09-26 实测后确认的：
	//  1. 没有任何速率控制。预热 cookie 后有道就没限流过，所以没加节流。
	//  2. 重试只有 1 次且不打 sleep，等于"立刻换 key 再打一发"，一旦有道收紧风控这是最容易
	//     继续撞墙的姿势；要治就加 time.Sleep(1<<retry) 指数退避 + 随机抖动，重试提到 3 次。
	//  3. 某条文本失败会中止整批，没有"跳过失败项、继续处理其余"的逻辑，
	//     所以一次被拦下会连带这批里所有文本一起失败。
retryLoop:
	for retry := 0; retry <= 1; retry++ {
		keys, err := youdaoGetKey(retry > 0)
		if err != nil {
			return nil, "", fmt.Errorf("youdao_tran_full: get key: %w", err)
		}

		results = results[:0]
		srclang = ""

		for _, text := range texts {
			parts := youdaoSplitText(text, youdaoMaxLen)
			merged := make([]string, 0, len(parts))
			for _, part := range parts {
				result, err := youdaoTranOnce(tolang, fromlang, keys, part)
				if err != nil {
					if retry == 0 {
						youdaoInvalidateCache()
						continue retryLoop
					}
					return nil, "", fmt.Errorf("youdao_tran_full: %w", err)
				}
				if result.Code != 0 {
					// code 20 = 超过服务端单请求字符上限（实测 20000），换 key 无意义故不重试；
					// 正常情况下 youdaoSplitText 已按 youdaoMaxLen 切块不该触发，
					// 触发说明上限变了，报错要能直接看出是这个原因。
					if result.Code == 20 {
						return nil, "", fmt.Errorf(
							"youdao_tran_full: api code 20 (text too long, server limit ~20000 chars, chunk size is %d)",
							youdaoMaxLen)
					}
					// code 40 = 过长/不可译，50 = 被风控拒掉（50 的常见原因是 cookie 缺失或过期，
					// 而非请求太频繁）。两者只换新 key 重试 1 次，再失败直接报错。
					if (result.Code == 40 || result.Code == 50) && retry == 0 {
						youdaoInvalidateCache()
						continue retryLoop
					}
					return nil, "", fmt.Errorf("youdao_tran_full: api code %d", result.Code)
				}
				if len(result.TranslateResult) == 0 {
					return nil, "", fmt.Errorf("youdao_tran_full: empty translate result")
				}
				if srclang == "" {
					srclang = youdaoSrcLang(result.Type)
				}
				merged = append(merged, youdaoJoinLines(result))
			}
			results = append(results, strings.Join(merged, ""))
		}

		return results, srclang, nil
	}
	return nil, "", fmt.Errorf("youdao_tran_full: retry exhausted")
}

func YoudaoTranFull(tolang, fromlang string, texts ...string) ([]string, error) {
	res, _, err := YoudaoTranFullType(tolang, fromlang, texts...)
	return res, err
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
	youdaoInvalidateCache()
}
