module feedut

import strings
import touse.xml

pub struct FeedItem {
pub mut:
	title       string
	link        string
	description string
	author      string
	category    []string
	comments    string
	guid        string
	pub_date    string
	source_url  string
	source_text string
}

pub struct ParsedFeed {
pub mut:
	title string
	items []FeedItem
}

// parse_feed parses RSS 2.0 or Atom.
pub fn parse_feed(body string) !ParsedFeed {
	doc := xml.parse_document(strip_xml_header(body))
	if doc == unsafe { nil } {
		return error('xml parse failed')
	}
	defer { doc.free() }
	root := doc.root()
	match root.name() {
		'rss' {
			channel := child_node(root, 'channel') or { return error('rss: no channel') }
			mut pf := ParsedFeed{
				title: node_text(channel, 'title')
			}
			for item in children_by_tag(channel, 'item') {
				pf.items << parse_rss_item(item)
			}
			return pf
		}
		'feed' {
			mut pf := ParsedFeed{
				title: node_text(root, 'title')
			}
			for entry in children_by_tag(root, 'entry') {
				pf.items << parse_atom_entry(entry)
			}
			return pf
		}
		else {
			return error('unsupported feed root: ${root.name()}')
		}
	}
}

fn strip_xml_header(s string) string {
	mut t := s.trim_space()
	if t.starts_with('\xEF\xBB\xBF') {
		t = t[3..]
	}
	if t.starts_with('<?xml') {
		idx := t.index('?>') or { return replace_cdata(t) }
		t = t[idx + 2..]
	}
	return replace_cdata(t.trim_space())
}

// xmlc does not support CDATA; convert it to escaped text.
fn replace_cdata(s string) string {
	mut sb := strings.new_builder(s.len)
	mut i := 0
	for i < s.len {
		rest := s[i..]
		p := rest.index('<![CDATA[') or {
			sb.write_string(rest)
			break
		}
		start := i + p
		sb.write_string(s[i..start])
		body := s[start + 9..]
		q := body.index(']]>') or {
			sb.write_string(s[start..])
			break
		}
		end := start + 9 + q
		sb.write_string(escape_xml_text(s[start + 9..end]))
		i = end + 3
	}
	return sb.str()
}

fn escape_xml_text(s string) string {
	return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
}

fn children_by_tag(node &xml.Node2, tag string) []&xml.Node2 {
	mut out := []&xml.Node2{}
	for i in 0 .. node.count() {
		c := node.at(i)
		if c.name() == tag {
			out << c
		}
	}
	return out
}

fn child_node(node &xml.Node2, tag string) ?&xml.Node2 {
	for i in 0 .. node.count() {
		c := node.at(i)
		if c.name() == tag {
			return c
		}
	}
	return none
}

fn node_text(node &xml.Node2, tag string) string {
	if c := child_node(node, tag) {
		return xml_inner_text(c)
	}
	return ''
}

fn node_attr(node &xml.Node2, tag string, attr string) string {
	if c := child_node(node, tag) {
		return attr_of(c, attr)
	}
	return ''
}

fn attr_of(node &xml.Node2, key string) string {
	for i in 0 .. node.attr_count() {
		if node.attr_name(i) == key {
			return node.attr_value(i)
		}
	}
	return ''
}

fn xml_inner_text(node &xml.Node2) string {
	mut sb := strings.new_builder(64)
	direct := node.content()
	if direct != '' {
		sb.write_string(direct)
	}
	for i in 0 .. node.count() {
		sb.write_string(xml_inner_text(node.at(i)))
	}
	return sb.str().trim_space()
}

fn parse_rss_item(node &xml.Node2) FeedItem {
	mut it := FeedItem{
		title:       node_text(node, 'title')
		link:        node_text(node, 'link')
		description: node_text(node, 'description')
		guid:        node_text(node, 'guid')
		pub_date:    node_text(node, 'pubDate')
		author:      node_text(node, 'author')
		comments:    node_text(node, 'comments')
		source_url:  node_attr(node, 'source', 'url')
		source_text: node_text(node, 'source')
	}
	if it.author == '' {
		it.author = node_text(node, 'dc:creator')
	}
	for cat in children_by_tag(node, 'category') {
		it.category << xml_inner_text(cat)
	}
	return it
}

fn parse_atom_entry(node &xml.Node2) FeedItem {
	mut it := FeedItem{
		title:       node_text(node, 'title')
		guid:        node_text(node, 'id')
		pub_date:    node_text(node, 'published')
		description: node_text(node, 'summary')
	}
	if it.description == '' {
		it.description = node_text(node, 'content')
	}
	for c in children_by_tag(node, 'link') {
		href := attr_of(c, 'href')
		rel := attr_of(c, 'rel')
		if (rel == '' || rel == 'alternate') && href != '' {
			it.link = href
			break
		}
	}
	return it
}
