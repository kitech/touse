module clang

// ═══ 生成器产出（确认后合入仓库）═══

fn C.clang_CXRewriter_create(tu TranslationUnit) Rewriter
pub fn cx_rewriter_create(tu TranslationUnit) Rewriter {
	if has_major(16) {
		return C.clang_CXRewriter_create(tu)
	}

	return 0
}

fn C.clang_CXRewriter_dispose(rew Rewriter)
pub fn cx_rewriter_dispose(rew Rewriter) {
	if has_major(16) {
		C.clang_CXRewriter_dispose(rew)
	}
}

fn C.clang_CXRewriter_insertTextBefore(rew Rewriter, loc SourceLocation, insert &char)
pub fn cx_rewriter_insert_text_before(rew Rewriter, loc SourceLocation, insert &char) {
	if has_major(16) {
		C.clang_CXRewriter_insertTextBefore(rew, loc, insert)
	}
}

fn C.clang_CXRewriter_overwriteChangedFiles(rew Rewriter) int
pub fn cx_rewriter_overwrite_changed_files(rew Rewriter) int {
	if has_major(16) {
		return C.clang_CXRewriter_overwriteChangedFiles(rew)
	}

	return 0
}

fn C.clang_CXRewriter_removeText(rew Rewriter, to_be_removed SourceRange)
pub fn cx_rewriter_remove_text(rew Rewriter, to_be_removed SourceRange) {
	if has_major(16) {
		C.clang_CXRewriter_removeText(rew, to_be_removed)
	}
}

fn C.clang_CXRewriter_replaceText(rew Rewriter, to_be_replaced SourceRange, replacement &char)
pub fn cx_rewriter_replace_text(rew Rewriter, to_be_replaced SourceRange, replacement &char) {
	if has_major(16) {
		C.clang_CXRewriter_replaceText(rew, to_be_replaced, replacement)
	}
}

fn C.clang_CXRewriter_writeMainFileToStdOut(rew Rewriter)
pub fn cx_rewriter_write_main_file_to_std_out(rew Rewriter) {
	if has_major(16) {
		C.clang_CXRewriter_writeMainFileToStdOut(rew)
	}
}
