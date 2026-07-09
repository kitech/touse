package oai

import (
	"encoding/json"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	googleAuthURL = "https://translate.googleapis.com/_/translate_http/_/js/k=translate_http.tr.en_US.YusFYy3P_ro.O/am=AAg/d=1/exm=el_conf/ed=1/rs=AN8SPfq1Hb8iJRleQqQc8zhdzXmF9E56eQ/m=el_main"
	googleAPIBase = "https://translate-pa.googleapis.com/v1/translateHtml"
	googleUA      = "msie 6"

	googleFallbackKey = "AIzaSyATBXajvzQLTDHEQbcpq0Ihe0vWDHmO520"

	googleKeyTTLOK        = 20 * time.Minute
	googleKeyTTLNotFound  = 5 * time.Minute
	googleKeyTTLDefault   = 1 * time.Minute
)

var (
	googleHTTPClient  *http.Client
	googleAPIKey      string
	googleKeyTime     int64
	googleKeyNotFound bool
)

func googleGetHTTPClient() *http.Client {
	if googleHTTPClient == nil {
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
				googleHTTPClient = &http.Client{Transport: transport, Timeout: 30 * time.Second}
			}
		}
		if googleHTTPClient == nil {
			googleHTTPClient = &http.Client{Timeout: 30 * time.Second}
		}
	}
	return googleHTTPClient
}

func googleShouldRefresh() bool {
	if googleKeyTime == 0 {
		return true
	}
	elapsed := time.Since(time.Unix(0, googleKeyTime))
	if googleAPIKey != "" {
		return elapsed >= googleKeyTTLOK
	} else if googleKeyNotFound {
		return elapsed >= googleKeyTTLNotFound
	}
	return elapsed >= googleKeyTTLDefault
}

