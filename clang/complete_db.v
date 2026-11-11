module clang

fn C.clang_CompilationDatabase_fromDirectory(build_dir &char, error_code &int) CompilationDatabase
pub fn compilation_database_from_directory(build_dir string) (CompilationDatabase, int) {
	mut error := int(0)
	cdb := C.clang_CompilationDatabase_fromDirectory(unsafe { build_dir.str }, &error)
	return cdb, error
}

fn C.clang_CompilationDatabase_dispose(cdb CompilationDatabase)
pub fn compilation_database_dispose(cdb CompilationDatabase) {
	C.clang_CompilationDatabase_dispose(cdb)
}

fn C.clang_CompilationDatabase_getCompileCommands(cdb CompilationDatabase, complete_filename &char) CompileCommands
pub fn compilation_database_get_compile_commands(cdb CompilationDatabase, filename string) CompileCommands {
	return C.clang_CompilationDatabase_getCompileCommands(cdb, unsafe { filename.str })
}

fn C.clang_CompilationDatabase_getAllCompileCommands(cdb CompilationDatabase) CompileCommands
pub fn compilation_database_get_all_compile_commands(cdb CompilationDatabase) CompileCommands {
	return C.clang_CompilationDatabase_getAllCompileCommands(cdb)
}

fn C.clang_CompileCommands_dispose(cc CompileCommands)
pub fn compile_commands_dispose(cc CompileCommands) {
	C.clang_CompileCommands_dispose(cc)
}

fn C.clang_CompileCommands_getSize(cc CompileCommands) u32
pub fn compile_commands_get_size(cc CompileCommands) u32 {
	return C.clang_CompileCommands_getSize(cc)
}

fn C.clang_CompileCommands_getCommand(cc CompileCommands, i u32) CompileCommand
pub fn compile_commands_get_command(cc CompileCommands, i u32) CompileCommand {
	return C.clang_CompileCommands_getCommand(cc, i)
}

fn C.clang_CompileCommand_getDirectory(cmd CompileCommand) String
pub fn compile_command_get_directory(cmd CompileCommand) string {
	return cxstring_to_string(C.clang_CompileCommand_getDirectory(cmd))
}

fn C.clang_CompileCommand_getFilename(cmd CompileCommand) String
pub fn compile_command_get_filename(cmd CompileCommand) string {
	return cxstring_to_string(C.clang_CompileCommand_getFilename(cmd))
}

fn C.clang_CompileCommand_getNumArgs(cmd CompileCommand) u32
pub fn compile_command_get_num_args(cmd CompileCommand) u32 {
	return C.clang_CompileCommand_getNumArgs(cmd)
}

fn C.clang_CompileCommand_getArg(cmd CompileCommand, i u32) String
pub fn compile_command_get_arg(cmd CompileCommand, i u32) string {
	return cxstring_to_string(C.clang_CompileCommand_getArg(cmd, i))
}

fn C.clang_CompileCommand_getMappedSourceContent(arg0 CompileCommand, i u32) String
pub fn compile_command_get_mapped_source_content(arg0 CompileCommand, i u32) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_CompileCommand_getMappedSourceContent(arg0, i))
	}

	return ''
}

fn C.clang_CompileCommand_getMappedSourcePath(arg0 CompileCommand, i u32) String
pub fn compile_command_get_mapped_source_path(arg0 CompileCommand, i u32) string {
	if has_major(16) {
		return cxstring_to_string(C.clang_CompileCommand_getMappedSourcePath(arg0, i))
	}

	return ''
}

fn C.clang_CompileCommand_getNumMappedSources(arg0 CompileCommand) u32
pub fn compile_command_get_num_mapped_sources(arg0 CompileCommand) u32 {
	if has_major(16) {
		return C.clang_CompileCommand_getNumMappedSources(arg0)
	}

	return 0
}
