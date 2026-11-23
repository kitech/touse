module feedut

import db.sqlite
import os

// feed_store_sql_open opens a private copy of a SQLite store so a live reader
// database is never locked or modified by parsing.
fn feed_store_sql_open(path string) !sqlite.DB {
	tmp := feed_store_sqlite_copy(path)!
	mut db := sqlite.connect(tmp)!
	return db
}

fn feed_store_sql_rows(db sqlite.DB, query string) []sqlite.Row {
	return db.exec(query) or { return []sqlite.Row{} }
}

fn feed_store_sql_val(row sqlite.Row, idx int) string {
	if idx >= row.vals.len {
		return ''
	}
	return row.vals[idx]
}

fn feed_store_sql_int(row sqlite.Row, idx int) int {
	return feed_store_sql_val(row, idx).int()
}

// feed_store_load_liferea reads node/subscription/items tables from a Liferea
// database. Only type='folder' nodes become group_path; vfolder is ignored.
pub fn feed_store_load_liferea(path string) !StoreResult {
	tmp := feed_store_sqlite_copy(path)!
	defer {
		os.rm(tmp) or {}
	}
	mut db := sqlite.connect(tmp)!

	mut nodes := map[string]StoreFeed{}
	mut node_titles := map[string]string{}
	mut node_parents := map[string]string{}
	mut node_types := map[string]string{}
	for row in feed_store_sql_rows(db, 'select node_id, parent_id, title, type from node') {
		id := feed_store_sql_val(row, 0)
		node_titles[id] = feed_store_sql_val(row, 2)
		node_parents[id] = feed_store_sql_val(row, 1)
		node_types[id] = feed_store_sql_val(row, 3).to_lower()
	}
	for row in feed_store_sql_rows(db, 'select node_id, source, orig_source from subscription') {
		id := feed_store_sql_val(row, 0)
		url := feed_store_normalize_url(feed_store_sql_val(row, 1))
		if url == '' {
			url = feed_store_normalize_url(feed_store_sql_val(row, 2))
		}
		if url == '' || id in nodes {
			continue
		}
		title := node_titles[id]
		if title == '' {
			title = node_titles[id]
		}
		nodes[id] = StoreFeed{
			title:      title
			url:        url
			group_path: feed_store_liferea_group(node_parents[id], node_parents, node_types,
				node_titles)
			group_raw:  feed_store_liferea_group_raw(node_parents[id], node_parents, node_types,
				node_titles)
			source:     path
		}
	}

	mut item_meta := map[string]map[string][]string{}
	for row in feed_store_sql_rows(db, 'select item_id, key, value from metadata') {
		id := feed_store_sql_val(row, 0)
		key := feed_store_sql_val(row, 1).to_lower()
		val := feed_store_sql_val(row, 2)
		if val == '' {
			continue
		}
		if id !in item_meta {
			item_meta[id] = map[string][]string{}
		}
		item_meta[id][key] << val
	}

	for row in feed_store_sql_rows(db, 'select item_id, node_id, title, read, marked, source, source_id, description, date from items') {
		node_id := feed_store_sql_val(row, 1)
		if node_id !in nodes {
			continue
		}
		id := feed_store_sql_val(row, 0)
		it := StoredItem{
			title:       feed_store_sql_val(row, 2)
			link:        feed_store_sql_val(row, 5)
			guid:        feed_store_sql_val(row, 6)
			description: feed_store_sql_val(row, 7)
			pub_date:    feed_store_sql_epoch(feed_store_sql_val(row, 8))
			read:        feed_store_sql_int(row, 3) != 0
			starred:     feed_store_sql_int(row, 4) != 0
		}
		if meta := item_meta[id] {
			if vals := meta['author'] {
				if vals.len > 0 {
					it.author = vals[0]
				}
			}
			if it.author == '' {
				if vals := meta['creator'] {
					if vals.len > 0 {
						it.author = vals[0]
					}
				}
			}
			if vals := meta['category'] {
				it.category = vals.clone()
			}
		}
		mut feed := nodes[node_id]
		feed.items << it
		nodes[node_id] = feed
	}

	mut feeds := []StoreFeed{}
	for id in nodes.keys() {
		feeds << nodes[id]
	}
	return StoreResult{
		kind:  .liferea
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

fn feed_store_liferea_group(parent_id string, parents map[string]string, types map[string]string, titles map[string]string) []string {
	mut out := []string{}
	mut cur := parent_id
	mut guard := 0
	for cur != '' && guard < 32 {
		guard++
		if types[cur] == 'folder' {
			name := titles[cur]
			if name == '' {
				name = cur
			}
			out << name
		}
		cur = parents[cur]
	}
	out.reverse_in_place()
	return out
}

fn feed_store_liferea_group_raw(parent_id string, parents map[string]string, types map[string]string, titles map[string]string) string {
	return feed_store_liferea_group(parent_id, parents, types, titles).join('/')
}

fn feed_store_sql_epoch(raw string) string {
	n := raw.trim_space().int()
	if n <= 0 {
		return ''
	}
	// V's time module has no unix->Time constructor; keep the epoch seconds
	// as the canonical string form for downstream normalization.
	return n.str()
}

// feed_store_load_firefox reads legacy livemark folders from places.sqlite.
// Modern Firefox removed livemarks, so an empty feed list is a valid result.
pub fn feed_store_load_firefox(path string) !StoreResult {
	tmp := feed_store_sqlite_copy(path)!
	defer {
		os.rm(tmp) or {}
	}
	mut db := sqlite.connect(tmp)!
	mut feeds := []StoreFeed{}
	query := 'select b.title, a.content from moz_bookmarks b ' +
		'join moz_items_annos a on a.item_id=b.id ' +
		'join moz_anno_attributes n on n.id=a.anno_attribute_id ' +
		'where n.name="feedURL" and (b.type=3 or b.folder_type="livemark")'
	for row in feed_store_sql_rows(db, query) {
		title := feed_store_sql_val(row, 0)
		url := feed_store_sql_val(row, 1)
		if url == '' {
			continue
		}
		mut feed := StoreFeed{
			title:  title
			url:    feed_store_normalize_url(url)
			source: path
		}
		if feed.title == '' {
			feed.title = feed_store_title_from_url(feed.url)
		}
		feeds << feed
	}
	return StoreResult{
		kind:  .firefox
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

// feed_store_load_thunderbird reads RSS feed URLs from prefs.js of a profile.
pub fn feed_store_load_thunderbird(path string) !StoreResult {
	body := os.read_file(path) or { return StoreResult{
		kind: .thunderbird
		root: path
	} }
	mut rss_servers := []string{}
	for line in body.split_into_lines() {
		t := line.trim_space()
		if !t.starts_with('user_pref(') || !t.contains('mail.server') || !t.contains('"rss"') {
			continue
		}
		if idx := t.index('mail.server.') {
			rest := t[idx + 'mail.server.'.len..]
			if dot := rest.index('.') {
				server := rest[..dot]
				if server !in rss_servers {
					rss_servers << server
				}
			}
		}
	}
	mut feeds := []StoreFeed{}
	for line in body.split_into_lines() {
		t := line.trim_space()
		if !t.starts_with('user_pref(') {
			continue
		}
		mut matched := false
		for server in rss_servers {
			if t.contains('mail.server.${server}.') {
				matched = true
				break
			}
		}
		if !matched {
			continue
		}
		url := feed_store_first_url(t)
		if url == '' || (!url.starts_with('http://') && !url.starts_with('https://')) {
			continue
		}
		feeds << StoreFeed{
			title:  feed_store_title_from_url(url)
			url:    feed_store_normalize_url(url)
			source: path
		}
	}
	return StoreResult{
		kind:  .thunderbird
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

// feed_store_load_netnewswire reads Core Data tables of NetNewsWire.
pub fn feed_store_load_netnewswire(path string) !StoreResult {
	tmp := feed_store_sqlite_copy(path)!
	defer {
		os.rm(tmp) or {}
	}
	mut db := sqlite.connect(tmp)!
	mut feeds := []StoreFeed{}
	for row in feed_store_sql_rows(db, 'select zfeedurl, ztitle, zfolder from zfeed where zfeedurl is not null') {
		url := feed_store_normalize_url(feed_store_sql_val(row, 0))
		if url == '' {
			continue
		}
		mut feed := StoreFeed{
			title:  feed_store_sql_val(row, 1)
			url:    url
			source: path
		}
		if feed.title == '' {
			feed.title = feed_store_title_from_url(url)
		}
		feed.group_raw = feed_store_sql_val(row, 2)
		feed.group_path = feed_store_normalize_group(feed.group_raw)
		feeds << feed
	}
	return StoreResult{
		kind:  .netnewswire
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

// feed_store_load_vienna reads the SQLite schema used by Vienna RSS.
pub fn feed_store_load_vienna(path string) !StoreResult {
	tmp := feed_store_sqlite_copy(path)!
	defer {
		os.rm(tmp) or {}
	}
	mut db := sqlite.connect(tmp)!
	mut feeds := []StoreFeed{}
	for row in feed_store_sql_rows(db, 'select feed_url, title, folder from feed where feed_url is not null') {
		url := feed_store_normalize_url(feed_store_sql_val(row, 0))
		if url == '' {
			continue
		}
		mut feed := StoreFeed{
			title:  feed_store_sql_val(row, 1)
			url:    url
			source: path
		}
		if feed.title == '' {
			feed.title = feed_store_title_from_url(url)
		}
		feed.group_raw = feed_store_sql_val(row, 2)
		feed.group_path = feed_store_normalize_group(feed.group_raw)
		feeds << feed
	}
	return StoreResult{
		kind:  .vienna
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

// feed_store_load_rssguard reads feed/entry tables used by RSS Guard.
pub fn feed_store_load_rssguard(path string) !StoreResult {
	tmp := feed_store_sqlite_copy(path)!
	defer {
		os.rm(tmp) or {}
	}
	mut db := sqlite.connect(tmp)!
	mut feeds := []StoreFeed{}
	for row in feed_store_sql_rows(db, 'select url, title, category from feed where url is not null') {
		url := feed_store_normalize_url(feed_store_sql_val(row, 0))
		if url == '' {
			continue
		}
		mut feed := StoreFeed{
			title:  feed_store_sql_val(row, 1)
			url:    url
			source: path
		}
		if feed.title == '' {
			feed.title = feed_store_title_from_url(url)
		}
		feed.tags = feed_store_split_tags(feed_store_sql_val(row, 2))
		feeds << feed
	}
	return StoreResult{
		kind:  .rssguard
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

// feed_store_load_quiterss reads feeds/news tables used by QuiteRSS.
pub fn feed_store_load_quiterss(path string) !StoreResult {
	tmp := feed_store_sqlite_copy(path)!
	defer {
		os.rm(tmp) or {}
	}
	mut db := sqlite.connect(tmp)!
	mut feeds := []StoreFeed{}
	for row in feed_store_sql_rows(db, 'select feed_url, feed_name, category_id from feeds where feed_url is not null') {
		url := feed_store_normalize_url(feed_store_sql_val(row, 0))
		if url == '' {
			continue
		}
		mut feed := StoreFeed{
			title:  feed_store_sql_val(row, 1)
			url:    url
			source: path
		}
		if feed.title == '' {
			feed.title = feed_store_title_from_url(url)
		}
		feeds << feed
	}
	return StoreResult{
		kind:  .quiterss
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

// feed_store_load_feedme reads a generic feed/item SQLite schema used by FeedMe.
pub fn feed_store_load_feedme(path string) !StoreResult {
	tmp := feed_store_sqlite_copy(path)!
	defer {
		os.rm(tmp) or {}
	}
	mut db := sqlite.connect(tmp)!
	mut feeds := []StoreFeed{}
	for row in feed_store_sql_rows(db, 'select url, title, folder from feed where url is not null') {
		url := feed_store_normalize_url(feed_store_sql_val(row, 0))
		if url == '' {
			continue
		}
		mut feed := StoreFeed{
			title:  feed_store_sql_val(row, 1)
			url:    url
			source: path
		}
		if feed.title == '' {
			feed.title = feed_store_title_from_url(url)
		}
		feed.group_raw = feed_store_sql_val(row, 2)
		feed.group_path = feed_store_normalize_group(feed.group_raw)
		feeds << feed
	}
	return StoreResult{
		kind:  .feedme
		root:  path
		feeds: feed_store_dedupe(feeds)
	}
}

fn feed_store_split_tags(raw string) []string {
	mut out := []string{}
	for part in raw.replace(';', ',').split(',') {
		t := part.trim_space()
		if t != '' && t !in out {
			out << t
		}
	}
	return out
}

fn feed_store_first_url(s string) string {
	for prefix in ['http://', 'https://', 'feed://'] {
		if idx := s.index(prefix) {
			mut end := idx
			for end < s.len && s[end] != `"` && s[end] != `'` && s[end] != ` ` && s[end] != `;` {
				end++
			}
			return feed_store_normalize_url(s[idx..end])
		}
	}
	return ''
}
