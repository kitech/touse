// netpkgman.v 是 zpkg 包的联网搜索库，仅提供公共 API，不含 main 函数。
import os
import time
import rand
import strings
import json
import encoding.html
import net.urllib
import vcp.curlv

pub const fp_ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

pub const net_managers = ['nix', 'pypi', 'npm', 'aur', 'vpm', 'canon', 'zig', 'rspm', 'jvpm', 'jspm']

const cache_ttl_ms = i64(60_000)
const min_gap_ms = i64(350)
const jitter_ms = 250
const max_retries = 2
const default_limit = 20
const max_limit = 250
const max_query_len = 200

const html_accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
const json_accept = 'application/json,text/plain,*/*'

pub struct NetPkg {
pub:
	manager string
	name    string
	version string
	desc    string
	url     string
	updated string
}

pub struct SearchOutcome {
pub:
	manager string
	query   string
	ok      bool
	items   []NetPkg
	err     string
}

struct CacheEntry {
	at   i64
	body string
}

struct Client {
mut:
	last  map[string]i64
	cache map[string]CacheEntry
}

struct NpmLinks {
	npm      string
	homepage string
}

struct NpmPackage {
	name        string
	version     string
	description string
	date        string
	links       NpmLinks
}

struct NpmObject {
	package NpmPackage
}

struct NpmResp {
	objects []NpmObject
}

struct AurResult {
	name         string @[json: 'Name']
	description  string @[json: 'Description']
	url          string @[json: 'URL']
	version      string @[json: 'Version']
	last_modified i64   @[json: 'LastModified']
}

struct AurResp {
	typ     string @[json: 'type']
	reason  string @[json: 'error']
	results []AurResult
}

struct ConanInfo {
	version     string
	description string
	timestamp   string
}

struct ConanEntry {
	name string
	info ConanInfo
}

struct Crate {
	name        string
	description string
	max_version string @[json: 'max_version']
	updated_at  string @[json: 'updated_at']
	repository  string
	homepage    string
}

struct CratesResp {
	crates []Crate
}

struct MavenDoc {
	id            string
	g             string
	a             string
	latest_version string @[json: 'latestVersion']
	timestamp     i64
}

struct MavenResponse {
	docs []MavenDoc
}

struct MavenResp {
	response MavenResponse
}

pub fn manager_names() []string {
	return net_managers.clone()
}

pub fn search(manager string, q string, limit int) ![]NetPkg {
	return search_with(new_client(), manager, q, limit)
}

pub fn search_all(q string, limit int) []SearchOutcome {
	c := new_client()
	mut out := []SearchOutcome{}
	nq := normalize_query(q) or {
		for m in net_managers {
			out << SearchOutcome{
				manager: m
				query: q
				ok: false
				items: []
				err: err.str()
			}
		}
		return out
	}
	for m in net_managers {
		items := search_with(c, m, nq, limit) or {
			out << SearchOutcome{
				manager: m
				query: nq
				ok: false
				items: []
				err: err.str()
			}
			continue
		}
		out << SearchOutcome{
			manager: m
			query: nq
			ok: true
			items: items
			err: ''
		}
	}
	return out
}

fn new_client() &Client {
	return &Client{
		last: map[string]i64{}
		cache: map[string]CacheEntry{}
	}
}

fn search_with(c &Client, manager string, raw_q string, limit int) ![]NetPkg {
	q := normalize_query(raw_q) !
	n := clamp_limit(limit)
	match manager {
		'npm' {
			return adapter_npm_registry(c, 'npm', q, n)
		}
		'jspm' {
			return adapter_npm_registry(c, 'jspm', q, n)
		}
		'aur' {
			return adapter_aur(c, q, n)
		}
		'canon' {
			return adapter_conan(c, q, n)
		}
		'rspm' {
			return adapter_rspm(c, q, n)
		}
		'jvpm' {
			return adapter_jvpm(c, q, n)
		}
		'pypi' {
			return adapter_pypi(c, q, n)
		}
		'nix' {
			return adapter_nix(c, q, n)
		}
		'zig' {
			return adapter_zig(c, q, n)
		}
		'vpm' {
			return adapter_vpm(c, q, n)
		}
		else {
			return error('未知包管理器: $manager')
		}
	}
}

