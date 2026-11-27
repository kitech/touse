import touse.htmpar

fn test_lexbor_basic() {
	if !htmpar.lexbor_libok() && htmpar.lexbor_dyn_init('') != 0 {
		println('SKIP: liblexbor not available')
		return
	}
	defer { htmpar.lexbor_cleanup() }

	assert htmpar.lexbor_has_symbol('lxb_html_document_create')

	doc := htmpar.lexbor_new_document() or {
		panic('lexbor create failed')
	}
	defer { doc.free() }

	html := '<html><head><title>Hi</title></head><body id="b"><p>ok</p></body></html>'
	assert doc.parse(html)
	assert doc.title() == 'Hi'
	body := doc.body()
	assert !body.is_nil()
	assert body.attr('id') == 'b'
	assert !body.first_child().is_nil()
}
