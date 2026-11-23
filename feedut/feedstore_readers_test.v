module feedut

import os

fn test_decode_rfc2047_base64() {
	assert feed_store_decode_rfc2047('=?UTF-8?B?5L2g5aW9?=') == '你好'
	assert feed_store_decode_rfc2047('=?UTF-8?Q?caf=C3=A9?=') == 'café'
	assert feed_store_decode_rfc2047('=?UTF-8?B?YQ==?= =?UTF-8?B?Yg==?=') == 'ab'
	assert feed_store_decode_rfc2047('plain text') == 'plain text'
}

fn test_newsboat_urls() {
	dir := os.temp_dir()
	path := os.join_path(dir, 'feedut_urls_test')
	defer {
		os.rm(path) or {}
	}
	os.write_file(path, '# comment\nhttps://a.example/feed tech news\nhttps://b.example/rss\n')!
	assert feed_store_detect(path) == .newsboat
	res := feed_store_load(path)!
	assert res.kind == .newsboat
	assert res.feeds.len == 2
	assert res.feeds[0].tags == ['tech', 'news']
	assert res.feeds[0].title == 'feed'
}

fn test_elfeed_org() {
	dir := os.temp_dir()
	path := os.join_path(dir, 'feedut_elfeed_test.org')
	defer {
		os.rm(path) or {}
	}
	os.write_file(path, '* Feed A\n:PROPERTIES:\n:feed-url: https://a.example/feed\n:END:\n')!
	assert feed_store_detect(path) == .elfeed
	res := feed_store_load(path)!
	assert res.kind == .elfeed
	assert res.feeds.len == 1
	assert res.feeds[0].title == 'Feed A'
	assert res.feeds[0].url == 'https://a.example/feed'
}

fn test_liferea_sqlite_schema_detect() {
	dir := os.temp_dir()
	path := os.join_path(dir, 'feedut_liferea_test.db')
	defer {
		os.rm(path) or {}
	}
	sample := '/home/gzleo/.local/share/liferea/liferea.db'
	if !os.is_file(sample) {
		return
	}
	os.cp(sample, path)!
	assert feed_store_detect(path) == .liferea
}

fn test_real_claws() {
	path := '/home/gzleo/.claws-mail/RSSyl'
	if !os.is_dir(path) {
		return
	}
	assert feed_store_detect(path) == .claws
	res := feed_store_load(path)!
	assert res.kind == .claws
	assert res.feeds.len >= 12
	mut found := false
	for f in res.feeds {
		if f.url.contains('meta.appinn.net') {
			found = true
			assert f.group_path == ['My Feeds (RSSyl)']
			if f.items.len > 0 {
				assert f.items[0].title != ''
				assert f.items[0].link.starts_with('http')
			}
		}
	}
	assert found
}

fn test_real_liferea() {
	path := '/home/gzleo/.local/share/liferea/liferea.db'
	if !os.is_file(path) {
		return
	}
	assert feed_store_detect(path) == .liferea
	res := feed_store_load(path)!
	assert res.kind == .liferea
	assert res.feeds.len >= 50
	mut items := 0
	mut grouped := 0
	for f in res.feeds {
		items += f.items.len
		if f.group_path.len > 0 {
			grouped++
		}
	}
	assert items > 100
	assert grouped >= 50
}