fn normalize_query(raw string) !string {
	mut b := strings.new_builder(raw.len)
	mut pending_space := false
	for i := 0; i < raw.len; i++ {
		c := raw[i]
		if c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == 0x0b || c == 0x0c {
			if b.len > 0 {
				pending_space = true
			}
			continue
		}
		if c < 0x20 || c == 0x7f {
			return error('关键词包含控制字符')
		}
		if pending_space {
			b.write_byte(` `)
			pending_space = false
		}
		b.write_byte(c)
	}
	q := b.str()
	if q.len == 0 {
		return error('关键词不能为空')
	}
	if q.len > max_query_len {
		return error('关键词过长，上限 $max_query_len 字节')
	}
	return q
}

fn enc_query(q string) string {
	return urllib.query_escape(q)
}

fn enc_path(q string) string {
	return urllib.path_escape(q).replace('+', '%2B')
}

fn clamp_limit(n int) int {
	if n <= 0 {
		return default_limit
	}
	if n > max_limit {
		return max_limit
	}
	return n
}

fn host_of(url string) string {
	i := url.index('://') or {
		return ''
	}
	s := url[i + 3..]
	j := s.index('/') or {
		return s
	}
	return s[..j]
}

fn proxy_addr() string {
	for k in ['NETPKG_PROXY', 'HTTPS_PROXY', 'https_proxy', 'HTTP_PROXY', 'http_proxy'] {
		v := os.getenv(k)
		if v != '' {
			return v
		}
	}
	return ''
}

fn is_challenge(body string) bool {
	return body.contains('_fs-ch-') || body.contains('Client Challenge')
}

fn (c &Client) wait(host string) {
	now := time.now().unix_milli()
	prev := c.last[host]
	gap := min_gap_ms + i64(rand.intn(jitter_ms) or { 0 })
	if prev > 0 {
		left := prev + gap - now
		if left > 0 {
			time.sleep(time.Duration(left) * time.millisecond)
		}
	}
	c.last[host] = time.now().unix_milli()
}

fn (c &Client) fetch(url string, referer string, accept string) !string {
	key := '$accept|$url'
	e := c.cache[key]
	if e.at > 0 && time.now().unix_milli() - e.at < cache_ttl_ms {
		return e.body
	}
	host := host_of(url)
	mut last_err := ''
	for attempt := 0; attempt <= max_retries; attempt++ {
		c.wait(host)
		mut ch := curlv.new()
		ch.url(url)
		ch.useragent(fp_ua)
		ch.header('Accept', accept)
		ch.header('Accept-Language', 'en-US,en;q=0.9')
		ch.header('Sec-CH-UA', '"Chromium";v="126", "Google Chrome";v="126", "Not-A.Brand";v="99"')
		ch.header('Sec-CH-UA-Mobile', '?0')
		ch.header('Sec-CH-UA-Platform', '"Linux"')
		ch.header('Sec-Fetch-Dest', 'document')
		ch.header('Sec-Fetch-Mode', 'navigate')
		ch.header('Sec-Fetch-Site', 'none')
		ch.header('Sec-Fetch-User', '?1')
		ch.header('Upgrade-Insecure-Requests', '1')
		ch.header('Priority', 'u=0, i')
		ch.header('Cache-Control', 'max-age=0')
		if referer != '' {
			ch.refer(referer)
		}
		px := proxy_addr()
		if px != '' {
			ch.proxy(px)
		}
		ch.timeout(20)
		res := ch.get() or {
			last_err = err.str()
			continue
		}
		if res.stcode == 200 {
			if is_challenge(res.data) {
				return error('反爬挑战页（Client Challenge），无法解析结果')
			}
			c.cache[key] = CacheEntry{at: time.now().unix_milli(), body: res.data}
			return res.data
		}
		last_err = 'HTTP $res.stcode'
		if (res.stcode == 429 || res.stcode >= 500) && attempt < max_retries {
			time.sleep(time.Duration(200 * (1 << attempt)) * time.millisecond)
			continue
		}
		return error(last_err)
	}
	return error('请求失败: $last_err')
}

