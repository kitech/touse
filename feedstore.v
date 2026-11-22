module feedut

import db.sqlite
import os
import time

// StoreKind identifies the on-disk feed store format or reader application.
pub enum StoreKind {
	unknown
	rss
	opml
	sfeed
	sqlite
	claws
	liferea
	newsboat
	rssguard
	quiterss
	firefox
	thunderbird
	netnewswire
	vienna
	feedme
	opera
	elfeed
	akregator
}

// StoredItem is one entry read from a reader store.
pub struct StoredItem {
pub mut:
	title       string
	link        string
	guid        string
	description string
	author      string
	pub_date    string
	category    []string
	read        bool
	starred     bool
}

// StoreFeed is one subscription read from a reader store.
// group_path is the physical folder hierarchy; tags are feed attributes.
pub struct StoreFeed {
pub mut:
	title      string
	url        string
	group_path []string
	group_raw  string
	tags       []string
	source     string
	items      []StoredItem
}

// StoreGroup is a physical folder node built from StoreFeed.group_path.
pub struct StoreGroup {
pub mut:
	name      string
	path      []string
	feed_urls []string
	children  []StoreGroup
}

// StoreResult is the normalized result of reading one store file.
pub struct StoreResult {
pub mut:
	kind  StoreKind
	root  string
	feeds []StoreFeed
}

struct StoreTag {
mut:
	closing      bool
	self_closing bool
	name         string
	attrs        map[string]string
}

const store_sqlite_magic = 'SQLite format 3'

// feed_store_detect returns the store format of a file or directory.
pub fn feed_store_detect(path string) StoreKind {
	if os.is_dir(path) {
		return feed_store_detect_dir(path)
	}
	if !os.is_file(path) {
		return .unknown
	}
	basename := feed_store_basename(path).to_lower()
	if basename.contains('akregator') && basename.ends_with('.opml') {
		return .akregator
	}
	if basename.ends_with('prefs.js') {
		head_text := feed_store_read_head(path, 65536)
		if head_text.contains('mail.server') && head_text.contains('rss') {
			return .thunderbird
		}
	}
	head := feed_store_read_head(path, 4096)
	if head.starts_with(store_sqlite_magic) {
		return feed_store_detect_sqlite(path)
	}
	kind := feed_store_detect_text(head)
	if kind != .unknown {
		return kind
	}
	if head.len > 0 && head.len < 4096 {
		return .unknown
	}
	full := os.read_file(path) or { return .unknown }
	return feed_store_detect_text(full)
}

fn feed_store_detect_dir(path string) StoreKind {
	if os.is_file(os.join_path(path, 'rssyl-feedlist.opml')) {
		return .claws
	}
	if os.is_file(os.join_path(path, 'accounts.ini')) {
		return .opera
	}
	if os.is_file(os.join_path(path, 'akregatorrc')) {
		return .akregator
	}
	names := ['subscriptions.opml', 'feedlist.opml', 'feeds.opml', 'export.opml']
	for name in names {
		if os.is_file(os.join_path(path, name)) {
			return .opml
		}
	}
	entries := os.ls(path) or { return .unknown }
	for entry in entries {
		if entry.to_lower().ends_with('.opml') {
			return .opml
		}
	}
	return .unknown
}

// feed_store_detect_sqlite opens a copy of the database and identifies the
// reader application from its table names.
fn feed_store_detect_sqlite(path string) StoreKind {
	tables := feed_store_sqlite_table_set(path) or { return .sqlite }
	if 'node' in tables && 'subscription' in tables && 'items' in tables {
		return .liferea
	}
	if 'moz_bookmarks' in tables && 'moz_places' in tables {
		return .firefox
	}
	if 'zentry' in tables || 'zfeed' in tables {
		return .netnewswire
	}
	if 'zarticle' in tables {
		return .vienna
	}
	if 'feed' in tables && 'article' in tables {
		return .vienna
	}
	if 'feeds' in tables && 'news' in tables {
		return .quiterss
	}
	if 'feed' in tables && 'entry' in tables {
		return .rssguard
	}
	if 'feed' in tables && 'item' in tables {
		return .feedme
	}
	return .sqlite
}

// feed_store_sqlite_table_set returns the lowercased table names of a database.
// The file is copied first so a live, locked reader database can be inspected.
pub fn feed_store_sqlite_table_set(path string) ![]string {
	tmp := feed_store_sqlite_copy(path)!
	defer {
		os.rm(tmp) or {}
	}
	mut db := sqlite.connect(tmp)!
	rows := db.exec("select name from sqlite_master where type='table'")!
	mut out := []string{}
	for row in rows {
		if row.vals.len > 0 {
			out << row.vals[0].to_lower()
		}
	}
	return out
}

