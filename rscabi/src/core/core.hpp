#ifndef RSCABI_CORE_HPP
#define RSCABI_CORE_HPP

#include <stdint.h>

#include <map>
#include <string>
#include <vector>

namespace rscabi {

template <typename Tag>
struct Idx
{
    uint32_t index;

    Idx() : index(0) {}
    explicit Idx(uint32_t i) : index(i) {}

    bool operator==(const Idx &other) const { return index == other.index; }
    bool operator<(const Idx &other) const { return index < other.index; }
};

struct FieldIdxTag {};
struct VariantIdxTag {};

typedef Idx<FieldIdxTag> FieldIdx;
typedef Idx<VariantIdxTag> VariantIdx;

struct AddressSpace
{
    uint32_t index;

    AddressSpace() : index(0) {}
    explicit AddressSpace(uint32_t i) : index(i) {}

    static AddressSpace zero() { return AddressSpace(0); }
    bool operator==(const AddressSpace &other) const { return index == other.index; }
};

enum class IntegerClass { I8, I16, I32, I64, I128 };
enum class FloatClass { F16, F16B, F32, F64, F128 };

struct Numeric
{
    enum class Kind { Int, Float } kind;
    IntegerClass integer;
    FloatClass float_type;
    bool is_signed;

    Numeric()
        : kind(Kind::Int),
          integer(IntegerClass::I8),
          float_type(FloatClass::F32),
          is_signed(false) {}

    static Numeric from_integer(IntegerClass i, bool signedness);
    static Numeric from_float(FloatClass f);
    uint32_t bits() const;
};

struct PrimitiveSpec
{
    enum class Kind { Int, Float, Pointer } kind;
    Numeric numeric;
    AddressSpace space;

    PrimitiveSpec() : kind(Kind::Int), numeric(), space() {}
};

struct Align;
struct Size;

struct Size
{
    uint64_t bytes;

    Size() : bytes(0) {}
    explicit Size(uint64_t b) : bytes(b) {}

    static Size from_bits(uint64_t bits);
    static Size from_bytes(uint64_t bytes);

    uint64_t bits() const;
    Size align_to(const Align &align) const;
    bool checked_add(const Size &other, Size *out) const;
    bool checked_mul(uint64_t count, Size *out) const;
};

struct Align
{
    uint8_t pow2;

    Align() : pow2(0) {}
    explicit Align(uint8_t p) : pow2(p) {}

    static Align one();
    static bool from_bytes(uint64_t bytes, Align *out);
    static Align max_for_target(uint64_t pointer_bits);
    static Align max_aligned_factor(uint64_t size);

    uint64_t bytes() const;
    uint64_t bits() const;
    Size align_size(const Size &size) const;
};

struct PointerSpec
{
    Size size;
    Align align;
    Size offset;
    bool fat;
    AddressSpace space;

    PointerSpec() : size(), align(), offset(), fat(false), space() {}
    PointerSpec(Size s, Align a, Size o, bool f, AddressSpace sp)
        : size(s), align(a), offset(o), fat(f), space(sp) {}
};

struct AbiAlign
{
    Align abi;
    Align pref;
};

struct U128
{
    uint64_t lo;
    uint64_t hi;

    U128() : lo(0), hi(0) {}
    U128(uint64_t l, uint64_t h) : lo(l), hi(h) {}

    static U128 from_u64(uint64_t value);
    static U128 from_u32(uint32_t value);

    bool is_zero() const;
    bool is_one() const;
};

bool operator==(const U128 &a, const U128 &b);
bool operator!=(const U128 &a, const U128 &b);
bool operator<(const U128 &a, const U128 &b);
bool operator<=(const U128 &a, const U128 &b);
bool operator>(const U128 &a, const U128 &b);
bool operator>=(const U128 &a, const U128 &b);

U128 u128_add(const U128 &a, const U128 &b);
U128 u128_sub(const U128 &a, const U128 &b);
U128 u128_and(const U128 &a, const U128 &b);
U128 u128_or(const U128 &a, const U128 &b);
U128 u128_not(const U128 &a);
U128 u128_shl(const U128 &a, uint32_t bits);
U128 u128_shr(const U128 &a, uint32_t bits);
U128 u128_truncate(const U128 &a, uint32_t bits);
U128 u128_unsigned_max(uint32_t bits);
uint32_t u128_bit_length(const U128 &a);
U128 u128_from_c(uint64_t lo, uint64_t hi);

struct WrappingRange
{
    U128 start;
    U128 end;

    WrappingRange() : start(), end() {}
    WrappingRange(const U128 &s, const U128 &e) : start(s), end(e) {}

