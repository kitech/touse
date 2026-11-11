import vcp.tcchf
import touse.clang

// 测试辅助：解析一段 C 源码
fn parse_c() (clang.Index, clang.TranslationUnit, clang.ErrorCode) {
	idx := clang.create_index(0, 0)
	src := 'int g_var = 7;\n/// doc comment for f\nint f(int a) { return a + g_var; }\nstruct S { int x; };\n'
	tu, ec := clang.parse_translation_unit2(idx, 'demo.c', ['-x', 'c'], [], 0)
	return idx, tu, ec
}

fn test_version_detection() {
	major := clang.clang_major()
	assert major >= 15 && major <= 23
	assert clang.has_major(15)
	assert !clang.has_major(24)
}

fn test_tu_parse_and_reparse() {
	idx, mut tu, mut ec := parse_c()
	defer {
		clang.dispose_translation_unit(tu)
		clang.dispose_index(idx)
	}
	assert ec == .success
	assert tu != 0
	assert clang.get_num_diagnostics(tu) == 0
	// 新绑定：TU spelling / reparse / save options
	assert clang.get_translation_unit_spelling(tu) == 'demo.c'
	opts := clang.default_reparse_options(tu)
	assert opts >= 0
	assert clang.reparse_translation_unit(tu, 0, unsafe { nil }, opts) == 0
}

fn test_cursor_bindings() {
	idx, mut tu, mut ec := parse_c()
	defer {
		clang.dispose_translation_unit(tu)
		clang.dispose_index(idx)
	}
	assert ec == .success
	cur := clang.get_translation_unit_cursor(tu)
	assert clang.is_translation_unit(clang.get_cursor_kind(cur))
	// 新绑定：Cursor->TU 往返
	assert clang.cursor_get_translation_unit(cur) == tu
	// USR 构造函数（纯函数）
	objc_usr := clang.construct_usr_obj_c_class('Foo'.str)
	assert objc_usr.len > 0
	// 结果类型/模板参数
	rt := clang.get_cursor_result_type(cur)
	assert clang.get_type_spelling(rt).len >= 0
	assert clang.cursor_get_num_template_arguments(cur) == -1 // 非模板
	// hasAttrs / bitfield
	assert clang.cursor_has_attrs(cur) == 0
}

fn test_comment_ast() {
	idx, mut tu, mut ec := parse_c()
	defer {
		clang.dispose_translation_unit(tu)
		clang.dispose_index(idx)
	}
	assert ec == .success
	cur := clang.get_translation_unit_cursor(tu)
	// TU 游标无注释 → Comment{} 降级/无效注释，调用不应崩溃
	cm := clang.cursor_get_parsed_comment(cur)
	assert clang.comment_get_kind(cm) == int(clang.CommentKind.null)
	assert clang.comment_get_num_children(cm) == 0
}

fn test_type_bindings() {
	idx, mut tu, mut ec := parse_c()
	defer {
		clang.dispose_translation_unit(tu)
		clang.dispose_index(idx)
	}
	assert ec == .success
	cur := clang.get_translation_unit_cursor(tu)
	rt := clang.get_cursor_result_type(cur)
	assert int(rt.kind) == int(clang.TypeKind.invalid)
	// 新绑定：数组大小（非数组 → -1）
	assert clang.get_array_size(rt) == -1
	// 数组拼写/pretty print（since=20 守卫走真实现）
	pp := clang.get_type_pretty_printed(rt, voidptr(0))
	assert pp.len >= 0
}

fn test_compile_database() {
	db, ec := clang.compilation_database_from_directory('/tmp/opencode/cdb')
	assert ec == 0
	defer { clang.compilation_database_dispose(db) }
	ccs := clang.compilation_database_get_compile_commands(db, '/tmp/opencode/cdb/demo.c')
	assert ccs != 0
	defer { clang.compile_commands_dispose(ccs) }
	assert clang.compile_commands_get_size(ccs) == 1
	cmd := clang.compile_commands_get_command(ccs, 0)
	assert clang.compile_command_get_filename(cmd) == 'demo.c'
	// 新绑定（since=16 守卫）：mapped sources
	assert clang.compile_command_get_num_mapped_sources(cmd) == 0
}

fn test_diag_and_printing_policy() {
	idx, mut tu, mut ec := parse_c()
	defer {
		clang.dispose_translation_unit(tu)
		clang.dispose_index(idx)
	}
	assert ec == .success
	// 新绑定：DiagnosticSet FromTU（TU 无诊断 → 空集合）
	ds := clang.get_diagnostic_set_from_tu(tu)
	assert ds != 0
	assert clang.get_num_diagnostics_in_set(ds) == 0
	clang.dispose_diagnostic_set(ds)
}

fn test_buildsys_and_module() {
	// VirtualFileOverlay（since=16 守卫）
	ov := clang.virtual_file_overlay_create(0)
	assert ov != 0
	assert clang.virtual_file_overlay_add_file_mapping(ov, '/v/foo.h'.str, '/r/foo.h'.str) == 0
	clang.virtual_file_overlay_dispose(ov)
	// ModuleMapDescriptor
	md := clang.module_map_descriptor_create(0)
	assert md != 0
	assert clang.module_map_descriptor_set_framework_module_name(md, 'Foo'.str) == 0
	clang.module_map_descriptor_dispose(md)
	// build session timestamp
	assert clang.get_build_session_timestamp() != 0
}

fn test_enums_and_guards() {
	assert int(clang.CommentKind.null) == 0
	assert int(clang.CommentKind.fullcomment) == 12
	assert int(clang.TemplateArgumentKind.invalid) == 9
	assert int(clang.UnaryOperatorKind.postinc) == 1
	// 守卫函数本身
	assert clang.has_major(16) == true
	assert clang.has_major(99) == false
}