// feed_store_sqlite_copy copies a database to a private temp file so readers
// never modify or lock the original store.
pub fn feed_store_sqlite_copy(path string) !string {
	name := 'feedut_${os.getpid()}_${time.now().unix_nano()}.sqlite'
	tmp := os.join_path(os.temp_dir(), name)
	os.cp(path, tmp)!
	return tmp
}

fn feed_store_detect_text(text string) StoreKind {
	body := feed_store_strip_prefix(text)
	if body.starts_with('<') {
		match feed_store_root_name(body).to_lower() {
			'opml' { return .opml }
			'rss', 'feed', 'rdf:rdf', 'rdf' { return .rss }
			else {}
		}
	}
	if feed_store_looks_like_sfeed(text) {
		return .sfeed
	}
	if feed_store_looks_like_newsboat(text) {
		return .newsboat
	}
	if feed_store_looks_like_elfeed(text) {
		return .elfeed
	}
	return .unknown
}

fn feed_store_looks_like_newsboat(text string) bool {
	mut lines := 0
	mut ok := 0
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t == '' || t.starts_with('#') {
			continue
		}
		lines++
		first := t.split(' ')[0]
		if first.starts_with('http://') || first.starts_with('https://') {
			ok++
		}
		if lines >= 5 {
			break
		}
	}
	return lines > 0 && ok * 2 >= lines
}

fn feed_store_looks_like_elfeed(text string) bool {
	return text.contains(':feed-url:') && text.contains(':PROPERTIES:')
}

fn feed_store_read_head(path string, n int) string {
	mut f := os.open(path) or { return '' }
	defer {
		f.close()
	}
	return f.read_bytes(n).bytestr()
}

fn feed_store_strip_prefix(s string) string {
	mut t := s.trim_space()
	if t.starts_with('\xEF\xBB\xBF') {
		t = t[3..].trim_space()
	}
	for {
		if t.starts_with('<?xml') {
			idx := t.index('?>') or { return '' }
			t = t[idx + 2..].trim_space()
			continue
		}
		if t.starts_with('<!--') {
			idx := t.index('-->') or { return '' }
			t = t[idx + 3..].trim_space()
			continue
		}
		if t.starts_with('<!DOCTYPE') {
			idx := t.index('>') or { return '' }
			t = t[idx + 1..].trim_space()
			continue
		}
		break
	}
	return t
}

fn feed_store_root_name(s string) string {
	if !s.starts_with('<') {
		return ''
	}
	mut i := 1
	for i < s.len && !feed_store_is_name_end(s[i]) {
		i++
	}
	return s[1..i]
}

fn feed_store_looks_like_sfeed(s string) bool {
	mut lines := 0
	mut ok := 0
	for line in s.split_into_lines() {
		if line.trim_space() == '' {
			continue
		}
		lines++
		fields := line.split('\t')
		if fields.len >= 4 && feed_store_is_digits(fields[0])
			&& (fields[2].starts_with('http://') || fields[2].starts_with('https://')) {
			ok++
		}
		if lines >= 5 {
			break
		}
	}
	return lines > 0 && ok * 2 >= lines
}

fn feed_store_is_digits(s string) bool {
	t := s.trim_space()
	if t == '' {
		return false
	}
	for c in t {
		if c < `0` || c > `9` {
			return false
		}
	}
	return true
}

// feed_store_load reads a store file and returns its normalized feeds.
// base is optional; it is used to derive physical group paths for directory
// based stores such as sfeed.
pub fn feed_store_load(path string, base ...string) !StoreResult {
	kind := feed_store_detect(path)
	if kind == .unknown {
		return error('unsupported feed store: ${path}')
	}
	base_dir := if base.len > 0 { base[0] } else { '' }
	match kind {
		.claws {
			return feed_store_load_claws(path)
		}
		.opml {
			body := os.read_file(path)!
			return feed_store_parse_opml(body, path)
		}
		.rss {
			body := os.read_file(path)!
			return feed_store_parse_rss(body, path)
		}
		.sfeed {
			body := os.read_file(path)!
			return feed_store_parse_sfeed(body, path, base_dir)
		}
		.liferea {
			return feed_store_load_liferea(path)
		}
		.firefox {
			return feed_store_load_firefox(path)
		}
		.thunderbird {
			return feed_store_load_thunderbird(path)
		}
		.netnewswire {
			return feed_store_load_netnewswire(path)
		}
		.vienna {
			return feed_store_load_vienna(path)
		}
		.rssguard {
			return feed_store_load_rssguard(path)
		}
		.quiterss {
			return feed_store_load_quiterss(path)
		}
		.feedme {
			return feed_store_load_feedme(path)
		}
		.newsboat {
			return feed_store_load_newsboat(path)
		}
		.elfeed {
			return feed_store_load_elfeed(path)
		}
		.opera {
			return feed_store_load_opera(path)
		}
		.akregator {
			body := os.read_file(path)!
			res := feed_store_parse_opml(body, path)!
			res.kind = .akregator
			return res
		}
		.sqlite {
			return error('unrecognized sqlite feed store: ${path}')
		}
		else {
			return error('unsupported feed store: ${path}')
		}
	}
}

