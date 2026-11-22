module feedut

fn test_parse_rss() {
	body := '<rss version="2.0"><channel><title>Demo</title>' +
		'<item><title>A</title><link>http://a</link><guid>g1</guid>' +
		'<pubDate>Mon, 01 Jan 2026 00:00:00 GMT</pubDate></item>' +
		'<item><title><![CDATA[B & C]]></title><link>http://b</link></item>' +
		'</channel></rss>'
	pf := parse_feed(body)!
	assert pf.title == 'Demo'
	assert pf.items.len == 2
	assert pf.items[0].title == 'A'
	assert pf.items[0].guid == 'g1'
	assert pf.items[1].title == 'B & C'
}

fn test_parse_atom() {
	body := '<feed xmlns="http://www.w3.org/2005/Atom"><title>Atom</title>' +
		'<entry><title>E1</title><id>urn:1</id>' +
		'<link rel="alternate" href="http://e1"/>' +
		'<updated>2026-01-01T00:00:00Z</updated></entry></feed>'
	pf := parse_feed(body)!
	assert pf.title == 'Atom'
	assert pf.items.len == 1
	assert pf.items[0].link == 'http://e1'
	assert pf.items[0].guid == 'urn:1'
}

fn test_parse_bad() {
	if _ := parse_feed('<not-xml') {
		assert false
	} else {
		assert true
	}
}