fn cut_between(s string, open string, close string, from int) string {
	a := s.index_after(open, from) or {
		return ''
	}
	st := a + open.len
	b := s.index_after(close, st) or {
		return ''
	}
	return s[st..b]
}

fn clean_html(s string) string {
	mut b := strings.new_builder(s.len)
	mut in_tag := false
	for i := 0; i < s.len; i++ {
		c := s[i]
		if c == `<` {
			in_tag = true
			continue
		}
		if c == `>` && in_tag {
			in_tag = false
			continue
		}
		if !in_tag {
			b.write_byte(c)
		}
	}
	return html.unescape(b.str().trim(' \t\r\n'), html.UnescapeConfig{all: true})
}

// marked_text 从 marker 所在标签的 '>' 之后取文本，直到 close_tag。
fn marked_text(block string, marker string, close_tag string) string {
	p := block.index_after(marker, 0) or {
		return ''
	}
	gt := block.index_after('>', p) or {
		return ''
	}
	end := block.index_after(close_tag, gt) or {
		return ''
	}
	return clean_html(block[gt + 1..end])
}

fn anchor(block string, marker string) (string, string) {
	p := block.index_after(marker, 0) or {
		return '', ''
	}
	href := cut_between(block[p..], 'href="', '"', 0)
	gt := block.index_after('">', p) or {
		return href, ''
	}
	end := block.index_after('</a>', gt) or {
		return href, ''
	}
	return href, clean_html(block[gt + 2..end])
}

fn add_item(mut items []NetPkg, seen map[string]bool, p NetPkg, limit int) {
	if items.len >= limit || p.name == '' {
		return
	}
	key := '$p.manager|$p.name'
	if seen[key] {
		return
	}
	seen[key] = true
	items << p
}