// feed_store_parse_rss wraps parse_feed for a single RSS/Atom/RDF file.
pub fn feed_store_parse_rss(body string, root string) !StoreResult {
	pf := parse_feed(body)!
	mut feed := StoreFeed{
		title:  pf.title
		source: root
	}
	for it in pf.items {
		feed.items << StoredItem{
			title:       it.title
			link:        it.link
			guid:        it.guid
			description: it.description
			author:      it.author
			pub_date:    it.pub_date
			category:    it.category.clone()
		}
	}
	return StoreResult{
		kind:  .rss
		root:  root
		feeds: [feed]
	}
}

// feed_store_parse_opml parses OPML recursively. Outline nesting becomes
// StoreFeed.group_path; category attributes become StoreFeed.tags.
pub fn feed_store_parse_opml(body string, root string) !StoreResult {
	tags := feed_store_scan_tags(body)
	mut feeds := []StoreFeed{}
	mut stack := []string{}
	mut saw_outline := false
	for tag in tags {
		if tag.name != 'outline' {
			continue
		}
		saw_outline = true
		if tag.closing {
			if stack.len > 0 {
				stack.delete_last()
			}
			continue
		}
		text := feed_store_tag_text(tag.attrs)
		url := feed_store_tag_url(tag.attrs)
		if url != '' {
			path := feed_store_stack_path(stack)
			mut feed := StoreFeed{
				title:      text
				url:        url
				group_path: path
				group_raw:  path.join('/')
				source:     root
			}
			if feed.title == '' {
				feed.title = feed_store_title_from_url(url)
			}
			if cats := tag.attrs['category'] {
				for part in cats.split(',') {
					c := part.trim_space()
					if c != '' && c !in feed.tags {
						feed.tags << c
					}
				}
			}
			feeds << feed
			if !tag.self_closing {
				stack << ''
			}
			continue
		}
		if !tag.self_closing {
			stack << text
		}
	}
	if !saw_outline && !body.contains('<opml') {
		return error('opml: no outline elements in ${root}')
	}
	return StoreResult{
		kind:  .opml
		root:  root
		feeds: feed_store_dedupe(feeds)
	}
}

fn feed_store_stack_path(stack []string) []string {
	mut out := []string{}
	for s in stack {
		if s != '' {
			out << s
		}
	}
	return out
}

// feed_store_parse_sfeed parses one sfeed TSV file.
// Fields: timestamp, title, link, content, id, author, enclosure, type, category.
pub fn feed_store_parse_sfeed(body string, root string, base ...string) !StoreResult {
	mut items := []StoredItem{}
	for line in body.split_into_lines() {
		if line.trim_space() == '' {
			continue
		}
		fields := line.split('\t')
		if fields.len < 4 {
			continue
		}
		mut it := StoredItem{
			pub_date:    fields[0].trim_space()
			title:       fields[1]
			link:        fields[2]
			description: fields[3]
		}
		if fields.len > 4 {
			it.guid = fields[4]
		}
		if fields.len > 5 {
			it.author = fields[5]
		}
		if fields.len > 8 {
			for part in fields[8].split(',') {
				c := part.trim_space()
				if c != '' {
					it.category << c
				}
			}
		}
		items << it
	}
	if items.len == 0 {
		return error('sfeed: no items in ${root}')
	}
	group_base := if base.len > 0 { base[0] } else { '' }
	group_path := feed_store_relative_groups(root, group_base)
	return StoreResult{
		kind:  .sfeed
		root:  root
		feeds: [
			StoreFeed{
				title:      feed_store_basename(root)
				group_path: group_path
				group_raw:  group_path.join('/')
				source:     root
				items:      items
			},
		]
	}
}

