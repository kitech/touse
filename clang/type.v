module clang

fn C.clang_getCursorType(cursor Cursor) Type
pub fn get_cursor_type(cursor Cursor) Type {
	return C.clang_getCursorType(cursor)
}

fn C.clang_getTypeSpelling(t Type) String
pub fn get_type_spelling(t Type) string {
	return cxstring_to_string(C.clang_getTypeSpelling(t))
}

fn C.clang_getTypeKindSpelling(kind TypeKind) String
pub fn get_type_kind_spelling(kind TypeKind) string {
	return cxstring_to_string(C.clang_getTypeKindSpelling(kind))
}

fn C.clang_getPointeeType(t Type) Type
pub fn get_pointee_type(t Type) Type {
	return C.clang_getPointeeType(t)
}

fn C.clang_getCanonicalType(t Type) Type
pub fn get_canonical_type(t Type) Type {
	return C.clang_getCanonicalType(t)
}

fn C.clang_getResultType(t Type) Type
pub fn get_result_type(t Type) Type {
	return C.clang_getResultType(t)
}

fn C.clang_getNumArgTypes(t Type) int
pub fn get_num_arg_types(t Type) int {
	return C.clang_getNumArgTypes(t)
}

fn C.clang_getArgType(t Type, index u32) Type
pub fn get_arg_type(t Type, index u32) Type {
	return C.clang_getArgType(t, index)
}

fn C.clang_isConstQualifiedType(t Type) u32
pub fn is_const_qualified_type(t Type) bool {
	return C.clang_isConstQualifiedType(t) != 0
}

fn C.clang_isVolatileQualifiedType(t Type) u32
pub fn is_volatile_qualified_type(t Type) bool {
	return C.clang_isVolatileQualifiedType(t) != 0
}

fn C.clang_isRestrictQualifiedType(t Type) u32
pub fn is_restrict_qualified_type(t Type) bool {
	return C.clang_isRestrictQualifiedType(t) != 0
}

fn C.clang_Type_getAlignOf(t Type) i64
pub fn type_get_align_of(t Type) i64 {
	return C.clang_Type_getAlignOf(t)
}

fn C.clang_Type_getSizeOf(t Type) i64
pub fn type_get_size_of(t Type) i64 {
	return C.clang_Type_getSizeOf(t)
}

fn C.clang_Type_getOffsetOf(t Type, field_name &char) i64
pub fn type_get_offset_of(t Type, field_name string) i64 {
	return C.clang_Type_getOffsetOf(t, unsafe { field_name.str })
}

fn C.clang_Cursor_getOffsetOfField(cursor Cursor) i64
pub fn cursor_get_offset_of_field(cursor Cursor) i64 {
	return C.clang_Cursor_getOffsetOfField(cursor)
}

fn C.clang_Type_getClassType(t Type) Type
pub fn type_get_class_type(t Type) Type {
	return C.clang_Type_getClassType(t)
}

fn C.clang_Type_getModifiedType(t Type) Type
pub fn type_get_modified_type(t Type) Type {
	return C.clang_Type_getModifiedType(t)
}

fn C.clang_Type_getValueType(t Type) Type
pub fn type_get_value_type(t Type) Type {
	return C.clang_Type_getValueType(t)
}

fn C.clang_Type_getNamedType(t Type) Type
pub fn type_get_named_type(t Type) Type {
	return C.clang_Type_getNamedType(t)
}

fn C.clang_getTypedefName(t Type) String
pub fn type_get_typedef_name(t Type) string {
	return cxstring_to_string(C.clang_getTypedefName(t))
}

fn C.clang_Type_getCXXRefQualifier(t Type) RefQualifierKind
pub fn type_get_ref_qualifier(t Type) RefQualifierKind {
	return C.clang_Type_getCXXRefQualifier(t)
}

fn C.clang_Type_getNumTemplateArguments(t Type) int
pub fn type_get_num_template_arguments(t Type) int {
	return C.clang_Type_getNumTemplateArguments(t)
}

fn C.clang_Type_getTemplateArgumentAsType(t Type, i u32) Type
pub fn type_get_template_argument_as_type(t Type, i u32) Type {
	return C.clang_Type_getTemplateArgumentAsType(t, i)
}