    static WrappingRange full(uint32_t bits);
    static WrappingRange from_bounds(uint64_t start, uint64_t end);
    static WrappingRange with_start(const WrappingRange &range, const U128 &start);
    static WrappingRange with_end(const WrappingRange &range, const U128 &end);

    bool is_full(uint32_t bits) const;
    bool is_empty_marker() const;
    bool contains(const U128 &value) const;
    U128 count(uint32_t bits) const;
    uint32_t available_log2(uint32_t bits) const;
};

WrappingRange valid_complement_niche(const WrappingRange &valid, uint32_t bits);
WrappingRange smallest_range_containing(const std::vector<U128> &values, uint32_t bits);
uint32_t range_bits(const WrappingRange &range);

enum class PrimitiveKind
{
    Bool,
    Char,
    Int,
    Float,
    Pointer,
    FnPointer,
};

enum class BackendReprKind
{
    Memory,
    Scalar,
    ScalarPair,
    SimdVector,
    SimdScalableVector,
};

enum class FieldsShapeKind
{
    Primitive,
    Arbitrary,
    Array,
    Union,
};

enum class VariantsKind
{
    Empty,
    Single,
    Multiple,
};

enum class TagEncodingKind
{
    None,
    Direct,
    Niche,
};

enum class NicheBias
{
    Start,
    End,
};

enum class StructKind
{
    AlwaysSized,
    MaybeUnsized,
    Prefixed,
};

struct StructKindSpec
{
    StructKind kind;
    uint64_t prefix_size;
    uint64_t prefix_align;

    StructKindSpec()
        : kind(StructKind::AlwaysSized), prefix_size(0), prefix_align(1) {}

    static StructKindSpec always();
    static StructKindSpec maybe_unsized();
    static StructKindSpec prefixed(uint64_t size, uint64_t align);
};

struct Scalar
{
    PrimitiveKind primitive;
    uint32_t bits;
    bool is_signed;
    WrappingRange valid;

    Scalar()
        : primitive(PrimitiveKind::Int), bits(8), is_signed(false), valid(WrappingRange::full(8)) {}
};

// `value` is the *invalid* value range (the complement of the scalar's valid
// range), matching rustc's `Niche::available()` perspective. `bits` records the
// scalar width used by `available()` and `reserve()`.
struct Niche
{
    uint64_t offset;
    WrappingRange value;
    uint32_t bits;

    Niche() : offset(0), value(), bits(0) {}
    Niche(uint64_t off, const WrappingRange &v, uint32_t b)
        : offset(off), value(v), bits(b) {}

    U128 available() const;
    uint64_t value_size_bytes() const;

    // Rustc `Niche::reserve`: reserves `count` invalid values for discriminants
    // and returns `niche_start` plus the scalar valid range after reservation.
    bool reserve(const U128 &count, U128 *niche_start, WrappingRange *new_valid) const;

    static bool from_scalar(uint64_t offset, const Scalar &scalar, Niche *out);
};

struct ReprOptions
{
    bool is_c;
    bool is_transparent;
    bool is_packed;
    bool is_simd;
    bool is_scalable;
    uint32_t align_bits;
    uint32_t pack_bits;
    uint32_t int_bits;

    ReprOptions()
        : is_c(false),
          is_transparent(false),
          is_packed(false),
          is_simd(false),
          is_scalable(false),
          align_bits(0),
          pack_bits(0),
          int_bits(0) {}

    bool inhibit_enum_layout_opt() const;
    bool inhibit_field_reorder() const;
};

struct VariantLayout
{
    uint64_t size;
    uint64_t align;
    uint64_t unadjusted_abi_align;
    BackendReprKind backend;
    std::vector<uint64_t> field_offsets;
    std::vector<uint64_t> field_sizes;
    std::vector<uint32_t> in_memory_order;
    bool has_niche;
    Niche largest_niche;
    bool has_tag_range;
    WrappingRange tag_range;
    bool uninhabited;

    VariantLayout()
        : size(0),
          align(1),
          unadjusted_abi_align(1),
          backend(BackendReprKind::Memory),
          has_niche(false),
          largest_niche(),
          has_tag_range(false),
          tag_range(),
          uninhabited(false) {}
};

struct LayoutData
{
    uint64_t size;
    uint64_t align;
    uint64_t unadjusted_abi_align;
    uint64_t max_repr_align;
    bool uninhabited;
    BackendReprKind backend;
    FieldsShapeKind fields_kind;
    std::vector<uint64_t> field_offsets;
    std::vector<uint64_t> field_sizes;
    std::vector<uint32_t> in_memory_order;
    bool has_niche;
    Niche largest_niche;
    VariantsKind variants_kind;
    uint64_t single_variant;
    TagEncodingKind tag_encoding;
    uint64_t untagged_variant;
    uint64_t niche_variants_start;
    uint64_t niche_variants_end;
    U128 niche_start;
    uint32_t tag_bits;
    bool has_tag_scalar;
    Scalar tag_scalar;
    AddressSpace address_space;
    uint32_t backend_lane_count;
    uint8_t number_of_vectors;
    uint64_t randomization_seed;
    std::vector<VariantLayout> variants;