func googleGetAPIKey(renew bool) (string, error) {
	if !renew && googleAPIKey != "" && !googleShouldRefresh() {
		return googleAPIKey, nil
	}
	if renew || googleShouldRefresh() {
		googleKeyTime = time.Now().UnixNano()

		req, err := http.NewRequest("GET", googleAuthURL, nil)
		if err != nil {
			googleAPIKey = googleFallbackKey
			return googleAPIKey, nil
		}
		req.Header.Set("User-Agent", googleUA)
		resp, err := googleGetHTTPClient().Do(req)
		if err != nil {
			googleAPIKey = googleFallbackKey
			googleKeyNotFound = true
			return googleAPIKey, nil
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil || resp.StatusCode != 200 {
			googleAPIKey = googleFallbackKey
			googleKeyNotFound = true
			return googleAPIKey, nil
		}

		re := regexp.MustCompile(`['"]x-goog-api-key['"]\s*:\s*['"](\w{39})['"]`)
		matches := re.FindStringSubmatch(string(body))
		if len(matches) >= 2 {
			googleAPIKey = matches[1]
			googleKeyNotFound = false
		} else {
			googleAPIKey = googleFallbackKey
			googleKeyNotFound = true
		}
	}
	return googleAPIKey, nil
}

func googleFormatTexts(texts []string) string {
	escaped := make([]string, len(texts))
	for i, t := range texts {
		escaped[i] = html.EscapeString(t)
	}
	if len(escaped) > 1 {
		for i, t := range escaped {
			escaped[i] = fmt.Sprintf(`<a i=%d>%s</a>`, i, t)
		}
	}
	return "<pre>" + strings.Join(escaped, "") + "</pre>"
}

func googleExtractTexts(htmlStr string) []string {
	htmlStr = strings.TrimPrefix(htmlStr, "<pre>")
	htmlStr = strings.TrimSuffix(htmlStr, "</pre>")
	htmlStr = strings.TrimSpace(htmlStr)

	re := regexp.MustCompile(`<a\s+i=(\d+)>([^<]*)</a>`)
	matches := re.FindAllStringSubmatch(htmlStr, -1)

	if len(matches) == 0 {
		cleaned := strings.NewReplacer("<b>", "", "</b>", "", "<i>", "", "</i>", "").Replace(htmlStr)
		return []string{html.UnescapeString(strings.TrimSpace(cleaned))}
	}

	type seg struct {
		idx  int
		text string
	}
	segs := make([]seg, len(matches))
	for i, m := range matches {
		idx, _ := strconv.Atoi(m[1])
		segs[i] = seg{idx, html.UnescapeString(m[2])}
	}

	sort.Slice(segs, func(i, j int) bool {
		return segs[i].idx < segs[j].idx
	})

	maxIdx := segs[len(segs)-1].idx
	buckets := make([][]string, maxIdx+1)
	for _, s := range segs {
		buckets[s.idx] = append(buckets[s.idx], s.text)
	}

	result := make([]string, len(buckets))
	for i, b := range buckets {
		result[i] = strings.TrimSpace(strings.Join(b, " "))
	}
	return result
}

func googleNormalizeLang(lang string) string {
	if lang == "prs" {
		return "fa-AF"
	}
	return lang
}

func GoogleTranFull(tolang, fromlang string, texts ...string) ([]string, error) {
	if tolang == "" {
		return nil, fmt.Errorf("google_tran_full: tolang is empty")
	}
	if len(texts) == 0 {
		return nil, fmt.Errorf("google_tran_full: no texts")
	}

	tolang = googleNormalizeLang(tolang)
	if fromlang != "" {
		fromlang = googleNormalizeLang(fromlang)
	}

	key, err := googleGetAPIKey(false)
	if err != nil {
		return nil, fmt.Errorf("google_tran_full: get key: %w", err)
	}

	formatted := googleFormatTexts(texts)

	bodyArr := []interface{}{
		[]interface{}{
			[]string{formatted},
			fromlang,
			tolang,
		},
		"te",
	}
	jsonBody, err := json.Marshal(bodyArr)
	if err != nil {
		return nil, fmt.Errorf("google_tran_full: marshal: %w", err)
	}

	for retry := 0; retry <= 1; retry++ {
		req, err := http.NewRequest("POST", googleAPIBase, strings.NewReader(string(jsonBody)))
		if err != nil {
			return nil, fmt.Errorf("google_tran_full: create request: %w", err)
		}
		req.Header.Set("User-Agent", googleUA)
		req.Header.Set("Content-Type", "application/application/json+protobuf")
		req.Header.Set("X-goog-api-key", key)

		resp, err := googleGetHTTPClient().Do(req)
		if err != nil {
			return nil, fmt.Errorf("google_tran_full: %w", err)
		}

		respBody, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return nil, fmt.Errorf("google_tran_full: read body: %w", err)
		}

		if resp.StatusCode != 200 {
			key, _ = googleGetAPIKey(true)
			if retry == 0 {
				continue
			}
			return nil, fmt.Errorf("google_tran_full: http %d: %s", resp.StatusCode, string(respBody))
		}

		var raw []json.RawMessage
		if err := json.Unmarshal(respBody, &raw); err != nil {
			return nil, fmt.Errorf("google_tran_full: decode: %w", err)
		}
		if len(raw) < 1 {
			return nil, fmt.Errorf("google_tran_full: empty response array")
		}

		var textsArr []string
		if err := json.Unmarshal(raw[0], &textsArr); err != nil {
			return nil, fmt.Errorf("google_tran_full: decode texts: %w", err)
		}
		if len(textsArr) == 0 {
			return nil, fmt.Errorf("google_tran_full: empty texts")
		}

		results := googleExtractTexts(textsArr[0])
		return results, nil
	}
	return nil, fmt.Errorf("google_tran_full: retry exhausted")
}

func GoogleTran(text string) (string, error) {
	res, err := GoogleTranFull("zh", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func GoogleTranEn(text string) (string, error) {
	res, err := GoogleTranFull("en", "", text)
	if err != nil {
		return "", err
	}
	return res[0], nil
}

func GoogleGlobalCleanup() {
	googleHTTPClient = nil
	googleAPIKey = ""
	googleKeyTime = 0
	googleKeyNotFound = false
}