fn C.clang_Type_getNumObjCProtocolRefs(t Type) u32
pub fn type_get_num_objc_protocol_refs(t Type) u32 {
	return C.clang_Type_getNumObjCProtocolRefs(t)
}

fn C.clang_Type_getObjCProtocolDecl(t Type, i u32) Cursor
pub fn type_get_objc_protocol_decl(t Type, i u32) Cursor {
	return C.clang_Type_getObjCProtocolDecl(t, i)
}

fn C.clang_Type_getNumObjCTypeArgs(t Type) u32
pub fn type_get_num_objc_type_args(t Type) u32 {
	return C.clang_Type_getNumObjCTypeArgs(t)
}

fn C.clang_Type_getObjCTypeArg(t Type, i u32) Type
pub fn type_get_objc_type_arg(t Type, i u32) Type {
	return C.clang_Type_getObjCTypeArg(t, i)
}

fn C.clang_Type_getObjCObjectBaseType(t Type) Type
pub fn type_get_objc_object_base_type(t Type) Type {
	return C.clang_Type_getObjCObjectBaseType(t)
}


// clang/type.v 追加

// 类型相等性判断（基础但必备）
fn C.clang_equalTypes(a Type, b Type) u32
pub fn equal_types(a Type, b Type) bool {
	return C.clang_equalTypes(a, b) != 0
}

// POD 类型判断
fn C.clang_isPODType(t Type) u32
pub fn is_pod_type(t Type) bool {
	return C.clang_isPODType(t) != 0
}

// 虚基类判断
fn C.clang_isVirtualBase(cursor Cursor) u32
pub fn is_virtual_base(cursor Cursor) bool {
	return C.clang_isVirtualBase(cursor) != 0
}

// ObjC 声明类型编码
fn C.clang_getDeclObjCTypeEncoding(cursor Cursor) String
pub fn get_decl_objc_type_encoding(cursor Cursor) string {
	return cxstring_to_string(C.clang_getDeclObjCTypeEncoding(cursor))
}

// 原子类型判断（C11 / ObjC）
fn C.clang_Type_getObjCTypeArg(t Type, i u32) Type // 已有
fn C.clang_Type_getNullability(t Type) u32
pub fn type_get_nullability(t Type) u32 {
	return C.clang_Type_getNullability(t)
}

// 模板参数数量（已有 type_get_num_template_arguments）
// 类型修饰符深度判断
fn C.clang_isRestrictQualifiedType(t Type) u32 // 已有
fn C.clang_isVolatileQualifiedType(t Type) u32 // 已有

// 函数类型是否为变参（已有 is_function_type_variadic）
// 调用约定（已有 get_function_type_calling_conv）

// 地址空间（已有 get_address_space）

fn C.clang_Type_getObjCEncoding(type_ Type) String
pub fn type_get_obj_c_encoding(type_ Type) string {
	return cxstring_to_string(C.clang_Type_getObjCEncoding(type_))
}

fn C.clang_Type_isTransparentTagTypedef(t Type) u32
pub fn type_is_transparent_tag_typedef(t Type) u32 {
	return C.clang_Type_isTransparentTagTypedef(t)
}

fn C.clang_Type_visitFields(t Type, visitor FieldVisitor, client_data ClientData) u32
pub fn type_visit_fields(t Type, visitor FieldVisitor, client_data ClientData) u32 {
	return C.clang_Type_visitFields(t, visitor, client_data)
}

fn C.clang_getTypeDeclaration(t Type) Cursor
pub fn get_type_declaration(t Type) Cursor {
	return C.clang_getTypeDeclaration(t)
}

fn C.clang_getTypePrettyPrinted(ct Type, cxPolicy_ PrintingPolicy) String
pub fn get_type_pretty_printed(ct Type, cxPolicy_ PrintingPolicy) string {
	if has_major(20) {
		return cxstring_to_string(C.clang_getTypePrettyPrinted(ct, cxPolicy_))
	}

	return ''
}

fn C.clang_getTypedefDeclUnderlyingType(c Cursor) Type
pub fn get_typedef_decl_underlying_type(c Cursor) Type {
	return C.clang_getTypedefDeclUnderlyingType(c)
}
