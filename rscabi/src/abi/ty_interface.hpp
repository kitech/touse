#ifndef RSCABI_TY_INTERFACE_HPP
#define RSCABI_TY_INTERFACE_HPP

#include "../core/core.hpp"
#include "../model/abi_type.hpp"

namespace rscabi {

struct Reg;

// C++ equivalent of rustc_abi's `Ty`/`TyCtxt` driven interface. It walks
// `AbiType` through `TypeContext` and exposes the operations the ABI code
// needs (field access, variant access, 1-ZST detection and HVA merge).
class TyAbiInterface
{
public:
    explicit TyAbiInterface(const TypeContext &cx) : cx_(&cx) {}

    const TargetDataLayout *data_layout() const { return &cx_->data_layout(); }

    bool is_1zst(const LayoutData &layout) const
    {
        return layout.size == 1 && layout.align == 1 && layout.field_offsets.empty();
    }

    bool field_layout(const LayoutData &parent, FieldIdx index, LayoutData *out) const;

    bool variant_layout(const LayoutData &parent, VariantIdx index, LayoutData *out) const;

    bool homogeneous_aggregate(const LayoutData &layout, Reg *out, bool *has_data) const;

private:
    const TypeContext *cx_;

    bool merge(const Reg &a,
               bool a_data,
               const Reg &b,
               bool b_data,
               Reg *out,
               bool *has_data) const;
};

} // namespace rscabi

#endif
