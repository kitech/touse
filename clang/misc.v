module clang

fn C.clang_getClangVersion() String
pub fn get_clang_version() string {
	return cxstring_to_string(C.clang_getClangVersion())
}

fn C.clang_toggleCrashRecovery(is_enabled u32)
pub fn toggle_crash_recovery(is_enabled bool) {
	C.clang_toggleCrashRecovery(if is_enabled { u32(1) } else { u32(0) })
}

fn C.clang_Cursor_Evaluate(cursor Cursor) EvalResult
pub fn cursor_evaluate(cursor Cursor) EvalResult {
	return C.clang_Cursor_Evaluate(cursor)
}

fn C.clang_EvalResult_dispose(result EvalResult)
pub fn eval_result_dispose(result EvalResult) {
	C.clang_EvalResult_dispose(result)
}

fn C.clang_EvalResult_getKind(result EvalResult) EvalResultKind
pub fn eval_result_get_kind(result EvalResult) EvalResultKind {
	return C.clang_EvalResult_getKind(result)
}

fn C.clang_EvalResult_getAsInt(result EvalResult) int
pub fn eval_result_get_as_int(result EvalResult) int {
	return C.clang_EvalResult_getAsInt(result)
}

fn C.clang_EvalResult_getAsDouble(result EvalResult) f64
pub fn eval_result_get_as_double(result EvalResult) f64 {
	return C.clang_EvalResult_getAsDouble(result)
}

fn C.clang_EvalResult_getAsStr(result EvalResult) &char
pub fn eval_result_get_as_str(result EvalResult) &char {
	return C.clang_EvalResult_getAsStr(result)
}

fn C.clang_EvalResult_isUnsignedInt(result EvalResult) u32
pub fn eval_result_is_unsigned_int(result EvalResult) bool {
	return C.clang_EvalResult_isUnsignedInt(result) != 0
}

fn C.clang_EvalResult_getAsUnsigned(result EvalResult) u64
pub fn eval_result_get_as_unsigned(result EvalResult) u64 {
	return C.clang_EvalResult_getAsUnsigned(result)
}

fn C.clang_createCXCursorSet() CursorSet
pub fn create_cursor_set() CursorSet {
	return C.clang_createCXCursorSet()
}

fn C.clang_disposeCXCursorSet(cset CursorSet)
pub fn dispose_cursor_set(cset CursorSet) {
	C.clang_disposeCXCursorSet(cset)
}

fn C.clang_CXCursorSet_contains(cset CursorSet, cursor Cursor) u32
pub fn cursor_set_contains(cset CursorSet, cursor Cursor) bool {
	return C.clang_CXCursorSet_contains(cset, cursor) != 0
}

fn C.clang_CXCursorSet_insert(cset CursorSet, cursor Cursor) u32
pub fn cursor_set_insert(cset CursorSet, cursor Cursor) bool {
	return C.clang_CXCursorSet_insert(cset, cursor) != 0
}

// clang/misc.v 追加

// 文件包含关系遍历（已有 get_inclusions，但回调结构体 CXInclusionVisitor 需确认）
// 版本相关：获取详细版本信息
fn C.clang_getClangVersion() String // 已有
// 崩溃恢复开关（已有 toggle_crash_recovery）

// CursorSet 操作（已有 create/dispose/contains/insert）

// EvalResult 操作（已有 evaluate/dispose/getKind/getAsInt/getAsDouble/getAsStr/isUnsignedInt/getAsUnsigned）

// 线程执行（已有 execute_on_thread）

fn C.clang_EvalResult_getAsLongLong(e EvalResult) i64
pub fn eval_result_get_as_long_long(e EvalResult) i64 {
	return C.clang_EvalResult_getAsLongLong(e)
}

fn C.clang_PrintingPolicy_getProperty(policy PrintingPolicy, property int) u32
pub fn printing_policy_get_property(policy PrintingPolicy, property int) u32 {
	return C.clang_PrintingPolicy_getProperty(policy, property)
}

fn C.clang_PrintingPolicy_setProperty(policy PrintingPolicy, property int, value u32)
pub fn printing_policy_set_property(policy PrintingPolicy, property int, value u32) {
	C.clang_PrintingPolicy_setProperty(policy, property, value)
}

fn C.clang_codeCompleteGetContainerKind(results &CodeCompleteResults, is_incomplete &u32) int
pub fn code_complete_get_container_kind(results &CodeCompleteResults, is_incomplete &u32) int {
	return C.clang_codeCompleteGetContainerKind(results, is_incomplete)
}

