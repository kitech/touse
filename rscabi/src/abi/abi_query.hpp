#ifndef RSCABI_ABI_QUERY_HPP
#define RSCABI_ABI_QUERY_HPP

#include <string>

#include "../model/abi_type.hpp"
#include "callconv.hpp"
#include "canon_abi.hpp"
#include "extern_abi.hpp"

namespace rscabi {

CallingConv callconv_for_canon(const CanonAbi &abi, const char *target_triple);
CallingConv callconv_for_extern(ExternAbi abi, const char *target_triple);
const char *callconv_name(CallingConv callconv);
bool parse_callconv(const std::string &text, CallingConv *out);

bool homogeneous_aggregate(const TypeContext &cx,
                           const LayoutData &layout,
                           ExternAbi abi,
                           const char *target_triple,
                           HomogeneousAggregate *out);

} // namespace rscabi

#endif
