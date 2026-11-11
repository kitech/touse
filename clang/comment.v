module clang

// ═══ 生成器产出（确认后合入仓库）═══

fn C.clang_BlockCommandComment_getArgText(comment Comment, arg_idx u32) String
pub fn block_command_comment_get_arg_text(comment Comment, arg_idx u32) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_BlockCommandComment_getArgText(comment, arg_idx))
	}

	return ''
}

fn C.clang_BlockCommandComment_getCommandName(comment Comment) String
pub fn block_command_comment_get_command_name(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_BlockCommandComment_getCommandName(comment))
	}

	return ''
}

fn C.clang_BlockCommandComment_getNumArgs(comment Comment) u32
pub fn block_command_comment_get_num_args(comment Comment) u32 {
	if has_major(16) {
		return C.clang_BlockCommandComment_getNumArgs(comment)
	}

	return 0
}

fn C.clang_BlockCommandComment_getParagraph(comment Comment) Comment
pub fn block_command_comment_get_paragraph(comment Comment) Comment {
	if has_major(16) {
		return C.clang_BlockCommandComment_getParagraph(comment)
	}

	return Comment{}
}

fn C.clang_Comment_getChild(comment Comment, child_idx u32) Comment
pub fn comment_get_child(comment Comment, child_idx u32) Comment {
	if has_major(16) {
		return C.clang_Comment_getChild(comment, child_idx)
	}

	return Comment{}
}

fn C.clang_Comment_getKind(comment Comment) int
pub fn comment_get_kind(comment Comment) int {
	if has_major(16) {
		return C.clang_Comment_getKind(comment)
	}

	return 0
}

fn C.clang_Comment_getNumChildren(comment Comment) u32
pub fn comment_get_num_children(comment Comment) u32 {
	if has_major(16) {
		return C.clang_Comment_getNumChildren(comment)
	}

	return 0
}

fn C.clang_Comment_isWhitespace(comment Comment) u32
pub fn comment_is_whitespace(comment Comment) u32 {
	if has_major(16) {
		return C.clang_Comment_isWhitespace(comment)
	}

	return 0
}

fn C.clang_Cursor_getCommentRange(c Cursor) SourceRange
pub fn cursor_get_comment_range(c Cursor) SourceRange {
	return C.clang_Cursor_getCommentRange(c)
}

fn C.clang_Cursor_getParsedComment(c Cursor) Comment
pub fn cursor_get_parsed_comment(c Cursor) Comment {
	if has_major(16) {
		return C.clang_Cursor_getParsedComment(c)
	}

	return Comment{}
}

fn C.clang_FullComment_getAsHTML(comment Comment) String
pub fn full_comment_get_as_html(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_FullComment_getAsHTML(comment))
	}

	return ''
}

fn C.clang_FullComment_getAsXML(comment Comment) String
pub fn full_comment_get_as_xml(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_FullComment_getAsXML(comment))
	}

	return ''
}

fn C.clang_HTMLStartTagComment_isSelfClosing(comment Comment) u32
pub fn html_start_tag_comment_is_self_closing(comment Comment) u32 {
	if has_major(16) {
		return C.clang_HTMLStartTagComment_isSelfClosing(comment)
	}

	return 0
}

fn C.clang_HTMLStartTag_getAttrName(comment Comment, attr_idx u32) String
pub fn html_start_tag_get_attr_name(comment Comment, attr_idx u32) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_HTMLStartTag_getAttrName(comment, attr_idx))
	}

	return ''
}

fn C.clang_HTMLStartTag_getAttrValue(comment Comment, attr_idx u32) String
pub fn html_start_tag_get_attr_value(comment Comment, attr_idx u32) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_HTMLStartTag_getAttrValue(comment, attr_idx))
	}

	return ''
}

fn C.clang_HTMLStartTag_getNumAttrs(comment Comment) u32
pub fn html_start_tag_get_num_attrs(comment Comment) u32 {
	if has_major(16) {
		return C.clang_HTMLStartTag_getNumAttrs(comment)
	}

	return 0
}

fn C.clang_HTMLTagComment_getAsString(comment Comment) String
pub fn html_tag_comment_get_as_string(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_HTMLTagComment_getAsString(comment))
	}

	return ''
}

fn C.clang_HTMLTagComment_getTagName(comment Comment) String
pub fn html_tag_comment_get_tag_name(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_HTMLTagComment_getTagName(comment))
	}

	return ''
}

fn C.clang_InlineCommandComment_getArgText(comment Comment, arg_idx u32) String
pub fn inline_command_comment_get_arg_text(comment Comment, arg_idx u32) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_InlineCommandComment_getArgText(comment, arg_idx))
	}

	return ''
}

