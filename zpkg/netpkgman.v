// netpkgman.v 是 zpkg 包的联网搜索库，仅提供公共 API，不含 main 函数。
import os
import time
import rand
import strings
import net.urllib
import vcp.curlv
import vcp.json as cjsonx
import vcp
import touse.htmpar

pub const fp_ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

pub struct NetManager {
pub:
	name     string
	disabled bool = false
}

pub const net_managers = [
	NetManager{name: 'nix', disabled: false},
	NetManager{name: 'pypi', disabled: false},
	NetManager{name: 'aur', disabled: false},
	NetManager{name: 'vpm', disabled: false},
	NetManager{name: 'canon', disabled: false},
	NetManager{name: 'zig', disabled: false},
	NetManager{name: 'rspm', disabled: false},
	NetManager{name: 'jvpm', disabled: false},
	// gopm: pkg.go.dev 官方 JSON API（/v1/search），限流 45 QPS
	NetManager{name: 'gopm', disabled: false},
	// jspm 曾作为触发点放在中间会拖住后续源；后续修好 handle 清理和硬超时后，
	// 顺序只作历史记录，不再依赖“必须最后”。
	NetManager{name: 'jspm', disabled: false},
]

const cache_ttl_ms = i64(60_000)
const min_gap_ms = i64(350)
const jitter_ms = 250
const max_retries = 2
const default_limit = 20
const max_limit = 250
const max_dom_nodes = 200_000 // DOM 遍历预算，防畸形页面拖死
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

pub struct SearchStats {
pub:
	bytes       int
	duration_ms i64
}

pub struct SearchResult {
pub:
	items []NetPkg
	stats SearchStats
}

struct CacheEntry {
	at   i64
	body string
}

