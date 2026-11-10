module clang

fn C.clang_getCursor(tu TranslationUnit, loc SourceLocation) Cursor
pub fn get_cursor(tu TranslationUnit, loc SourceLocation) Cursor {
	return C.clang_getCursor(tu, loc)
}

fn C.clang_getCursorLocation(cursor Cursor) SourceLocation
pub fn get_cursor_location(cursor Cursor) SourceLocation {
	return C.clang_getCursorLocation(cursor)
}

fn C.clang_getCursorExtent(cursor Cursor) SourceRange
pub fn get_cursor_extent(cursor Cursor) SourceRange {
	return C.clang_getCursorExtent(cursor)
}

fn C.clang_getNullLocation() SourceLocation
pub fn get_null_location() SourceLocation {
	return C.clang_getNullLocation()
}

fn C.clang_equalLocations(loc1 SourceLocation, loc2 SourceLocation) u32
pub fn equal_locations(loc1 SourceLocation, loc2 SourceLocation) bool {
	return C.clang_equalLocations(loc1, loc2) != 0
}

fn C.clang_getLocation(tu TranslationUnit, file File, line u32, column u32) SourceLocation
pub fn get_location(tu TranslationUnit, file File, line u32, column u32) SourceLocation {
	return C.clang_getLocation(tu, file, line, column)
}

fn C.clang_getLocationForOffset(tu TranslationUnit, file File, offset u32) SourceLocation
pub fn get_location_for_offset(tu TranslationUnit, file File, offset u32) SourceLocation {
	return C.clang_getLocationForOffset(tu, file, offset)
}

fn C.clang_Location_isInSystemHeader(location SourceLocation) int
pub fn location_is_in_system_header(location SourceLocation) bool {
	return C.clang_Location_isInSystemHeader(location) != 0
}

fn C.clang_Location_isFromMainFile(location SourceLocation) int
pub fn location_is_from_main_file(location SourceLocation) bool {
	return C.clang_Location_isFromMainFile(location) != 0
}

fn C.clang_getExpansionLocation(loc SourceLocation, file &File, line &u32, column &u32, offset &u32)
pub fn get_expansion_location(loc SourceLocation) (File, u32, u32, u32) {
	mut file := File(nil)
	mut line := u32(0)
	mut col := u32(0)
	mut offset := u32(0)
	C.clang_getExpansionLocation(loc, &file, &line, &col, &offset)
	return file, line, col, offset
}

fn C.clang_getSpellingLocation(loc SourceLocation, file &File, line &u32, column &u32, offset &u32)
pub fn get_spelling_location(loc SourceLocation) (File, u32, u32, u32) {
	mut file := File(nil)
	mut line := u32(0)
	mut col := u32(0)
	mut offset := u32(0)
	C.clang_getSpellingLocation(loc, &file, &line, &col, &offset)
	return file, line, col, offset
}

fn C.clang_getFileLocation(loc SourceLocation, file &File, line &u32, column &u32, offset &u32)
pub fn get_file_location(loc SourceLocation) (File, u32, u32, u32) {
	mut file := File(nil)
	mut line := u32(0)
	mut col := u32(0)
	mut offset := u32(0)
	C.clang_getFileLocation(loc, &file, &line, &col, &offset)
	return file, line, col, offset
}

fn C.clang_getNullRange() SourceRange
pub fn get_null_range() SourceRange {
	return C.clang_getNullRange()
}

fn C.clang_getRange(begin SourceLocation, end SourceLocation) SourceRange
pub fn get_range(begin SourceLocation, end SourceLocation) SourceRange {
	return C.clang_getRange(begin, end)
}

fn C.clang_equalRanges(r1 SourceRange, r2 SourceRange) u32
pub fn equal_ranges(r1 SourceRange, r2 SourceRange) bool {
	return C.clang_equalRanges(r1, r2) != 0
}

fn C.clang_Range_isNull(r SourceRange) int
pub fn range_is_null(r SourceRange) bool {
	return C.clang_Range_isNull(r) != 0
}

fn C.clang_getRangeStart(r SourceRange) SourceLocation
pub fn get_range_start(r SourceRange) SourceLocation {
	return C.clang_getRangeStart(r)
}

fn C.clang_getRangeEnd(r SourceRange) SourceLocation
pub fn get_range_end(r SourceRange) SourceLocation {
	return C.clang_getRangeEnd(r)
}

fn C.clang_getFileName(file File) String
pub fn get_file_name(file File) string {
	return cxstring_to_string(C.clang_getFileName(file))
}

fn C.clang_getFileTime(file File) i64
pub fn get_file_time(file File) i64 {
	return C.clang_getFileTime(file)
}

fn C.clang_File_isEqual(file1 File, file2 File) int
pub fn file_is_equal(file1 File, file2 File) bool {
	return C.clang_File_isEqual(file1, file2) != 0
}

fn C.clang_getFileContents(tu TranslationUnit, file File, size &usize) &char
pub fn get_file_contents(tu TranslationUnit, file File) string {
	mut size := usize(0)
	contents := C.clang_getFileContents(tu, file, &size)
	if contents == unsafe { nil } {
		return ''
	}
	return unsafe { contents.vstring_with_len(int(size)) }
}

fn C.clang_getSkippedRanges(tu TranslationUnit, file File) SourceRangeList
pub fn get_skipped_ranges(tu TranslationUnit, file File) SourceRangeList {
	return C.clang_getSkippedRanges(tu, file)
}

fn C.clang_getAllSkippedRanges(tu TranslationUnit) SourceRangeList
pub fn get_all_skipped_ranges(tu TranslationUnit) SourceRangeList {
	return C.clang_getAllSkippedRanges(tu)
}

fn C.clang_disposeSourceRangeList(ranges SourceRangeList)
pub fn dispose_source_range_list(ranges SourceRangeList) {
	C.clang_disposeSourceRangeList(ranges)
}

fn C.clang_isFileMultipleIncludeGuarded(tu TranslationUnit, file File) u32
pub fn is_file_multiple_include_guarded(tu TranslationUnit, file File) bool {
	return C.clang_isFileMultipleIncludeGuarded(tu, file) != 0
}

// clang/cursor_source.v 追加

fn C.clang_getFileUniqueID(file File, out_id &voidptr) int
pub fn get_file_unique_id(file File) (int, voidptr) {
	mut id := voidptr(nil)
	ret := C.clang_getFileUniqueID(file, &id)
	return ret, id
}

fn C.clang_File_tryGetRealPathName(file File) String
pub fn file_try_get_real_path_name(file File) string {
	return cxstring_to_string(C.clang_File_tryGetRealPathName(file))
}