fn C.clang_InlineCommandComment_getCommandName(comment Comment) String
pub fn inline_command_comment_get_command_name(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_InlineCommandComment_getCommandName(comment))
	}

	return ''
}

fn C.clang_InlineCommandComment_getNumArgs(comment Comment) u32
pub fn inline_command_comment_get_num_args(comment Comment) u32 {
	if has_major(16) {
		return C.clang_InlineCommandComment_getNumArgs(comment)
	}

	return 0
}

fn C.clang_InlineCommandComment_getRenderKind(comment Comment) int
pub fn inline_command_comment_get_render_kind(comment Comment) int {
	if has_major(16) {
		return C.clang_InlineCommandComment_getRenderKind(comment)
	}

	return 0
}

fn C.clang_InlineContentComment_hasTrailingNewline(comment Comment) u32
pub fn inline_content_comment_has_trailing_newline(comment Comment) u32 {
	if has_major(16) {
		return C.clang_InlineContentComment_hasTrailingNewline(comment)
	}

	return 0
}

fn C.clang_ParamCommandComment_getDirection(comment Comment) int
pub fn param_command_comment_get_direction(comment Comment) int {
	if has_major(16) {
		return C.clang_ParamCommandComment_getDirection(comment)
	}

	return 0
}

fn C.clang_ParamCommandComment_getParamIndex(comment Comment) u32
pub fn param_command_comment_get_param_index(comment Comment) u32 {
	if has_major(16) {
		return C.clang_ParamCommandComment_getParamIndex(comment)
	}

	return 0
}

fn C.clang_ParamCommandComment_getParamName(comment Comment) String
pub fn param_command_comment_get_param_name(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_ParamCommandComment_getParamName(comment))
	}

	return ''
}

fn C.clang_ParamCommandComment_isDirectionExplicit(comment Comment) u32
pub fn param_command_comment_is_direction_explicit(comment Comment) u32 {
	if has_major(16) {
		return C.clang_ParamCommandComment_isDirectionExplicit(comment)
	}

	return 0
}

fn C.clang_ParamCommandComment_isParamIndexValid(comment Comment) u32
pub fn param_command_comment_is_param_index_valid(comment Comment) u32 {
	if has_major(16) {
		return C.clang_ParamCommandComment_isParamIndexValid(comment)
	}

	return 0
}

fn C.clang_TParamCommandComment_getDepth(comment Comment) u32
pub fn t_param_command_comment_get_depth(comment Comment) u32 {
	if has_major(16) {
		return C.clang_TParamCommandComment_getDepth(comment)
	}

	return 0
}

fn C.clang_TParamCommandComment_getIndex(comment Comment, depth u32) u32
pub fn t_param_command_comment_get_index(comment Comment, depth u32) u32 {
	if has_major(16) {
		return C.clang_TParamCommandComment_getIndex(comment, depth)
	}

	return 0
}

fn C.clang_TParamCommandComment_getParamName(comment Comment) String
pub fn t_param_command_comment_get_param_name(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_TParamCommandComment_getParamName(comment))
	}

	return ''
}

fn C.clang_TParamCommandComment_isParamPositionValid(comment Comment) u32
pub fn t_param_command_comment_is_param_position_valid(comment Comment) u32 {
	if has_major(16) {
		return C.clang_TParamCommandComment_isParamPositionValid(comment)
	}

	return 0
}

fn C.clang_TextComment_getText(comment Comment) String
pub fn text_comment_get_text(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_TextComment_getText(comment))
	}

	return ''
}

fn C.clang_VerbatimBlockLineComment_getText(comment Comment) String
pub fn verbatim_block_line_comment_get_text(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_VerbatimBlockLineComment_getText(comment))
	}

	return ''
}

fn C.clang_VerbatimLineComment_getText(comment Comment) String
pub fn verbatim_line_comment_get_text(comment Comment) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_VerbatimLineComment_getText(comment))
	}

	return ''
}

fn C.clang_createAPISet(tu TranslationUnit, out_api &ApiSet) int
pub fn create_api_set(tu TranslationUnit, out_api &ApiSet) int {
	if has_major(16) {
		return C.clang_createAPISet(tu, out_api)
	}

	return 0
}

fn C.clang_disposeAPISet(api ApiSet)
pub fn dispose_api_set(api ApiSet) {
	if has_major(16) {
		C.clang_disposeAPISet(api)
	}
}

fn C.clang_getSymbolGraphForCursor(cursor Cursor) String
pub fn get_symbol_graph_for_cursor(cursor Cursor) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_getSymbolGraphForCursor(cursor))
	}

	return ''
}

fn C.clang_getSymbolGraphForUSR(usr &char, api ApiSet) String
pub fn get_symbol_graph_for_usr(usr &char, api ApiSet) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_getSymbolGraphForUSR(usr, api))
	}

	return ''
}