// feed_store_scan_tags is a small tag scanner. It is used instead of xmlc for
// OPML because xmlc truncates attribute values at the first space and does not
// decode entity references, which breaks real world text="..." attributes.
fn feed_store_scan_tags(body string) []StoreTag {
	mut tags := []StoreTag{}
	mut i := 0
	for i < body.len {
		if body[i] != `<` {
			i++
			continue
		}
		if body[i..].starts_with('<!--') {
			i = body.index_after('-->', i + 4) or { break }
			continue
		}
		if body[i..].starts_with('<![CDATA[') {
			i = body.index_after(']]>', i + 9) or { break }
			continue
		}
		if body[i..].starts_with('<?') || body[i..].starts_with('<!') {
			i = body.index_after('>', i + 2) or { break }
			continue
		}
		end := feed_store_tag_end(body, i) or { break }
		tags << feed_store_parse_tag(body[i + 1..end])
		i = end + 1
	}
	return tags
}

fn feed_store_tag_end(s string, start int) ?int {
	mut quote := u8(0)
	mut i := start + 1
	for i < s.len {
		c := s[i]
		if quote != 0 {
			if c == quote {
				quote = 0
			}
		} else if c == `"` || c == `'` {
			quote = c
		} else if c == `>` {
			return i
		}
		i++
	}
	return none
}

fn feed_store_parse_tag(raw string) StoreTag {
	mut t := raw.trim_space()
	mut tag := StoreTag{
		attrs: map[string]string{}
	}
	if t.starts_with('/') {
		tag.closing = true
		t = t[1..].trim_space()
	}
	if t.ends_with('/') {
		tag.self_closing = true
		t = t[..t.len - 1].trim_space()
	}
	mut name_end := 0
	for name_end < t.len && !feed_store_is_name_end(t[name_end]) {
		name_end++
	}
	tag.name = t[..name_end].to_lower()
	tag.attrs = feed_store_parse_attrs(t[name_end..])
	return tag
}

fn feed_store_parse_attrs(s string) map[string]string {
	mut attrs := map[string]string{}
	mut i := 0
	for i < s.len {
		for i < s.len && feed_store_is_space(s[i]) {
			i++
		}
		if i >= s.len {
			break
		}
		name_start := i
		for i < s.len && s[i] != `=` && !feed_store_is_space(s[i]) {
			i++
		}
		if i >= s.len {
			break
		}
		name := s[name_start..i].to_lower()
		for i < s.len && feed_store_is_space(s[i]) {
			i++
		}
		if i >= s.len || s[i] != `=` {
			i++
			continue
		}
		i++
		for i < s.len && feed_store_is_space(s[i]) {
			i++
		}
		mut value := ''
		if i < s.len && (s[i] == `"` || s[i] == `'`) {
			quote := s[i]
			i++
			value_start := i
			for i < s.len && s[i] != quote {
				i++
			}
			value = s[value_start..i]
			if i < s.len {
				i++
			}
		} else {
			value_start := i
			for i < s.len && !feed_store_is_space(s[i]) {
				i++
			}
			value = s[value_start..i]
		}
		if name != '' {
			attrs[name] = unescape_xml_text(value)
		}
	}
	return attrs
}

fn feed_store_tag_text(attrs map[string]string) string {
	for key in ['text', 'title', 'name'] {
		if v := attrs[key] {
			t := v.trim_space()
			if t != '' {
				return t
			}
		}
	}
	return ''
}

fn feed_store_tag_url(attrs map[string]string) string {
	for key in ['xmlurl', 'feedurl', 'url'] {
		if v := attrs[key] {
			u := feed_store_normalize_url(v)
			if u != '' {
				return u
			}
		}
	}
	return ''
}

// feed_store_normalize_url trims a URL and converts feed: schemes to http(s).
pub fn feed_store_normalize_url(u string) string {
	mut s := u.trim_space()
	if s.starts_with('feed:http://') || s.starts_with('feed:https://') {
		s = s[5..]
	} else if s.starts_with('feed://') {
		s = 'http://' + s[7..]
	}
	return s
}

// feed_store_dedupe keeps the first feed for each URL and merges tags/items.
pub fn feed_store_dedupe(feeds []StoreFeed) []StoreFeed {
	mut out := []StoreFeed{}
	mut at := map[string]int{}
	for feed in feeds {
		key := feed.url.trim_space()
		if key == '' {
			out << feed
			continue
		}
		if key in at {
			idx := at[key]
			if out[idx].title == '' {
				out[idx].title = feed.title
			}
			if out[idx].group_path.len == 0 && feed.group_path.len > 0 {
				out[idx].group_path = feed.group_path.clone()
				out[idx].group_raw = feed.group_raw
			}
			mut merged_tags := out[idx].tags.clone()
			for t in feed.tags {
				if t !in merged_tags {
					merged_tags << t
				}
			}
			out[idx].tags = merged_tags
			out[idx].items = feed_store_merge_items(out[idx].items, feed.items)
			continue
		}
		at[key] = out.len
		out << feed
	}
	return out
}