fn C.clang_codeCompleteGetContainerUSR(results &CodeCompleteResults) String
pub fn code_complete_get_container_usr(results &CodeCompleteResults) string {
	return cxstring_to_string(C.clang_codeCompleteGetContainerUSR(results))
}

fn C.clang_codeCompleteGetObjCSelector(results &CodeCompleteResults) String
pub fn code_complete_get_obj_c_selector(results &CodeCompleteResults) string {
	return cxstring_to_string(C.clang_codeCompleteGetObjCSelector(results))
}

fn C.clang_constructUSR_ObjCCategory(class_name &char, category_name &char) String
pub fn construct_usr_obj_c_category(class_name &char, category_name &char) string {
	return cxstring_to_string(C.clang_constructUSR_ObjCCategory(class_name, category_name))
}

fn C.clang_constructUSR_ObjCClass(class_name &char) String
pub fn construct_usr_obj_c_class(class_name &char) string {
	return cxstring_to_string(C.clang_constructUSR_ObjCClass(class_name))
}

fn C.clang_constructUSR_ObjCIvar(name &char, classUSR_ String) String
pub fn construct_usr_obj_c_ivar(name &char, classUSR_ String) string {
	return cxstring_to_string(C.clang_constructUSR_ObjCIvar(name, classUSR_))
}

fn C.clang_constructUSR_ObjCMethod(name &char, isInstanceMethod_ u32, classUSR_ String) String
pub fn construct_usr_obj_c_method(name &char, isInstanceMethod_ u32, classUSR_ String) string {
	return cxstring_to_string(C.clang_constructUSR_ObjCMethod(name, isInstanceMethod_, classUSR_))
}

fn C.clang_constructUSR_ObjCProperty(property &char, classUSR_ String) String
pub fn construct_usr_obj_c_property(property &char, classUSR_ String) string {
	return cxstring_to_string(C.clang_constructUSR_ObjCProperty(property, classUSR_))
}

fn C.clang_constructUSR_ObjCProtocol(protocol_name &char) String
pub fn construct_usr_obj_c_protocol(protocol_name &char) string {
	return cxstring_to_string(C.clang_constructUSR_ObjCProtocol(protocol_name))
}

fn C.clang_defaultCodeCompleteOptions() u32
pub fn default_code_complete_options() u32 {
	return C.clang_defaultCodeCompleteOptions()
}

fn C.clang_defaultSaveOptions(tu TranslationUnit) u32
pub fn default_save_options(tu TranslationUnit) u32 {
	return C.clang_defaultSaveOptions(tu)
}

fn C.clang_getAddressSpace(t Type) u32
pub fn get_address_space(t Type) u32 {
	return C.clang_getAddressSpace(t)
}

fn C.clang_getArrayElementType(t Type) Type
pub fn get_array_element_type(t Type) Type {
	return C.clang_getArrayElementType(t)
}

fn C.clang_getArraySize(t Type) i64
pub fn get_array_size(t Type) i64 {
	return C.clang_getArraySize(t)
}

fn C.clang_getBinaryOperatorKindSpelling(kind int) String
pub fn get_binary_operator_kind_spelling(kind int) string {
	if has_major(17) {
		return cxstring_to_string(C.clang_getBinaryOperatorKindSpelling(kind))
	}

	return ''
}

fn C.clang_getCXTUResourceUsage(tu TranslationUnit) TUResourceUsage
pub fn get_cxtu_resource_usage(tu TranslationUnit) TUResourceUsage {
	return C.clang_getCXTUResourceUsage(tu)
}

fn C.clang_getCXXAccessSpecifier(arg0 Cursor) int
pub fn get_cxx_access_specifier(arg0 Cursor) int {
	return C.clang_getCXXAccessSpecifier(arg0)
}

fn C.clang_getCompletionAnnotation(completion_string CompletionString, annotation_number u32) String
pub fn get_completion_annotation(completion_string CompletionString, annotation_number u32) string {
	return cxstring_to_string(C.clang_getCompletionAnnotation(completion_string, annotation_number))
}

fn C.clang_getCompletionAvailability(completion_string CompletionString) int
pub fn get_completion_availability(completion_string CompletionString) int {
	return C.clang_getCompletionAvailability(completion_string)
}

fn C.clang_getCompletionFixIt(results &CodeCompleteResults, completion_index u32, fixit_index u32, replacement_range &SourceRange) String
pub fn get_completion_fix_it(results &CodeCompleteResults, completion_index u32, fixit_index u32, replacement_range &SourceRange) string {
	return cxstring_to_string(C.clang_getCompletionFixIt(results, completion_index, fixit_index, replacement_range))
}