fn adapter_npm_registry(c &Client, manager string, q string, limit int) ![]NetPkg {
	url := 'https://registry.npmjs.org/-/v1/search?text=${enc_query(q)}&size=$limit&from=0'
	body := c.fetch(url, 'https://www.npmjs.com/', json_accept) or {
		return error('$manager: $err')
	}
	r := json.decode(NpmResp, body) or {
		return error('$manager: 搜索结果解析失败: $err')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	for o in r.objects {
		p := o.package
		u := p.links.npm
		if u == '' {
			u = p.links.homepage
		}
		add_item(mut items, seen, NetPkg{
			manager: manager
			name: p.name
			version: p.version
			desc: p.description
			url: u
			updated: p.date
		}, limit)
	}
	return items
}

fn adapter_aur(c &Client, q string, limit int) ![]NetPkg {
	if q.len < 2 {
		return error('aur: 关键词至少 2 个字符')
	}
	url := 'https://aur.archlinux.org/rpc/v5/search/${enc_path(q)}?by=name-desc'
	body := c.fetch(url, 'https://aur.archlinux.org/', json_accept) or {
		return error('aur: $err')
	}
	r := json.decode(AurResp, body) or {
		return error('aur: 搜索结果解析失败: $err')
	}
	if r.typ == 'error' {
		return error('aur: $r.reason')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	for p in r.results {
		updated := ''
		if p.last_modified > 0 {
			updated = time.unix(p.last_modified).strftime('%Y-%m-%d')
		}
		add_item(mut items, seen, NetPkg{
			manager: 'aur'
			name: p.name
			version: p.version
			desc: p.description
			url: p.url
			updated: updated
		}, limit)
	}
	return items
}

fn adapter_conan(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://conan.io/api/search/${enc_path(q)}?topics=&licenses='
	body := c.fetch(url, 'https://conan.io/', json_accept) or {
		return error('canon: $err')
	}
	r := json.decode(map[string]ConanEntry, body) or {
		return error('canon: 搜索结果解析失败: $err')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	for i := 0; i < 500; i++ {
		e := r['$i']
		if e.name == '' {
			break
		}
		add_item(mut items, seen, NetPkg{
			manager: 'canon'
			name: e.name
			version: e.info.version
			desc: e.info.description
			url: 'https://conan.io/center/$e.name'
			updated: e.info.timestamp
		}, limit)
	}
	return items
}

fn adapter_rspm(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://crates.io/api/v1/crates?q=${enc_query(q)}&per_page=$limit&page=1'
	body := c.fetch(url, 'https://crates.io/', json_accept) or {
		return error('rspm: $err')
	}
	r := json.decode(CratesResp, body) or {
		return error('rspm: 搜索结果解析失败: $err')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	for p in r.crates {
		u := p.repository
		if u == '' {
			u = p.homepage
		}
		if u == '' {
			u = 'https://crates.io/crates/$p.name'
		}
		add_item(mut items, seen, NetPkg{
			manager: 'rspm'
			name: p.name
			version: p.max_version
			desc: p.description
			url: u
			updated: p.updated_at
		}, limit)
	}
	return items
}

fn adapter_jvpm(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://search.maven.org/solrsearch/select?q=${enc_query(q)}&rows=$limit&wt=json&start=0'
	body := c.fetch(url, 'https://search.maven.org/', json_accept) or {
		return error('jvpm: $err')
	}
	r := json.decode(MavenResp, body) or {
		return error('jvpm: 搜索结果解析失败: $err')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	for p in r.response.docs {
		updated := ''
		if p.timestamp > 0 {
			updated = time.unix(p.timestamp / 1000).strftime('%Y-%m-%d')
		}
		add_item(mut items, seen, NetPkg{
			manager: 'jvpm'
			name: p.id
			version: p.latest_version
			desc: ''
			url: 'https://central.sonatype.com/artifact/${p.g}/${p.a}'
			updated: updated
		}, limit)
	}
	return items
}

fn adapter_pypi(c &Client, q string, limit int) ![]NetPkg {
	return adapter_pypi_guru(c, q, limit) or {
		return adapter_pypi_official(c, q, limit)
	}
}

fn adapter_pypi_guru(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://pypkg.guru/search?q=${enc_query(q)}'
	body := c.fetch(url, 'https://pypkg.guru/', html_accept) or {
		return error('pypkg.guru: $err')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	mut pos := 0
	for {
		a := body.index_after('class="result-card"', pos) or {
			break
		}
		b := body.index_after('</article>', a) or {
			break
		}
		block := body[a..b]
		pos = b + '</article>'.len
		href := cut_between(block, 'href="', '"', 0)
		updated := marked_text(block, 'class="result-update contrast"', '</div>')
		updated = updated.replace('Updated:', '').trim(' \t\r\n')
		add_item(mut items, seen, NetPkg{
			manager: 'pypi'
			name: marked_text(block, 'class="result-name"', '</div>')
			version: ''
			desc: marked_text(block, 'class="result-description"', '</div>')
			url: href
			updated: updated
		}, limit)
		if pos >= body.len {
			break
		}
	}
	return items
}

fn adapter_pypi_official(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://pypi.org/search/?q=${enc_query(q)}'
	body := c.fetch(url, 'https://pypi.org/', html_accept) or {
		return error('pypi 官方搜索: $err')
	}
	if is_challenge(body) {
		return error('pypi 官方搜索页要求浏览器 JS 验证，当前环境无法通过')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	mut pos := 0
	for {
		a := body.index_after('class="package-snippet"', pos) or {
			break
		}
		b := body.index_after('</a>', a) or {
			break
		}
		block := body[a..b]
		pos = b + '</a>'.len
		href, _ := anchor(block, 'class="package-snippet"')
		mut u := href
		if u.starts_with('/') {
			u = 'https://pypi.org$u'
		}
		add_item(mut items, seen, NetPkg{
			manager: 'pypi'
			name: marked_text(block, 'class="package-snippet__name"', '</span>')
			version: marked_text(block, 'class="package-snippet__version"', '</span>')
			desc: marked_text(block, 'class="package-snippet__description"', '</span>')
			url: u
			updated: ''
		}, limit)
		if pos >= body.len {
			break
		}
	}
	return items
}

fn adapter_nix(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://www.nixhub.io/search?q=${enc_query(q)}'
	body := c.fetch(url, 'https://www.nixhub.io/', html_accept) or {
		return error('nix: $err')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	mut pos := 0
	for {
		a := body.index_after('href="/packages/', pos) or {
			break
		}
		b := body.index_after('</a>', a) or {
			break
		}
		block := body[a..b]
		pos = b + '</a>'.len
		href := cut_between(block, 'href="/packages/', '"', 0)
		add_item(mut items, seen, NetPkg{
			manager: 'nix'
			name: marked_text(block, 'class="text-xl font-bold text-ink-900"', '</h3>')
			version: ''
			desc: marked_text(block, 'class="inline text-base text-ink-700"', '</dd>')
			url: 'https://www.nixhub.io/packages/$href'
			updated: marked_text(block, 'class="whitespace-nowrap', '</span>')
		}, limit)
		if pos >= body.len {
			break
		}
	}
	return items
}

fn adapter_zig(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://zigistry.dev/?s=${enc_query(q)}'
	body := c.fetch(url, 'https://zigistry.dev/', html_accept) or {
		return error('zig: $err')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	mut pos := 0
	for pos < body.len {
		a := body.index_after('class="card z-0', pos) or {
			break
		}
		b := body.index_after('class="card z-0', a + 1) or {
			body.len
		}
		block := body[a..b]
		pos = b
		href := cut_between(block, 'href="/packages/', '"', 0)
		add_item(mut items, seen, NetPkg{
			manager: 'zig'
			name: marked_text(block, 'class="truncate text-2xl font-bold text-gray-900 dark:text-white"', '</span>')
			version: marked_text(block, 'class="px-1.5 text-xs font-medium text-slate-700 dark:text-slate-300"', '</span>')
			desc: marked_text(block, '<p class="font-normal text-gray-700 dark:text-gray-400"', '</p>')
			url: 'https://zigistry.dev/packages/$href'
			updated: marked_text(block, 'class="px-1.5 text-xs font-medium text-sky-700 dark:text-sky-300"', '</span>')
		}, limit)
	}
	return items
}

fn adapter_vpm(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://vpm.vlang.io/search?q=${enc_query(q)}'
	body := c.fetch(url, 'https://vpm.vlang.io/', html_accept) or {
		return error('vpm: $err')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	mut pos := 0
	for pos < body.len {
		a := body.index_after('<section class="package"', pos) or {
			break
		}
		b := body.index_after('<section class="package"', a + 1) or {
			body.len
		}
		block := body[a..b]
		pos = b
		href, name := anchor(block, 'class="package-card__title hover:underline cursor-pointer"')
		mut u := href
		if u.starts_with('/') {
			u = 'https://vpm.vlang.io$u'
		}
		add_item(mut items, seen, NetPkg{
			manager: 'vpm'
			name: name
			version: ''
			desc: marked_text(block, 'class="package-card__description', '</p>')
			url: u
			updated: marked_text(block, 'class="package-card__attribute package-card__last-update', '</div>')
		}, limit)
	}
	return items
}
