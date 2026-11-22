module feedut

import os

fn test_feed_store_detect() {
	dir := os.temp_dir()
	opml_path := os.join_path(dir, 'feedut_detect.opml')
	rss_path := os.join_path(dir, 'feedut_detect.rss')
	sfeed_path := os.join_path(dir, 'feedut_detect.sfeed')
	sqlite_path := os.join_path(dir, 'feedut_detect.sqlite')
	defer {
		os.rm(opml_path) or {}
		os.rm(rss_path) or {}
		os.rm(sfeed_path) or {}
		os.rm(sqlite_path) or {}
	}
	os.write_file(opml_path, '<?xml version="1.0"?><opml version="2.0"><body></body></opml>')!
	os.write_file(rss_path, '<rss version="2.0"><channel><title>T</title></channel></rss>')!
	os.write_file(sfeed_path, '1700000000\tA\thttp://a\tbody\tid\n')!
	os.write_file(sqlite_path, 'SQLite format 3\x00rest')!
	assert feed_store_detect(opml_path) == .opml
	assert feed_store_detect(rss_path) == .rss
	assert feed_store_detect(sfeed_path) == .sfeed
	assert feed_store_detect(sqlite_path) == .sqlite
}

fn test_feed_store_opml_nested_groups() {
	body := '<?xml version="1.0" encoding="UTF-8"?>' +
		'<opml version="2.0"><head><title>Subs</title></head><body>' +
		'<outline text="News &amp; Views">' + '<outline text="Tech">' +
		'<outline text="Feed A" type="rss" xmlUrl="http://a.example/feed?x=1&amp;y=2" category="dev, v"/>' +
		'</outline>' + '<outline title="Feed B" xmlUrl="feed://b.example/rss"/>' + '</outline>' +
		'<outline text="Solo" xmlUrl="https://c.example/feed"/>' + '</body></opml>'
	res := feed_store_parse_opml(body, 'subs.opml')!
	assert res.kind == .opml
	assert res.feeds.len == 3
	assert res.feeds[0].title == 'Feed A'
	assert res.feeds[0].url == 'http://a.example/feed?x=1&y=2'
	assert res.feeds[0].group_path == ['News & Views', 'Tech']
	assert res.feeds[0].tags == ['dev', 'v']
	assert res.feeds[1].title == 'Feed B'
	assert res.feeds[1].url == 'http://b.example/rss'
	assert res.feeds[1].group_path == ['News & Views']
	assert res.feeds[2].group_path.len == 0
}

fn test_feed_store_rdf() {
	body := '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ' +
		'xmlns="http://purl.org/rss/1.0/" xmlns:dc="http://purl.org/dc/elements/1.1/" ' +
		'xmlns:content="http://purl.org/rss/1.0/modules/content/">' +
		'<channel><title>RDF Feed</title><link>http://rdf</link></channel>' +
		'<item rdf:about="http://rdf/1"><title>R1</title><link>http://rdf/1</link>' +
		'<description></description><content:encoded><![CDATA[<p>Body</p>]]></content:encoded>' +
		'<dc:date>2026-01-01T00:00:00Z</dc:date><dc:creator>Ann</dc:creator></item>' + '</rdf:RDF>'
	res := feed_store_parse_rss(body, 'rdf.xml')!
	assert res.kind == .rss
	assert res.feeds[0].title == 'RDF Feed'
	assert res.feeds[0].items.len == 1
	assert res.feeds[0].items[0].description == '<p>Body</p>'
	assert res.feeds[0].items[0].author == 'Ann'
}

fn test_feed_store_sfeed() {
	body := '1700000000\tA\thttp://a\tbody\tid1\tAnn\n' +
		'1700000001\tB\thttp://b\tbody2\tid2\tBob\n'
	res := feed_store_parse_sfeed(body, '/tmp/sfeed/feeds/oschina', '/tmp/sfeed')!
	assert res.kind == .sfeed
	assert res.feeds[0].title == 'oschina'
	assert res.feeds[0].group_path == ['feeds']
	assert res.feeds[0].items.len == 2
	assert res.feeds[0].items[0].title == 'A'
	assert res.feeds[0].items[1].guid == 'id2'
}

fn test_feed_store_normalize_group() {
	assert feed_store_normalize_group('/News//Tech/') == ['News', 'Tech']
	assert feed_store_normalize_group('A\\B') == ['A', 'B']
}

fn test_feed_store_dedupe() {
	feeds := [
		StoreFeed{
			url:        'http://a'
			group_path: []string{}
			tags:       ['x']
		},
		StoreFeed{
			url:        'http://a'
			title:      'A'
			group_path: ['G']
			tags:       ['y']
			items:      [StoredItem{
				link: 'http://a/1'
			}]
		},
		StoreFeed{
			url:        'http://a'
			group_path: ['H']
			items:      [StoredItem{
				link: 'http://a/1'
			}, StoredItem{
				link: 'http://a/2'
			}]
		},
	]
	out := feed_store_dedupe(feeds)
	assert out.len == 1
	assert out[0].title == 'A'
	assert out[0].group_path == ['G']
	assert out[0].tags == ['x', 'y']
	assert out[0].items.len == 2
}

fn test_feed_store_groups() {
	feeds := [
		StoreFeed{
			url:        'http://a'
			group_path: ['News', 'Tech']
		},
		StoreFeed{
			url:        'http://b'
			group_path: ['News', 'Tech']
		},
		StoreFeed{
			url:        'http://c'
			group_path: ['News']
		},
	]
	groups := feed_store_groups(feeds)
	assert groups.len == 1
	assert groups[0].name == 'News'
	assert groups[0].feed_urls == ['http://c']
	assert groups[0].children.len == 1
	assert groups[0].children[0].name == 'Tech'
	assert groups[0].children[0].feed_urls == ['http://a', 'http://b']
	assert groups[0].children[0].path == ['News', 'Tech']
}