    LayoutData()
        : size(0),
          align(1),
          unadjusted_abi_align(1),
          max_repr_align(1),
          uninhabited(false),
          backend(BackendReprKind::Memory),
          fields_kind(FieldsShapeKind::Arbitrary),
          has_niche(false),
          largest_niche(),
          variants_kind(VariantsKind::Single),
          single_variant(0),
          tag_encoding(TagEncodingKind::None),
          untagged_variant(0),
          niche_variants_start(0),
          niche_variants_end(0),
          niche_start(),
          tag_bits(0),
          has_tag_scalar(false),
          tag_scalar(),
          address_space(0),
          backend_lane_count(0),
          number_of_vectors(1),
          randomization_seed(0) {}
};

struct TargetDataLayout
{
    bool little_endian;
    uint32_t pointer_bits;
    uint32_t pointer_align_bits;
    uint32_t usize_bits;
    uint32_t i16_align_bits;
    uint32_t i32_align_bits;
    uint32_t i64_align_bits;
    uint32_t i128_align_bits;
    uint32_t aggregate_align_bits;
    uint32_t c_enum_min_bits;
    std::map<uint64_t, uint64_t> vector_align_bits;
    std::map<uint32_t, PointerSpec> address_spaces;
    std::map<uint32_t, uint64_t> f16_align_bits;
    std::map<uint32_t, uint64_t> f128_align_bits;

    TargetDataLayout()
        : little_endian(true),
          pointer_bits(64),
          pointer_align_bits(64),
          usize_bits(64),
          i16_align_bits(16),
          i32_align_bits(32),
          i64_align_bits(64),
          i128_align_bits(128),
          aggregate_align_bits(8),
          c_enum_min_bits(32) {}

    Align integer_align(uint32_t bits) const;
    Align pointer_align() const;
    uint64_t rust_vector_align_bytes(uint64_t size) const;
};

bool parse_llvm_data_layout(const std::string &input, TargetDataLayout *out);

class HasDataLayout
{
public:
    virtual ~HasDataLayout() {}
    virtual const TargetDataLayout *data_layout() const = 0;
};

class LayoutCalculator : public HasDataLayout
{
public:
    explicit LayoutCalculator(const TargetDataLayout &target);

    virtual const TargetDataLayout *data_layout() const;

    bool layout_scalar(const Scalar &scalar, LayoutData *out) const;
    bool layout_never(LayoutData *out) const;
    bool layout_unit(LayoutData *out) const;
    bool layout_array(const LayoutData &element, uint64_t count, LayoutData *out) const;
    bool layout_univariant(const std::vector<LayoutData> &fields,
                           const ReprOptions &repr,
                           LayoutData *out) const;
    bool layout_union(const std::vector<LayoutData> &fields,
                      const ReprOptions &repr,
                      LayoutData *out) const;
    bool layout_enum(const std::vector<std::vector<LayoutData> > &variants,
                     const std::vector<U128> &discriminants,
                     const ReprOptions &repr,
                     LayoutData *out) const;
    bool layout_simd(const LayoutData &element,
                     uint64_t lanes,
                     bool packed,
                     LayoutData *out) const;
    bool layout_coroutine(const std::vector<LayoutData> &local_layouts,
                          const std::vector<LayoutData> &prefix_layouts,
                          const std::vector<std::vector<uint32_t> > &variant_locals,
                          const std::vector<std::vector<bool> > &storage_conflicts,
                          LayoutData *out) const;

private:
    TargetDataLayout target_;

    bool univariant(const std::vector<LayoutData> &fields,
                    const ReprOptions &repr,
                    const StructKindSpec &kind,
                    LayoutData *out) const;
    bool univariant_biased(const std::vector<LayoutData> &fields,
                           const ReprOptions &repr,
                           const StructKindSpec &kind,
                           NicheBias bias,
                           LayoutData *out) const;
    bool layout_tagged_enum(const std::vector<std::vector<LayoutData> > &variants,
                            const std::vector<U128> &discriminants,
                            const ReprOptions &repr,
                            LayoutData *out) const;
    bool layout_niche_enum(const std::vector<std::vector<LayoutData> > &variants,
                           const std::vector<U128> &discriminants,
                           const ReprOptions &repr,
                           LayoutData *out) const;
    uint32_t integer_for_align(uint64_t align_bytes) const;
    uint32_t discriminant_bits(const std::vector<U128> &discriminants,
                               const ReprOptions &repr) const;
};

} // namespace rscabi

#endif