struct Client {
mut:
	last    map[string]i64
	cache   map[string]CacheEntry
	timeout int = 20
	bytes   int
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

struct GopmImportedBy {
	packages i64 @[json: 'packages']
	modules  i64 @[json: 'modules']
}

struct GopmItem {
	packagePath string         @[json: 'packagePath']
	modulePath  string         @[json: 'modulePath']
	version     string         @[json: 'version']
	synopsis    string         @[json: 'synopsis']
	importedBy  GopmImportedBy @[json: 'importedByCounts']
}

struct GopmSearchResp {
	items []GopmItem @[json: 'items']
	total int        @[json: 'total']
}

pub fn manager_names() []string {
	mut out := []string{}
	for m in net_managers {
		if !m.disabled { out << m.name }
	}
	return out
}

pub fn net_manager_defs() []NetManager {
	return net_managers.clone()
}

fn net_manager_disabled(manager string) bool {
	for m in net_managers {
		if m.name == manager { return m.disabled }
	}
	return false
}

pub fn search(manager string, q string, limit int, timeout int) ![]NetPkg {
	r := search_stat(manager, q, limit, timeout) or { return err }
	return r.items
}

pub fn search_stat(manager string, q string, limit int, timeout int) !SearchResult {
	mut c := new_client(timeout)
	t0 := time.now()
	items := search_with(c, manager, q, limit) or { return err }
	return SearchResult{
		items: items
		stats: SearchStats{
			bytes: c.bytes
			duration_ms: time.since(t0).milliseconds()
		}
	}
}

pub fn netpm_search_all(sites []string, q string, limit int, timeout int) []SearchOutcome {
	c := new_client(timeout)
	mut out := []SearchOutcome{}
	chosen := if sites.len > 0 { sites } else { manager_names() }
	nq := normalize_query(q) or {
		for m in chosen {
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
	for m in chosen {
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

fn new_client(timeout int) &Client {
	return &Client{
		last: map[string]i64{}
		cache: map[string]CacheEntry{}
		timeout: timeout
	}
}

fn search_with(c &Client, manager string, raw_q string, limit int) ![]NetPkg {
	if net_manager_disabled(manager) {
		return error('源 ${manager} 已禁用')
	}
	q := normalize_query(raw_q) !
	n := clamp_limit(limit)
	match manager {
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
		'gopm' {
			return adapter_gopm(c, q, n)
		}
		'jspm' {
			return adapter_npm_registry(c, 'jspm', q, n)
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
		// 历史问题：jspm 放在中间时，它之后的源会在 curl_easy_perform 卡住。
		// 原因之一是响应 decode 阶段触发 GC，把前面未关闭的 curl handle
		// 集中放到 finalizer 里清理，时机正好落到下一个请求上。
		// 后续改为每个请求结束后立刻 closews()，不把清理交给 GC。
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
		ch.timeout(c.timeout)
		ch.lowspeed(512, 5)
		res := ch.get() or {
			// ch.closews()
			return error('请求失败: $err')
		}
		// 请求结束立即关闭句柄，不把清理交给 GC finalizer：
		// finalizer 链表用对象首字做 next 指针，与 Curl.ch 冲突，
		// 堆积后 GC_finish_collection 会遍历到自环节点并死锁。
		// ch.closews()
		if res.stcode == 200 {
			c.bytes += res.data.len
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

fn dom_doc(body string, site string) !htmpar.GumboDoc {
	return htmpar.gumbo_new_document(body) or {
		return error('$site: HTML 解析失败: $err')
	}
}

fn dom_class_has_parts(class string, wants []string) bool {
	parts := class.split(' ')
	for want in wants {
		if want == '' {
			continue
		}
		mut found := false
		for have in parts {
			if have == want {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

fn dom_walk(root htmpar.GumboNodeRef, wants []string, tag_id int, mut out []htmpar.GumboNodeRef, budget &i64) {
	if root.is_nil() || *budget <= 0 {
		return
	}
	*budget -= 1
	class_ok := wants.len == 0 || dom_class_has_parts(root.attr_view('class'), wants)
	tag_ok := tag_id < 0 || root.tag() == tag_id
	matched := class_ok && tag_ok
	if matched {
		out << root
	}
	for i := 0; i < root.child_count(); i++ {
		c := root.child_at(i)
		if c.is_nil() {
			continue
		}
		dom_walk(c, wants, tag_id, mut out, budget)
	}
}

fn dom_find_all(root htmpar.GumboNodeRef, class_marker string) []htmpar.GumboNodeRef {
	mut out := []htmpar.GumboNodeRef{}
	mut wants := []string{}
	if class_marker != '' {
		wants = class_marker.split(' ')
	}
	mut budget := i64(max_dom_nodes)
	dom_walk(root, wants, -1, mut out, &budget)
	if budget <= 0 {
		vcp.warn('dom 遍历达到 $max_dom_nodes 节点上限，已截断')
	}
	return out
}

fn dom_find_all_tag(root htmpar.GumboNodeRef, tag string) []htmpar.GumboNodeRef {
	mut out := []htmpar.GumboNodeRef{}
	mut budget := i64(max_dom_nodes)
	dom_walk(root, [], htmpar.gumbo_tag_enum(tag), mut out, &budget)
	if budget <= 0 {
		vcp.warn('dom 遍历达到 $max_dom_nodes 节点上限，已截断')
	}
	return out
}

fn dom_first(root htmpar.GumboNodeRef, class_marker string) ?htmpar.GumboNodeRef {
	nodes := dom_find_all(root, class_marker)
	if nodes.len == 0 {
		return none
	}
	return nodes[0]
}

fn dom_first_link(root htmpar.GumboNodeRef) ?htmpar.GumboNodeRef {
	nodes := dom_find_all_tag(root, 'a')
	if nodes.len == 0 {
		return none
	}
	return nodes[0]
}

fn dom_text(n htmpar.GumboNodeRef) string {
	if n.is_nil() {
		return ''
	}
	mut parts := []string{}
	t := n.text_view().trim(' \t\r\n')
	if t != '' {
		parts << t
	}
	for i := 0; i < n.child_count(); i++ {
		c := n.child_at(i)
		if c.is_nil() {
			continue
		}
		t = dom_text(c)
		if t != '' {
			parts << t
		}
	}
	return parts.join(' ').trim(' \t\r\n')
}

fn dom_text_opt(n ?htmpar.GumboNodeRef) string {
	if node := n {
		return dom_text(node)
	}
	return ''
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
	r := cjsonx.decode[NpmResp](body) or {
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

fn adapter_gopm(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://pkg.go.dev/v1/search?q=${enc_query(q)}&limit=$limit'
	body := c.fetch(url, 'https://pkg.go.dev/', json_accept) or {
		return error('gopm: $err')
	}
	r := cjsonx.decode[GopmSearchResp](body) or {
		return error('gopm: 搜索结果解析失败: $err')
	}
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	for it in r.items {
		add_item(mut items, seen, NetPkg{
			manager: 'gopm'
			name:    it.packagePath
			version: it.version
			desc:    it.synopsis
			url:     'https://pkg.go.dev/$it.packagePath'
			updated: ''
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
	r := cjsonx.decode[AurResp](body) or {
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
	r := cjsonx.decode[map[string]ConanEntry](body) or {
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
	r := cjsonx.decode[CratesResp](body) or {
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
	r := cjsonx.decode[MavenResp](body) or {
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
		eprintln('[pypi] pypkg.guru 搜索失败，回退 pypi.org: ${err.str()}')
		return adapter_pypi_official(c, q, limit)
	}
}

fn adapter_pypi_guru(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://pypkg.guru/search?q=${enc_query(q)}'
	body := c.fetch(url, 'https://pypkg.guru/', html_accept) or {
		return error('pypkg.guru: $err')
	}
	doc := dom_doc(body, 'pypi.guru') or { return err }
	defer { doc.free() }
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	root := doc.document()
	for card in dom_find_all(root, 'result-card') {
		mut href := ''
		if a := dom_first_link(card) {
			href = a.attr('href')
		}
		mut updated := ''
		if n := dom_first(card, 'result-update contrast') {
			updated = dom_text(n).replace('Updated:', '').trim(' \t\r\n')
		}
		mut name := ''
		if n := dom_first(card, 'result-name') {
			name = dom_text(n)
		}
		mut desc := ''
		if n := dom_first(card, 'result-description') {
			desc = dom_text(n)
		}
		add_item(mut items, seen, NetPkg{
			manager: 'pypi'
			name: name
			version: ''
			desc: desc
			url: href
			updated: updated
		}, limit)
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
	doc := dom_doc(body, 'pypi.org') or { return err }
	defer { doc.free() }
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	root := doc.document()
	for card in dom_find_all(root, 'package-snippet') {
		mut u := card.attr('href')
		if u.starts_with('/') {
			u = 'https://pypi.org$u'
		}
		add_item(mut items, seen, NetPkg{
			manager: 'pypi'
			name: dom_text_opt(dom_first(card, 'package-snippet__name'))
			version: dom_text_opt(dom_first(card, 'package-snippet__version'))
			desc: dom_text_opt(dom_first(card, 'package-snippet__description'))
			url: u
			updated: ''
		}, limit)
	}
	return items
}

fn adapter_nix(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://www.nixhub.io/search?q=${enc_query(q)}'
	body := c.fetch(url, 'https://www.nixhub.io/', html_accept) or {
		return error('nix: $err')
	}
	doc := dom_doc(body, 'nix') or { return err }
	defer { doc.free() }
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	root := doc.document()
	for a in dom_find_all_tag(root, 'a') {
		href := a.attr('href')
		if !href.starts_with('/packages/') {
			continue
		}
		add_item(mut items, seen, NetPkg{
			manager: 'nix'
			name: dom_text_opt(dom_first(a, 'text-xl font-bold text-ink-900'))
			version: ''
			desc: dom_text_opt(dom_first(a, 'inline text-base text-ink-700'))
			url: 'https://www.nixhub.io$href'
			updated: dom_text_opt(dom_first(a, 'whitespace-nowrap'))
		}, limit)
	}
	return items
}

fn adapter_zig(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://zigistry.dev/?s=${enc_query(q)}'
	body := c.fetch(url, 'https://zigistry.dev/', html_accept) or {
		return error('zig: $err')
	}
	doc := dom_doc(body, 'zig') or { return err }
	defer { doc.free() }
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	root := doc.document()
	for card in dom_find_all(root, 'card z-0') {
		mut href := ''
		for a in dom_find_all_tag(card, 'a') {
			h := a.attr('href')
			if h.starts_with('/packages/') {
				href = h
				break
			}
		}
		add_item(mut items, seen, NetPkg{
			manager: 'zig'
			name: dom_text_opt(dom_first(card, 'truncate text-2xl font-bold text-gray-900 dark:text-white'))
			version: dom_text_opt(dom_first(card, 'px-1.5 text-xs font-medium text-slate-700 dark:text-slate-300'))
			desc: dom_text_opt(dom_first(card, 'font-normal text-gray-700 dark:text-gray-400'))
			url: 'https://zigistry.dev$href'
			updated: dom_text_opt(dom_first(card, 'px-1.5 text-xs font-medium text-sky-700 dark:text-sky-300'))
		}, limit)
	}
	return items
}

fn adapter_vpm(c &Client, q string, limit int) ![]NetPkg {
	url := 'https://vpm.vlang.io/search?q=${enc_query(q)}'
	body := c.fetch(url, 'https://vpm.vlang.io/', html_accept) or {
		return error('vpm: $err')
	}
	doc := dom_doc(body, 'vpm') or { return err }
	defer { doc.free() }
	mut items := []NetPkg{}
	mut seen := map[string]bool{}
	root := doc.document()
	for card in dom_find_all_tag(root, 'section') {
		if !dom_class_has_parts(card.attr_view('class'), ['package']) {
			continue
		}
		title := dom_first(card, 'package-card__title hover:underline cursor-pointer') or { continue }
		mut u := title.attr('href')
		if u.starts_with('/') {
			u = 'https://vpm.vlang.io$u'
		}
		add_item(mut items, seen, NetPkg{
			manager: 'vpm'
			name: dom_text(title)
			version: ''
			desc: dom_text_opt(dom_first(card, 'package-card__description'))
			url: u
			updated: dom_text_opt(dom_first(card, 'package-card__attribute package-card__last-update'))
		}, limit)
	}
	return items
}
