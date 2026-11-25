#ifndef RSCABI_ABI_TYPE_HPP
#define RSCABI_ABI_TYPE_HPP

#include <map>
#include <set>
#include <vector>

#include "../core/core.hpp"

namespace rscabi {

enum class TypeKind
{
    Never,
    Unit,
    Bool,
    Char,
    Int,
    Float,
    FnPointer,
    Pointer,
    Reference,
    Box,
    NonNull,
    NonZero,
    Transparent,
    Array,
    Slice,
    Tuple,
    Struct,
    Union,
    Enum,
    Simd,
    Coroutine,
};

struct AbiType;
class TyAbiInterface;

struct EnumVariant
{
    std::vector<const AbiType *> fields;
    U128 discriminant;
    uint32_t flags;

    EnumVariant() : discriminant(), flags(0) {}
};

// A coroutine state mirrors one rustc coroutine variant. `fields` are the
// locals live in that state; storage conflicts are derived from locals that
// occur in more than one state (those get promoted into the prefix).
struct CoroutineState
{
    std::vector<const AbiType *> fields;
    U128 discriminant;

    CoroutineState() : discriminant() {}
};

struct AbiType
{
    TypeKind kind;
    Scalar scalar;
    ReprOptions repr;
    const AbiType *inner;
    std::vector<const AbiType *> fields;
    std::vector<EnumVariant> variants;
    std::vector<CoroutineState> coroutine_states;
    uint64_t array_count;
    bool is_fat_pointer;
    bool is_mutable;
    bool finished;
    AddressSpace address_space;
    PointerSpec pointer_spec;
    uint32_t scalable_count;
    uint64_t randomization_seed;

    AbiType()
        : kind(TypeKind::Unit),
          scalar(),
          repr(),
          inner(NULL),
          array_count(0),
          is_fat_pointer(false),
          is_mutable(false),
          finished(false),
          address_space(),
          pointer_spec(),
          scalable_count(0),
          randomization_seed(0) {}
};

class TypeContext
{
public:
    explicit TypeContext(const TargetDataLayout &target);
    ~TypeContext();

    AbiType *create(TypeKind kind);
    bool layout_of(const AbiType *type, LayoutData *out);
    const LayoutCalculator &calculator() const { return calculator_; }
    const TargetDataLayout &data_layout() const { return *calculator_.data_layout(); }
    void invalidate_cache();

private:
    std::vector<AbiType *> owned_;
    std::map<const AbiType *, LayoutData> cache_;
    std::set<const AbiType *> visiting_;
    LayoutCalculator calculator_;

    bool compute_layout(const AbiType *type, LayoutData *out);
    bool layout_children(const AbiType *type, std::vector<LayoutData> *out);
    bool layout_enum_variants(const AbiType *type,
                              std::vector<std::vector<LayoutData> > *out,
                              std::vector<U128> *discriminants);
    bool layout_coroutine_states(const AbiType *type,
                                 std::vector<LayoutData> *locals,
                                 std::vector<std::vector<uint32_t> > *variant_locals,
                                 std::vector<std::vector<bool> > *storage_conflicts);
};

} // namespace rscabi

#endif