fn C.clang_getCompletionNumAnnotations(completion_string CompletionString) u32
pub fn get_completion_num_annotations(completion_string CompletionString) u32 {
	return C.clang_getCompletionNumAnnotations(completion_string)
}

fn C.clang_getCompletionNumFixIts(results &CodeCompleteResults, completion_index u32) u32
pub fn get_completion_num_fix_its(results &CodeCompleteResults, completion_index u32) u32 {
	return C.clang_getCompletionNumFixIts(results, completion_index)
}

fn C.clang_getCompletionPriority(completion_string CompletionString) u32
pub fn get_completion_priority(completion_string CompletionString) u32 {
	return C.clang_getCompletionPriority(completion_string)
}

fn C.clang_getDiagnosticSetFromTU(unit TranslationUnit) DiagnosticSet
pub fn get_diagnostic_set_from_tu(unit TranslationUnit) DiagnosticSet {
	return C.clang_getDiagnosticSetFromTU(unit)
}

fn C.clang_getElementType(t Type) Type
pub fn get_element_type(t Type) Type {
	return C.clang_getElementType(t)
}

fn C.clang_getEnumConstantDeclUnsignedValue(c Cursor) u64
pub fn get_enum_constant_decl_unsigned_value(c Cursor) u64 {
	return C.clang_getEnumConstantDeclUnsignedValue(c)
}

fn C.clang_getEnumConstantDeclValue(c Cursor) i64
pub fn get_enum_constant_decl_value(c Cursor) i64 {
	return C.clang_getEnumConstantDeclValue(c)
}

fn C.clang_getEnumDeclIntegerType(c Cursor) Type
pub fn get_enum_decl_integer_type(c Cursor) Type {
	return C.clang_getEnumDeclIntegerType(c)
}

fn C.clang_getExceptionSpecificationType(t Type) int
pub fn get_exception_specification_type(t Type) int {
	return C.clang_getExceptionSpecificationType(t)
}

fn C.clang_getFieldDeclBitWidth(c Cursor) int
pub fn get_field_decl_bit_width(c Cursor) int {
	return C.clang_getFieldDeclBitWidth(c)
}

fn C.clang_getFullyQualifiedName(ct Type, policy PrintingPolicy, with_global_ns_prefix u32) String
pub fn get_fully_qualified_name(ct Type, policy PrintingPolicy, with_global_ns_prefix u32) string {
	if has_major(21) {
		return cxstring_to_string(C.clang_getFullyQualifiedName(ct, policy, with_global_ns_prefix))
	}

	return ''
}

fn C.clang_getFunctionTypeCallingConv(t Type) int
pub fn get_function_type_calling_conv(t Type) int {
	return C.clang_getFunctionTypeCallingConv(t)
}

fn C.clang_getIBOutletCollectionType(arg0 Cursor) Type
pub fn get_ib_outlet_collection_type(arg0 Cursor) Type {
	return C.clang_getIBOutletCollectionType(arg0)
}

fn C.clang_getNonReferenceType(ct Type) Type
pub fn get_non_reference_type(ct Type) Type {
	if has_major(16) {
		return C.clang_getNonReferenceType(ct)
	}

	return Type{}
}

fn C.clang_getNumElements(t Type) i64
pub fn get_num_elements(t Type) i64 {
	return C.clang_getNumElements(t)
}

fn C.clang_getOffsetOfBase(parent Cursor, base Cursor) i64
pub fn get_offset_of_base(parent Cursor, base Cursor) i64 {
	if has_major(20) {
		return C.clang_getOffsetOfBase(parent, base)
	}

	return 0
}

fn C.clang_getRemappings(arg0 &char) Remapping
pub fn get_remappings(arg0 &char) Remapping {
	return C.clang_getRemappings(arg0)
}

fn C.clang_getTUResourceUsageName(kind int) &char
pub fn get_tu_resource_usage_name(kind int) &char {
	return C.clang_getTUResourceUsageName(kind)
}

fn C.clang_getUnaryOperatorKindSpelling(kind int) String
pub fn get_unary_operator_kind_spelling(kind int) string {
	if has_major(17) {
		return cxstring_to_string(C.clang_getUnaryOperatorKindSpelling(kind))
	}

	return ''
}

fn C.clang_getUnqualifiedType(ct Type) Type
pub fn get_unqualified_type(ct Type) Type {
	if has_major(16) {
		return C.clang_getUnqualifiedType(ct)
	}

	return Type{}
}

