module feedut

import db.sqlite
import os

fn feedut_sql_fixture(name string, stmts []string) string {
	path := os.join_path(os.temp_dir(), 'feedut_sql_${name}_${os.getpid()}.db')
	os.rm(path) or {}
	mut db := sqlite.connect(path) or { panic('fixture connect: ${err}') }
	for stmt in stmts {
		db.exec(stmt) or { panic('fixture ${name}: ${err} - ${stmt}') }
	}
	db.close() or {}
	return path
}

fn test_sql_reader_rssguard() {
	path := feedut_sql_fixture('rssguard', [
		'create table feed (id integer primary key, url text, title text, category text)',
		'create table entry (id integer primary key, feed_id integer, title text)',
		"insert into feed values (1, 'https://a.example/feed', 'Feed A', 'tech, news')",
	])
	defer {
		os.rm(path) or {}
	}
	assert feed_store_detect(path) == .rssguard
	res := feed_store_load(path)!
	assert res.kind == .rssguard
	assert res.feeds.len == 1
	assert res.feeds[0].title == 'Feed A'
	assert res.feeds[0].tags == ['tech', 'news']
}

fn test_sql_reader_quiterss() {
	path := feedut_sql_fixture('quiterss', [
		'create table feeds (id integer primary key, feed_url text, feed_name text, category_id integer)',
		'create table news (id integer primary key, feed_id integer, title text)',
		"insert into feeds values (1, 'https://b.example/rss', 'Feed B', 2)",
	])
	defer {
		os.rm(path) or {}
	}
	assert feed_store_detect(path) == .quiterss
	res := feed_store_load(path)!
	assert res.kind == .quiterss
	assert res.feeds.len == 1
	assert res.feeds[0].title == 'Feed B'
}

fn test_sql_reader_netnewswire() {
	path := feedut_sql_fixture('nnw', [
		'create table ZFEED (ZFEEDURL text, ZTITLE text, ZFOLDER text)',
		'create table ZENTRY (ZENTRYID integer primary key)',
		"insert into ZFEED values ('https://c.example/feed', 'Feed C', 'News/Tech')",
	])
	defer {
		os.rm(path) or {}
	}
	assert feed_store_detect(path) == .netnewswire
	res := feed_store_load(path)!
	assert res.kind == .netnewswire
	assert res.feeds.len == 1
	assert res.feeds[0].group_path == ['News', 'Tech']
}

fn test_sql_reader_vienna() {
	path := feedut_sql_fixture('vienna', [
		'create table feed (feed_url text, title text, folder text)',
		'create table article (article_id integer primary key)',
		"insert into feed values ('https://d.example/feed', 'Feed D', 'Reading')",
	])
	defer {
		os.rm(path) or {}
	}
	assert feed_store_detect(path) == .vienna
	res := feed_store_load(path)!
	assert res.kind == .vienna
	assert res.feeds.len == 1
	assert res.feeds[0].group_path == ['Reading']
}

fn test_sql_reader_feedme() {
	path := feedut_sql_fixture('feedme', [
		'create table feed (url text, title text, folder text)',
		'create table item (item_id integer primary key)',
		"insert into feed values ('https://e.example/feed', 'Feed E', 'Tech')",
	])
	defer {
		os.rm(path) or {}
	}
	assert feed_store_detect(path) == .feedme
	res := feed_store_load(path)!
	assert res.kind == .feedme
	assert res.feeds.len == 1
	assert res.feeds[0].group_path == ['Tech']
}

fn test_sql_reader_firefox() {
	path := feedut_sql_fixture('firefox', [
		'create table moz_places (id integer primary key, url text)',
		'create table moz_bookmarks (id integer primary key, type integer, fk integer, parent integer, title text, folder_type text)',
		'create table moz_anno_attributes (id integer primary key, name text)',
		'create table moz_items_annos (item_id integer, anno_attribute_id integer, content text)',
		"insert into moz_bookmarks values (1, 3, null, 2, 'Feed F', 'livemark')",
		"insert into moz_anno_attributes values (1, 'feedURL')",
		"insert into moz_items_annos values (1, 1, 'https://f.example/feed')",
	])
	defer {
		os.rm(path) or {}
	}
	assert feed_store_detect(path) == .firefox
	res := feed_store_load(path)!
	assert res.kind == .firefox
	assert res.feeds.len == 1
	assert res.feeds[0].title == 'Feed F'
	assert res.feeds[0].url == 'https://f.example/feed'
}
