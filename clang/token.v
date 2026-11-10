module clang

fn C.clang_tokenize(tu TranslationUnit, r SourceRange, tokens &&C.CXToken, num_tokens &u32)
pub fn tokenize(tu TranslationUnit, r SourceRange) (&C.CXToken, u32) {
	mut tokens := &C.CXToken(unsafe { nil })
	mut num := u32(0)
	C.clang_tokenize(tu, r, &tokens, &num)
	return tokens, num
}

fn C.clang_disposeTokens(tu TranslationUnit, tokens &C.CXToken, num_tokens u32)
pub fn dispose_tokens(tu TranslationUnit, tokens &C.CXToken, num_tokens u32) {
	C.clang_disposeTokens(tu, tokens, num_tokens)
}

fn C.clang_getTokenKind(t C.CXToken) TokenKind
pub fn get_token_kind(t C.CXToken) TokenKind {
	return C.clang_getTokenKind(t)
}

fn C.clang_getTokenSpelling(tu TranslationUnit, t C.CXToken) String
pub fn get_token_spelling(tu TranslationUnit, t C.CXToken) string {
	return cxstring_to_string(C.clang_getTokenSpelling(tu, t))
}

fn C.clang_getTokenLocation(tu TranslationUnit, t C.CXToken) SourceLocation
pub fn get_token_location(tu TranslationUnit, t C.CXToken) SourceLocation {
	return C.clang_getTokenLocation(tu, t)
}

fn C.clang_getTokenExtent(tu TranslationUnit, t C.CXToken) SourceRange
pub fn get_token_extent(tu TranslationUnit, t C.CXToken) SourceRange {
	return C.clang_getTokenExtent(tu, t)
}

fn C.clang_annotateTokens(tu TranslationUnit, tokens &C.CXToken, num_tokens u32, cursors &Cursor)
pub fn annotate_tokens(tu TranslationUnit, tokens &C.CXToken, num_tokens u32, cursors &Cursor) {
	C.clang_annotateTokens(tu, tokens, num_tokens, cursors)
}

fn C.clang_getToken(tu TranslationUnit, loc SourceLocation) &C.CXToken
pub fn get_token(tu TranslationUnit, loc SourceLocation) &C.CXToken {
	return C.clang_getToken(tu, loc)
}
