module feedut

import encoding.base64
import os

// feed_store_load_claws reads a Claws Mail RSSyl directory. The OPML file
// provides feed URLs; physical subdirectories provide message files and group
// paths. Each message is an RFC 822 style file with X-RSSyl-URL headers.
pub fn feed_store_load_claws(path string) !StoreResult {
	opml_path := os.join_path(path, 'rssyl-feedlist.opml')
	body := os.read_file(opml_path)!
	opml := feed_store_parse_opml(body, opml_path)!
	mut feeds := opml.feeds.clone()
	for i in 0 .. feeds.len {
		feeds[i].source = path
		feeds[i].group_path = []string{}
		feeds[i].group_raw = ''
	}

	feed_store_claws_walk(path, path, mut feeds)
	return StoreResult{
		kind:  .claws
		root:  path
		feeds: feeds
	}
}

// feed_store_claws_walk recurses through the RSSyl directory tree. A directory
// whose name matches an OPML feed title holds that feed's message files; its
// parent directories form the physical group_path.
fn feed_store_claws_walk(root string, dir string, mut feeds []StoreFeed) {
	entries := os.ls(dir) or { return }
	for entry in entries {
		if entry.starts_with('.') {
			continue
		}
		full := os.join_path(dir, entry)
		if !os.is_dir(full) {
			continue
		}
		if feed_store_claws_match(feeds, entry) >= 0 {
			idx := feed_store_claws_match(feeds, entry)
			mut feed := feeds[idx]
			rel := feed_store_claws_relative(root, dir)
			feed.group_path = feed_store_normalize_group(rel)
			feed.group_raw = rel
			feed.items = feed_store_claws_messages(full)
			feeds[idx] = feed
			continue
		}
		feed_store_claws_walk(root, full, mut feeds)
	}
}

fn feed_store_claws_relative(root string, dir string) string {
	if dir == root || !dir.starts_with(root) {
		return ''
	}
	rel := dir[root.len..]
	for rel.starts_with('/') {
		rel = rel[1..]
	}
	return rel
}

fn feed_store_claws_match(feeds []StoreFeed, dirname string) int {
	for i, feed in feeds {
		if feed.title == dirname {
			return i
		}
	}
	for i, feed in feeds {
		if feed_store_title_from_url(feed.url) == dirname {
			return i
		}
	}
	return -1
}

fn feed_store_claws_messages(dir string) []StoredItem {
	mut out := []StoredItem{}
	files := os.ls(dir) or { return out }
	for name in files {
		if name.starts_with('.') {
			continue
		}
		full := os.join_path(dir, name)
		if !os.is_file(full) || !feed_store_is_digits(name) {
			continue
		}
		body := os.read_file(full) or { continue }
		out << feed_store_claws_message(body)
	}
	return out
}

fn feed_store_claws_message(body string) StoredItem {
	header_end := body.index('\n\n') or { body.len }
	header := body[..header_end]
	content := if header_end < body.len { body[header_end + 2..] } else { '' }
	mut it := StoredItem{
		description: content.trim_space()
	}
	mut lines := header.split_into_lines()
	mut i := 0
	for i < lines.len {
		line := lines[i].trim_space()
		i++
		if line == '' {
			continue
		}
		colon := line.index(':') or { continue }
		key := line[..colon].to_lower().trim_space()
		mut val := line[colon + 1..].trim_space()
		// RFC 822 continuation lines.
		for i < lines.len && (lines[i].starts_with(' ') || lines[i].starts_with('\t')) {
			val += lines[i].trim_space()
			i++
		}
		match key {
			'subject' {
				it.title = feed_store_decode_rfc2047(val)
			}
			'from' {
				it.author = feed_store_decode_rfc2047(val)
			}
			'date' {
				it.pub_date = val
			}
			'x-rssyl-url' {
				it.link = val
			}
			'message-id' {
				g := val.trim('<').trim('>')
				it.guid = g
			}
			else {}
		}
	}
	if it.guid == '' {
		it.guid = it.link
	}
	return it
}

// feed_store_decode_rfc2047 decodes =?charset?B/Q?...?= encoded words.
pub fn feed_store_decode_rfc2047(s string) string {
	if !s.contains('=?') {
		return s
	}
	mut out := ''
	mut i := 0
	mut prev_encoded := false
	for i < s.len {
		if !s[i..].starts_with('=?') {
			if s[i] == ` ` && prev_encoded {
				// whitespace between encoded words is discarded
				i++
				prev_encoded = false
				continue
			}
			out += s[i..i + 1]
			prev_encoded = false
			i++
			continue
		}
		q1 := s.index_after('?', i + 2) or {
			out += s[i..]
			break
		}
		if q1 + 1 >= s.len {
			out += s[i..]
			break
		}
		encoding_kind := s[q1 + 1].ascii_str().to_upper()
		q2 := s.index_after('?', q1 + 2) or {
			out += s[i..]
			break
		}
		end := s.index_after('?=', q2 + 1) or {
			out += s[i..]
			break
		}
		payload := s[q2 + 1..end]
		decoded := if encoding_kind == 'B' {
			base64.decode_str(payload)
		} else if encoding_kind == 'Q' {
			feed_store_decode_q(payload)
		} else {
			payload
		}
		out += decoded
		prev_encoded = true
		i = end + 2
	}
	return out
}