// feed_store_merge_items appends src items, skipping keys already in dst.
pub fn feed_store_merge_items(dst []StoredItem, src []StoredItem) []StoredItem {
	mut out := dst.clone()
	mut seen := map[string]bool{}
	for it in out {
		k := feed_store_item_key(it)
		if k != '' {
			seen[k] = true
		}
	}
	for it in src {
		k := feed_store_item_key(it)
		if k != '' && k in seen {
			continue
		}
		if k != '' {
			seen[k] = true
		}
		out << it
	}
	return out
}

// feed_store_item_key returns guid when present, otherwise link.
pub fn feed_store_item_key(it StoredItem) string {
	g := it.guid.trim_space()
	if g != '' {
		return g
	}
	return it.link.trim_space()
}

// feed_store_groups builds a physical folder tree from feed group paths.
pub fn feed_store_groups(feeds []StoreFeed) []StoreGroup {
	mut roots := []StoreGroup{}
	for feed in feeds {
		if feed.group_path.len == 0 {
			continue
		}
		feed_store_group_insert(mut roots, feed.group_path, 0, feed.url)
	}
	return roots
}

fn feed_store_group_insert(mut groups []StoreGroup, full []string, depth int, url string) {
	name := full[depth]
	mut at := -1
	for i in 0 .. groups.len {
		if groups[i].name == name {
			at = i
			break
		}
	}
	next := depth + 1
	if at < 0 {
		groups << StoreGroup{
			name: name
			path: full[0..next].clone()
		}
		at = groups.len - 1
	}
	if next >= full.len {
		if url != '' {
			mut urls := groups[at].feed_urls.clone()
			urls << url
			groups[at].feed_urls = urls
		}
		return
	}
	mut children := groups[at].children.clone()
	feed_store_group_insert(mut children, full, next, url)
	groups[at].children = children
}

// feed_store_normalize_group splits a physical folder string into components.
pub fn feed_store_normalize_group(raw string) []string {
	mut out := []string{}
	for part in raw.replace('\\', '/').split('/') {
		p := part.trim_space()
		if p == '' || p == '.' {
			continue
		}
		out << p
	}
	return out
}

// feed_store_relative_groups returns parent folders of path relative to base.
pub fn feed_store_relative_groups(path string, base string) []string {
	full := feed_store_path_parts(path)
	if base == '' || full.len == 0 {
		return []string{}
	}
	b := feed_store_path_parts(base)
	if b.len > full.len {
		return []string{}
	}
	for i in 0 .. b.len {
		if full[i] != b[i] {
			return []string{}
		}
	}
	rel := full[b.len..]
	if rel.len <= 1 {
		return []string{}
	}
	return rel[0..rel.len - 1].clone()
}

fn feed_store_path_parts(path string) []string {
	mut s := path.replace('\\', '/')
	if s.starts_with('/') {
		s = s[1..]
	}
	mut out := []string{}
	for part in s.split('/') {
		if part != '' && part != '.' {
			out << part
		}
	}
	return out
}

fn feed_store_basename(path string) string {
	s := path.replace('\\', '/')
	idx := s.last_index('/') or { return s }
	if idx + 1 >= s.len {
		return s
	}
	return s[idx + 1..]
}

// feed_store_title_from_url derives a display title from a feed URL.
pub fn feed_store_title_from_url(url string) string {
	mut s := url.trim_space()
	for prefix in ['https://', 'http://', 'feed://'] {
		if s.starts_with(prefix) {
			s = s[prefix.len..]
			break
		}
	}
	for sep in ['?', '#'] {
		if idx := s.index(sep) {
			s = s[..idx]
		}
	}
	for s.ends_with('/') {
		s = s[..s.len - 1]
	}
	if s == '' {
		return ''
	}
	parts := s.split('/')
	return parts[parts.len - 1]
}

fn feed_store_is_space(c u8) bool {
	return c == ` ` || c == `\t` || c == `\n` || c == `\r`
}

fn feed_store_is_name_end(c u8) bool {
	return feed_store_is_space(c) || c == `>` || c == `/`
}
