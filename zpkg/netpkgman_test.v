import os
import touse.htmpar

fn test_query_normalization() {
	assert normalize_query('  web   scraping ') or { '' } == 'web scraping'
	assert normalize_query('c++') or { '' } == 'c++'
	if q := normalize_query('   ') {
		assert q == ''
	} else {
		assert err.str().contains('关键词不能为空')
	}
}

fn test_query_encoding() {
	assert enc_query('web scraping') == 'web+scraping'
	assert enc_query('c++') == 'c%2B%2B'
	assert enc_query('rust & json') == 'rust+%26+json'
	assert enc_path('foo/bar') == 'foo%2Fbar'
	assert enc_path('web scraping') == 'web%20scraping'
}

fn test_live_search() {
	if os.getenv('NETPKG_SMOKE') == '' {
		return
	}
	mut q := os.getenv('NETPKG_SMOKE_QUERY')
	if q == '' {
		q = 'hello'
	}
	for m in manager_names() {
		items := search(m, q, 3, 20) or {
			eprintln('${m}: ERR $err')
			continue
		}
		first := if items.len > 0 { items[0].name } else { '' }
		eprintln('${m}: ${items.len} $first')
	}
}

fn test_dom_helpers() {
	html := '<div class="card"><a href="/p/x"><span class="name">Hello &amp; Co</span><span class="desc">world</span></a></div>'
	doc := dom_doc(html, 'test') or {
		panic('dom_doc failed: $err')
	}
	defer { doc.free() }

	cards := dom_find_all(doc.document(), 'card')
	assert cards.len == 1
	if a := dom_first_link(cards[0]) {
		assert a.attr('href') == '/p/x'
	}
	if n := dom_first(cards[0], 'name') {
		assert dom_text(n) == 'Hello & Co'
	}
	if n := dom_first(cards[0], 'desc') {
		assert dom_text(n) == 'world'
	}
}