fn feed_store_decode_q(s string) string {
	mut out := ''
	mut i := 0
	for i < s.len {
		c := s[i]
		if c == `_` {
			out += ' '
			i++
			continue
		}
		if c == `=` && i + 2 < s.len {
			hex := s[i + 1..i + 3]
			if hex.len == 2 {
				code := feed_store_hex_byte(hex)
				if code >= 0 {
					out += u8(code).ascii_str()
					i += 3
					continue
				}
			}
		}
		out += s[i..i + 1]
		i++
	}
	return out
}

fn feed_store_hex_byte(s string) int {
	if s.len != 2 {
		return -1
	}
	hi := feed_store_hex_nibble(s[0])
	lo := feed_store_hex_nibble(s[1])
	if hi < 0 || lo < 0 {
		return -1
	}
	return hi * 16 + lo
}

fn feed_store_hex_nibble(c u8) int {
	if c >= `0` && c <= `9` {
		return int(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return int(c - `a`) + 10
	}
	if c >= `A` && c <= `F` {
		return int(c - `A`) + 10
	}
	return -1
}

// feed_store_load_newsboat reads a newsboat urls file. Each line is a URL
// followed by optional whitespace separated tags.
pub fn feed_store_load_newsboat(path string) !StoreResult {
	body := os.read_file(path)!
	mut feeds := []StoreFeed{}
	for line in body.split_into_lines() {
		t := line.trim_space()
		if t == '' || t.starts_with('#') {
			continue
		}
		fields := t.split(' ')
		url := feed_store_normalize_url(fields[0])
		if !url.starts_with('http://') && !url.starts_with('https://') {
			continue
		}
		mut feed := StoreFeed{
			title:  feed_store_title_from_url(url)
			url:    url
			source: path
		}
		if fields.len > 1 {
			for tag in fields[1..] {
				tt := tag.trim_space()
				if tt != '' && tt !in feed.tags {
					feed.tags << tt
				}
			}
		}
		feeds << feed
	}
	return StoreResult{
		kind:  .newsboat
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

// feed_store_load_opera reads an Opera Mail profile directory. Feed URLs are
// stored in accounts.ini and accountN/account.ini files as http(s) values.
// Physical account subdirectories provide the group_path.
pub fn feed_store_load_opera(path string) !StoreResult {
	mut feeds := []StoreFeed{}
	mut ini_paths := []string{}
	ini_paths << os.join_path(path, 'accounts.ini')
	entries := os.ls(path) or {
		return StoreResult{
			kind:  .opera
			root:  path
			feeds: feeds
		}
	}
	for entry in entries {
		sub := os.join_path(path, entry)
		if !os.is_dir(sub) || entry.starts_with('.') {
			continue
		}
		account_ini := os.join_path(sub, 'account.ini')
		if os.is_file(account_ini) {
			ini_paths << account_ini
		}
	}
	for ini_path in ini_paths {
		if !os.is_file(ini_path) {
			continue
		}
		body := os.read_file(ini_path) or { continue }
		group := if ini_path == os.join_path(path, 'accounts.ini') {
			''
		} else {
			feed_store_basename(os.dir(ini_path))
		}
		for line in body.split_into_lines() {
			url := feed_store_first_url(line)
			if url == '' || (!url.starts_with('http://') && !url.starts_with('https://')) {
				continue
			}
			mut feed := StoreFeed{
				title:      feed_store_title_from_url(url)
				url:        url
				source:     ini_path
				group_path: feed_store_normalize_group(group)
				group_raw:  group
			}
			if key := line.index('=') {
				name := line[..key].trim_space()
				if name != '' && name.to_lower() != 'url' {
					feed.title = name
				}
			}
			feeds << feed
		}
	}
	return StoreResult{
		kind:  .opera
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

// feed_store_load_elfeed reads an org-mode file with elfeed :feed-url: props.
pub fn feed_store_load_elfeed(path string) !StoreResult {
	body := os.read_file(path)!
	mut feeds := []StoreFeed{}
	mut title := ''
	for line in body.split_into_lines() {
		t := line.trim_space()
		if t.starts_with('*') {
			title = t.trim('*').trim_space()
			continue
		}
		if t.starts_with(':feed-url:') {
			url := feed_store_normalize_url(t[':feed-url:'.len..].trim_space())
			if url == '' {
				continue
			}
			mut feed := StoreFeed{
				title:  title
				url:    url
				source: path
			}
			if feed.title == '' {
				feed.title = feed_store_title_from_url(url)
			}
			feeds << feed
		}
	}
	return StoreResult{
		kind:  .elfeed
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}