fn C.clang_index_getCXXClassDeclInfo(info &IdxDeclInfo) IdxCXXClassDeclInfo
pub fn index_get_cxx_class_decl_info(info &IdxDeclInfo) IdxCXXClassDeclInfo {
	return C.clang_index_getCXXClassDeclInfo(info)
}

fn C.clang_index_getClientContainer(info &IdxContainerInfo) IdxClientContainer
pub fn index_get_client_container(info &IdxContainerInfo) IdxClientContainer {
	return C.clang_index_getClientContainer(info)
}

fn C.clang_index_getClientEntity(info &IdxEntityInfo) IdxClientEntity
pub fn index_get_client_entity(info &IdxEntityInfo) IdxClientEntity {
	return C.clang_index_getClientEntity(info)
}

fn C.clang_index_getIBOutletCollectionAttrInfo(attr &IdxAttrInfo) IdxIBOutletCollectionAttrInfo
pub fn index_get_ib_outlet_collection_attr_info(attr &IdxAttrInfo) IdxIBOutletCollectionAttrInfo {
	return C.clang_index_getIBOutletCollectionAttrInfo(attr)
}

fn C.clang_index_getObjCCategoryDeclInfo(info &IdxDeclInfo) IdxObjCCategoryDeclInfo
pub fn index_get_obj_c_category_decl_info(info &IdxDeclInfo) IdxObjCCategoryDeclInfo {
	return C.clang_index_getObjCCategoryDeclInfo(info)
}

fn C.clang_index_getObjCContainerDeclInfo(info &IdxDeclInfo) IdxObjCContainerDeclInfo
pub fn index_get_obj_c_container_decl_info(info &IdxDeclInfo) IdxObjCContainerDeclInfo {
	return C.clang_index_getObjCContainerDeclInfo(info)
}

fn C.clang_index_getObjCInterfaceDeclInfo(info &IdxDeclInfo) IdxObjCInterfaceDeclInfo
pub fn index_get_obj_c_interface_decl_info(info &IdxDeclInfo) IdxObjCInterfaceDeclInfo {
	return C.clang_index_getObjCInterfaceDeclInfo(info)
}

fn C.clang_index_getObjCPropertyDeclInfo(info &IdxDeclInfo) IdxObjCPropertyDeclInfo
pub fn index_get_obj_c_property_decl_info(info &IdxDeclInfo) IdxObjCPropertyDeclInfo {
	return C.clang_index_getObjCPropertyDeclInfo(info)
}

fn C.clang_index_getObjCProtocolRefListInfo(info &IdxDeclInfo) IdxObjCProtocolRefListInfo
pub fn index_get_obj_c_protocol_ref_list_info(info &IdxDeclInfo) IdxObjCProtocolRefListInfo {
	return C.clang_index_getObjCProtocolRefListInfo(info)
}

fn C.clang_index_isEntityObjCContainerKind(arg0 int) int
pub fn index_is_entity_obj_c_container_kind(arg0 int) int {
	return C.clang_index_isEntityObjCContainerKind(arg0)
}

fn C.clang_index_setClientContainer(info &IdxContainerInfo, data IdxClientContainer)
pub fn index_set_client_container(info &IdxContainerInfo, data IdxClientContainer) {
	C.clang_index_setClientContainer(info, data)
}

fn C.clang_index_setClientEntity(info &IdxEntityInfo, data IdxClientEntity)
pub fn index_set_client_entity(info &IdxEntityInfo, data IdxClientEntity) {
	C.clang_index_setClientEntity(info, data)
}

fn C.clang_isFunctionTypeVariadic(t Type) u32
pub fn is_function_type_variadic(t Type) u32 {
	return C.clang_isFunctionTypeVariadic(t)
}

fn C.clang_sortCodeCompletionResults(results &int, num_results u32)
pub fn sort_code_completion_results(results &int, num_results u32) {
	C.clang_sortCodeCompletionResults(results, num_results)
}

fn C.clang_visitCXXBaseClasses(t Type, visitor FieldVisitor, client_data ClientData) u32
pub fn visit_cxx_base_classes(t Type, visitor FieldVisitor, client_data ClientData) u32 {
	if has_major(20) {
		return C.clang_visitCXXBaseClasses(t, visitor, client_data)
	}

	return 0
}

fn C.clang_visitCXXMethods(t Type, visitor FieldVisitor, client_data ClientData) u32
pub fn visit_cxx_methods(t Type, visitor FieldVisitor, client_data ClientData) u32 {
	if has_major(21) {
		return C.clang_visitCXXMethods(t, visitor, client_data)
	}

	return 0
}
