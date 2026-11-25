#include "abi_type.hpp"

namespace rscabi {

namespace {

bool scalar_of(const AbiType *type, Scalar *out)
{
    if (type == NULL || out == NULL)
    {
        return false;
    }
    switch (type->kind)
    {
        case TypeKind::Bool:
        case TypeKind::Char:
        case TypeKind::Int:
        case TypeKind::Float:
        case TypeKind::FnPointer:
        case TypeKind::Pointer:
        case TypeKind::Reference:
        case TypeKind::Box:
        case TypeKind::NonNull:
            *out = type->scalar;
            if (out->primitive == PrimitiveKind::FnPointer && out->valid.is_full(out->bits))
            {
                out->valid = WrappingRange(U128::from_u64(1), u128_unsigned_max(out->bits));
            }
            return true;
        case TypeKind::NonZero:
        {
            Scalar inner;
            if (!scalar_of(type->inner, &inner))
            {
                return false;
            }
            uint32_t bits = inner.bits;
            if (inner.valid.is_full(bits))
            {
                inner.valid = WrappingRange(U128::from_u64(1), u128_unsigned_max(bits));
            }
            else if (inner.valid.start <= inner.valid.end && inner.valid.start.is_zero())
            {
                inner.valid.start = U128::from_u64(1);
            }
            *out = inner;
            return true;
        }
        default:
            return false;
    }
}

} // namespace

TypeContext::TypeContext(const TargetDataLayout &target)
    : calculator_(target)
{
}

TypeContext::~TypeContext()
{
    for (size_t i = 0; i < owned_.size(); i++)
    {
        delete owned_[i];
    }
    owned_.clear();
}

AbiType *TypeContext::create(TypeKind kind)
{
    AbiType *type = new AbiType();
    type->kind = kind;
    switch (kind)
    {
        case TypeKind::Bool:
            type->scalar.primitive = PrimitiveKind::Bool;
            type->scalar.bits = 8;
            type->scalar.valid = WrappingRange(U128::from_u64(0), U128::from_u64(1));
            break;
        case TypeKind::Char:
            type->scalar.primitive = PrimitiveKind::Char;
            type->scalar.bits = 32;
            // Valid: 0..=0xD7FF and 0xE000..=0x10FFFF, encoded as a wrapping range.
            type->scalar.valid = WrappingRange(U128::from_u64(0xe000),
                                               U128::from_u64(0xd7ff));
            break;
        case TypeKind::Pointer:
        case TypeKind::FnPointer:
            type->scalar.primitive = kind == TypeKind::FnPointer
                                         ? PrimitiveKind::FnPointer
                                         : PrimitiveKind::Pointer;
            type->scalar.bits = 64;
            type->scalar.valid = WrappingRange::full(64);
            break;
        case TypeKind::Reference:
        case TypeKind::Box:
        case TypeKind::NonNull:
            type->scalar.primitive = PrimitiveKind::Pointer;
            type->scalar.bits = 64;
            type->scalar.valid = WrappingRange(U128::from_u64(1), u128_unsigned_max(64));
            break;
        default:
            break;
    }
    owned_.push_back(type);
    return type;
}

bool TypeContext::layout_of(const AbiType *type, LayoutData *out)
{
    if (type == NULL || out == NULL)
    {
        return false;
    }
    std::map<const AbiType *, LayoutData>::const_iterator it = cache_.find(type);
    if (it != cache_.end())
    {
        *out = it->second;
        return true;
    }
    if (visiting_.find(type) != visiting_.end())
    {
        return false;
    }

    visiting_.insert(type);
    LayoutData layout;
    bool ok = compute_layout(type, &layout);
    visiting_.erase(type);
    if (!ok)
    {
        return false;
    }
    cache_[type] = layout;
    *out = layout;
    return true;
}

void TypeContext::invalidate_cache()
{
    cache_.clear();
}

bool TypeContext::layout_children(const AbiType *type, std::vector<LayoutData> *out)
{
    if (type == NULL || out == NULL)
    {
        return false;
    }
    out->clear();
    for (size_t i = 0; i < type->fields.size(); i++)
    {
        LayoutData field;
        if (!layout_of(type->fields[i], &field))
        {
            return false;
        }
        out->push_back(field);
    }
    return true;
}

bool TypeContext::layout_enum_variants(const AbiType *type,
                                       std::vector<std::vector<LayoutData> > *out,
                                       std::vector<U128> *discriminants)
{
    if (type == NULL || out == NULL || discriminants == NULL)
    {
        return false;
    }
    out->clear();
    discriminants->clear();
    for (size_t v = 0; v < type->variants.size(); v++)
    {
        const EnumVariant &variant = type->variants[v];
        std::vector<LayoutData> fields;
        for (size_t f = 0; f < variant.fields.size(); f++)
        {
            LayoutData field;
            if (!layout_of(variant.fields[f], &field))
            {
                return false;
            }
            fields.push_back(field);
        }
        out->push_back(fields);
        discriminants->push_back(variant.discriminant);
    }
    return true;
}

bool TypeContext::layout_coroutine_states(const AbiType *type,
                                          std::vector<LayoutData> *locals,
                                          std::vector<std::vector<uint32_t> > *variant_locals,
                                          std::vector<std::vector<bool> > *storage_conflicts)
{
    if (type == NULL || locals == NULL || variant_locals == NULL || storage_conflicts == NULL)
    {
        return false;
    }
    locals->clear();
    variant_locals->clear();
    storage_conflicts->clear();

    std::map<const AbiType *, uint32_t> local_index;
    for (size_t v = 0; v < type->coroutine_states.size(); v++)
    {
        std::vector<uint32_t> indices;
        const CoroutineState &state = type->coroutine_states[v];
        for (size_t f = 0; f < state.fields.size(); f++)
        {
            const AbiType *field = state.fields[f];
            std::map<const AbiType *, uint32_t>::const_iterator it = local_index.find(field);
            uint32_t index = 0;
            if (it == local_index.end())
            {
                index = static_cast<uint32_t>(locals->size());
                local_index[field] = index;
                LayoutData layout;
                if (!layout_of(field, &layout))
                {
                    return false;
                }
                locals->push_back(layout);
            }
            else
            {
                index = it->second;
            }
            indices.push_back(index);
        }
        variant_locals->push_back(indices);
    }

    // Storage liveness is approximated conservatively: a local that occurs in
    // more than one state is promoted to the prefix by layout_coroutine().
    // No pairwise conflicts are needed for the single-state locals.
    storage_conflicts->assign(locals->size(), std::vector<bool>(locals->size(), false));
    return true;
}

bool TypeContext::compute_layout(const AbiType *type, LayoutData *out)
{
    if (type == NULL || out == NULL)
    {
        return false;
    }
    switch (type->kind)
    {
        case TypeKind::Never:
            return calculator_.layout_never(out);
        case TypeKind::Unit:
            return calculator_.layout_unit(out);
        case TypeKind::Bool:
        case TypeKind::Char:
        case TypeKind::Int:
        case TypeKind::Float:
        case TypeKind::FnPointer:
        case TypeKind::Pointer:
        case TypeKind::Reference:
        case TypeKind::Box:
        case TypeKind::NonNull:
        {
            if ((type->kind == TypeKind::Pointer || type->kind == TypeKind::Reference ||
                 type->kind == TypeKind::Box) && type->is_fat_pointer)
            {
                uint32_t pointer_bits = type->scalar.bits == 0 ? 64 : type->scalar.bits;
                uint64_t pointer_bytes = Size::from_bits(pointer_bits).bytes;
                Align pointer_align;
                if (!Align::from_bytes(pointer_bytes, &pointer_align))
                {
                    return false;
                }
                WrappingRange niche = valid_complement_niche(type->scalar.valid, pointer_bits);
                *out = LayoutData();
                out->size = pointer_bytes * 2;
                out->align = pointer_align.bytes();
                out->unadjusted_abi_align = pointer_align.bytes();
                out->backend = BackendReprKind::ScalarPair;
                out->fields_kind = FieldsShapeKind::Arbitrary;
                out->field_offsets.push_back(0);
                out->field_offsets.push_back(pointer_bytes);
                out->field_sizes.push_back(pointer_bytes);
                out->field_sizes.push_back(pointer_bytes);
                out->variants_kind = VariantsKind::Single;
                if (!niche.is_empty_marker() && !niche.is_full(pointer_bits))
                {
                    out->has_niche = true;
                    out->largest_niche = Niche(0, niche, pointer_bits);
                }
                return true;
            }
            Scalar scalar;
            if (!scalar_of(type, &scalar))
            {
                return false;
            }
            return calculator_.layout_scalar(scalar, out);
        }
        case TypeKind::NonZero:
        {
            Scalar scalar;
            if (!scalar_of(type, &scalar))
            {
                return false;
            }
            return calculator_.layout_scalar(scalar, out);
        }
        case TypeKind::Transparent:
            return layout_of(type->inner, out);
        case TypeKind::Array:
        {
            LayoutData element;
            if (!layout_of(type->inner, &element))
            {
                return false;
            }
            return calculator_.layout_array(element, type->array_count, out);
        }
        case TypeKind::Slice:
        {
            LayoutData element;
            if (!layout_of(type->inner, &element))
            {
                return false;
            }
            *out = LayoutData();
            out->align = element.align;
            out->unadjusted_abi_align = element.align;
            out->backend = BackendReprKind::Memory;
            out->fields_kind = FieldsShapeKind::Array;
            out->variants_kind = VariantsKind::Single;
            return true;
        }
        case TypeKind::Tuple:
        case TypeKind::Struct:
        {
            std::vector<LayoutData> fields;
            if (!layout_children(type, &fields))
            {
                return false;
            }
            return calculator_.layout_univariant(fields, type->repr, out);
        }
        case TypeKind::Union:
        {
            std::vector<LayoutData> fields;
            if (!layout_children(type, &fields))
            {
                return false;
            }
            return calculator_.layout_union(fields, type->repr, out);
        }
        case TypeKind::Enum:
        {
            std::vector<std::vector<LayoutData> > variants;
            std::vector<U128> discriminants;
            if (!layout_enum_variants(type, &variants, &discriminants))
            {
                return false;
            }
            return calculator_.layout_enum(variants, discriminants, type->repr, out);
        }
        case TypeKind::Simd:
        {
            LayoutData element;
            if (!layout_of(type->inner, &element))
            {
                return false;
            }
            return calculator_.layout_simd(element, type->array_count,
                                           type->repr.is_packed, out);
        }
        case TypeKind::Coroutine:
        {
            std::vector<LayoutData> locals;
            std::vector<std::vector<uint32_t> > variant_locals;
            std::vector<std::vector<bool> > storage_conflicts;
            if (!layout_coroutine_states(type, &locals, &variant_locals, &storage_conflicts))
            {
                return false;
            }
            if (variant_locals.empty())
            {
                return false;
            }
            std::vector<LayoutData> prefix;
            if (!layout_children(type, &prefix))
            {
                return false;
            }
            return calculator_.layout_coroutine(locals, prefix, variant_locals,
                                                storage_conflicts, out);
        }
        default:
            return false;
    }
}

} // namespace rscabi
