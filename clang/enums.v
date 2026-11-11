module clang

// ═══ 生成器产出（确认后合入仓库）═══

pub enum BinaryOperatorKind {
	invalid = 0
	ptrmemd = 1
	ptrmemi = 2
	mul = 3
	div = 4
	rem = 5
	add = 6
	sub = 7
	shl = 8
	shr = 9
	cmp = 10
	lt = 11
	gt = 12
	le = 13
	ge = 14
	eq = 15
	ne = 16
	and = 17
	xor = 18
	or = 19
	land = 20
	lor = 21
	assign = 22
	mulassign = 23
	divassign = 24
	remassign = 25
	addassign = 26
	subassign = 27
	shlassign = 28
	shrassign = 29
	andassign = 30
	xorassign = 31
	orassign = 32
	comma = 33
	last = 34
}


pub enum CallingConv {
	default = 0
	c = 1
	x86stdcall = 2
	x86fastcall = 3
	x86thiscall = 4
	x86pascal = 5
	aapcs = 6
	aapcs_vfp = 7
	x86regcall = 8
	inteloclbicc = 9
	win64 = 10
	x86_64win64 = 11
	x86vectorcall = 12
	swift = 13
	preservemost = 14
	preserveall = 15
	aarch64vectorcall = 16
	swiftasync = 17
	aarch64svepcs = 18
	m68krtd = 19
	preservenone = 20
	riscvvectorcall = 21
	riscvvlscall_32 = 22
	riscvvlscall_64 = 23
	riscvvlscall_128 = 24
	riscvvlscall_256 = 25
	riscvvlscall_512 = 26
	riscvvlscall_1024 = 27
	riscvvlscall_2048 = 28
	riscvvlscall_4096 = 29
	riscvvlscall_8192 = 30
	riscvvlscall_16384 = 31
	riscvvlscall_32768 = 32
	riscvvlscall_65536 = 33
	invalid = 100
	unexposed = 200
}


pub enum CommentInlineCommandRenderKind {
	normal = 0
	bold = 1
	monospaced = 2
	emphasized = 3
	anchor = 4
}


pub enum CommentKind {
	null = 0
	text = 1
	inlinecommand = 2
	htmlstarttag = 3
	htmlendtag = 4
	paragraph = 5
	blockcommand = 6
	paramcommand = 7
	tparamcommand = 8
	verbatimblockcommand = 9
	verbatimblockline = 10
	verbatimline = 11
	fullcomment = 12
}


pub enum CommentParamPassDirection {
	in = 0
	out = 1
	inout = 2
}


pub enum LoadDiag_Error {
	none = 0
	unknown = 1
	cannotload = 2
	invalidfile = 3
}


pub enum PrintingPolicyProperty {
	indentation = 0
	suppressspecifiers = 1
	suppresstagkeyword = 2
	includetagdefinition = 3
	suppressscope = 4
	suppressunwrittenscope = 5
	suppressinitializers = 6
	constantarraysizeaswritten = 7
	anonymoustaglocations = 8
	suppressstronglifetime = 9
	suppresslifetimequalifiers = 10
	suppresstemplateargsincxxconstructors = 11
	bool = 12
	restrict = 13
	alignof = 14
	underscorealignof = 15
	usevoidforzeroparams = 16
	terseoutput = 17
	polishfordeclaration = 18
	half = 19
	mswchar = 20
	includenewlines = 21
	msvcformatting = 22
	constantsaswritten = 23
	suppressimplicitbase = 24
	fullyqualifiedname = 25
	lastproperty = 26
}


pub enum TUResourceUsageKind {
	ast = 1
	identifiers = 2
	selectors = 3
	globalcompletionresults = 4
	sourcemanagercontentcache = 5
	ast_sidetables = 6
	sourcemanager_membuffer_malloc = 7
	sourcemanager_membuffer_mmap = 8
	externalastsource_membuffer_malloc = 9
	externalastsource_membuffer_mmap = 10
	preprocessor = 11
	preprocessingrecord = 12
	sourcemanager_datastructures = 13
	preprocessor_headersearch = 14
	memory_in_bytes_begin = 15
	memory_in_bytes_end = 16
	first = 17
	last = 18
}


pub enum TemplateArgumentKind {
	null = 0
	type = 1
	declaration = 2
	nullptr = 3
	integral = 4
	template = 5
	templateexpansion = 6
	expression = 7
	pack = 8
	invalid = 9
}


pub enum UnaryOperatorKind {
	invalid = 0
	postinc = 1
	postdec = 2
	preinc = 3
	predec = 4
	addrof = 5
	deref = 6
	plus = 7
	minus = 8
	not = 9
	lnot = 10
	real = 11
	imag = 12
	extension = 13
	coawait = 14
	last = 15
}

