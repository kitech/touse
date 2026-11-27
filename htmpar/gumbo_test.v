import touse.htmpar

fn test_gumbo_basic() {
	if !htmpar.gumbo_libok() && htmpar.gumbo_dyn_init('') != 0 {
		println('SKIP: libgumbo not available')
		return
	}
	defer { htmpar.gumbo_cleanup() }

	assert htmpar.gumbo_has_symbol('gumbo_parse')
	assert htmpar.gumbo_has_symbol('gumbo_destroy_output')

	out := htmpar.gumbo_parse('<h1>Hi</h1>') or {
		panic('gumbo parse failed: $err')
	}
	defer { htmpar.gumbo_destroy(out) }
	assert !isnil(out)

	h1 := htmpar.gumbo_tag_enum('h1')
	assert h1 >= 0
	assert htmpar.gumbo_normalized_tagname(h1) == 'h1'
	assert htmpar.gumbo_tag_is_void(htmpar.gumbo_tag_enum('br'))

	doc := htmpar.gumbo_document(out) or { panic('gumbo document missing') }
	assert htmpar.gumbo_node_type(doc) == 0
	assert htmpar.gumbo_node_tag(htmpar.gumbo_node_children(doc)[0]) == htmpar.gumbo_tag_enum('html')

	doc2 := htmpar.gumbo_new_document('<h1>Hi</h1>') or {
		panic('gumbo new document failed: $err')
	}
	defer { doc2.free() }

	dnode := doc2.document()
	assert !dnode.is_nil()
	assert dnode.type_id() == 0

	html_node := dnode.children()[0]
	assert html_node.tag() == htmpar.gumbo_tag_enum('html')
	assert html_node.tag_name() == 'html'
}
