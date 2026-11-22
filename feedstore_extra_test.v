module feedut

import os

fn test_opera_profile() {
	dir := os.join_path(os.temp_dir(), 'feedut_opera_${os.getpid()}')
	defer {
		os.rm(dir) or {}
	}
	os.mkdir_all(os.join_path(dir, 'Account 1'))!
	os.write_file(os.join_path(dir, 'accounts.ini'), 'FeedURL=https://a.example/feed\n')!
	os.write_file(os.join_path(dir, 'Account 1', 'account.ini'), 'FeedURL=https://b.example/rss\n')!
	assert feed_store_detect(dir) == .opera
	res := feed_store_load(dir)!
	assert res.kind == .opera
	assert res.feeds.len == 2
	assert res.feeds[0].url == 'https://a.example/feed'
	assert res.feeds[1].group_path == ['Account 1']
}

fn test_thunderbird_prefs() {
	dir := os.temp_dir()
	path := os.join_path(dir, 'feedut_prefs.js')
	defer {
		os.rm(path) or {}
	}
	os.write_file(path, 'user_pref("mail.server.server1.type", "rss");\nuser_pref("mail.server.server1.hostname", "https://example.com/feed");\n')!
	assert feed_store_detect(path) == .thunderbird
	res := feed_store_load(path)!
	assert res.kind == .thunderbird
	assert res.feeds.len >= 1
}

fn test_akregator_opml() {
	dir := os.temp_dir()
	path := os.join_path(dir, 'akregator_export.opml')
	defer {
		os.rm(path) or {}
	}
	os.write_file(path, '<opml version="1.0"><body><outline text="Feed A" xmlUrl="https://a.example/feed"/></body></opml>')!
	assert feed_store_detect(path) == .akregator
	res := feed_store_load(path)!
	assert res.kind == .akregator
	assert res.feeds.len == 1
	assert res.feeds[0].title == 'Feed A'
}
