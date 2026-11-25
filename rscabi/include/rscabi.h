#ifndef RSCABI_H
#define RSCABI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    RSCABI_OK = 0,
    RSCABI_ERR_INVALID_ARG = 1,
    RSCABI_ERR_PANIC = 2,
    RSCABI_ERR_LAYOUT = 3,
    RSCABI_ERR_OOM = 4,
    RSCABI_ERR_UNSUPPORTED = 5
} rscabi_status_t;

typedef struct rscabi_target rscabi_target_t;
typedef struct rscabi_context rscabi_context_t;
typedef struct rscabi_type rscabi_type_t;
typedef struct rscabi_layout rscabi_layout_t;

typedef struct {
    uint64_t lo;
    uint64_t hi;
} rscabi_u128_t;

#define RSCABI_REPR_C 0x00000001u
#define RSCABI_REPR_TRANSPARENT 0x00000002u
#define RSCABI_REPR_PACKED 0x00000004u
#define RSCABI_REPR_SIMD 0x00000008u
#define RSCABI_REPR_SCALABLE 0x00000010u

typedef struct {
    uint32_t flags;
    uint32_t align_bits;
    uint32_t pack_bits;
    uint32_t int_bits;
} rscabi_repr_t;

#define RSCABI_BACKEND_MEMORY 0u
#define RSCABI_BACKEND_SCALAR 1u
#define RSCABI_BACKEND_SCALAR_PAIR 2u
#define RSCABI_BACKEND_SIMD_VECTOR 3u
#define RSCABI_BACKEND_SIMD_SCALABLE_VECTOR 4u

#define RSCABI_FIELDS_PRIMITIVE 0u
#define RSCABI_FIELDS_ARBITRARY 1u
#define RSCABI_FIELDS_ARRAY 2u
#define RSCABI_FIELDS_UNION 3u

#define RSCABI_VARIANTS_NONE 0u
#define RSCABI_VARIANTS_SINGLE 1u
#define RSCABI_VARIANTS_MULTIPLE 2u

#define RSCABI_TAG_NONE 0u
#define RSCABI_TAG_DIRECT 1u
#define RSCABI_TAG_NICHE 2u

#define RSCABI_EXTERN_ABI_C 0u
#define RSCABI_EXTERN_ABI_C_UNWIND 1u
#define RSCABI_EXTERN_ABI_SYSTEM 2u
#define RSCABI_EXTERN_ABI_SYSTEM_UNWIND 3u
#define RSCABI_EXTERN_ABI_RUST 4u
#define RSCABI_EXTERN_ABI_RUST_CALL 5u
#define RSCABI_EXTERN_ABI_RUST_COLD 6u
#define RSCABI_EXTERN_ABI_RUST_INVALID 7u
#define RSCABI_EXTERN_ABI_RUST_PRESERVE_NONE 8u
#define RSCABI_EXTERN_ABI_RUST_TAIL 9u
#define RSCABI_EXTERN_ABI_LLVM_INTRINSIC 10u
#define RSCABI_EXTERN_ABI_CUSTOM 11u
#define RSCABI_EXTERN_ABI_EFIAPI 12u
#define RSCABI_EXTERN_ABI_SWIFT 13u
#define RSCABI_EXTERN_ABI_AAPCS 14u
#define RSCABI_EXTERN_ABI_AAPCS_UNWIND 15u
#define RSCABI_EXTERN_ABI_CMSE_NONSECURE_CALL 16u
#define RSCABI_EXTERN_ABI_CMSE_NONSECURE_ENTRY 17u
#define RSCABI_EXTERN_ABI_GPU_KERNEL 18u
#define RSCABI_EXTERN_ABI_PTX_KERNEL 19u
#define RSCABI_EXTERN_ABI_AVR_INTERRUPT 20u
#define RSCABI_EXTERN_ABI_AVR_NON_BLOCKING_INTERRUPT 21u
#define RSCABI_EXTERN_ABI_MSP430_INTERRUPT 22u
#define RSCABI_EXTERN_ABI_RISCV_INTERRUPT_M 23u
#define RSCABI_EXTERN_ABI_RISCV_INTERRUPT_S 24u
#define RSCABI_EXTERN_ABI_X86_INTERRUPT 25u
#define RSCABI_EXTERN_ABI_CDECL 26u
#define RSCABI_EXTERN_ABI_CDECL_UNWIND 27u
#define RSCABI_EXTERN_ABI_STDCALL 28u
#define RSCABI_EXTERN_ABI_STDCALL_UNWIND 29u
#define RSCABI_EXTERN_ABI_FASTCALL 30u
#define RSCABI_EXTERN_ABI_FASTCALL_UNWIND 31u
#define RSCABI_EXTERN_ABI_THISCALL 32u
#define RSCABI_EXTERN_ABI_THISCALL_UNWIND 33u
#define RSCABI_EXTERN_ABI_VECTORCALL 34u
#define RSCABI_EXTERN_ABI_VECTORCALL_UNWIND 35u
#define RSCABI_EXTERN_ABI_SYSV64 36u
#define RSCABI_EXTERN_ABI_SYSV64_UNWIND 37u
#define RSCABI_EXTERN_ABI_WIN64 38u
#define RSCABI_EXTERN_ABI_WIN64_UNWIND 39u

#define RSCABI_CALLCONV_C 0u
#define RSCABI_CALLCONV_RUST 1u
#define RSCABI_CALLCONV_RUST_COLD 2u
#define RSCABI_CALLCONV_RUST_CALL 3u
#define RSCABI_CALLCONV_SYSTEM 4u
#define RSCABI_CALLCONV_ARM_AAPCS 5u
#define RSCABI_CALLCONV_X86_STDCALL 6u
#define RSCABI_CALLCONV_X86_FASTCALL 7u
#define RSCABI_CALLCONV_X86_THISCALL 8u
#define RSCABI_CALLCONV_X86_VECTORCALL 9u
#define RSCABI_CALLCONV_X86_SYSV64 10u
#define RSCABI_CALLCONV_X86_WIN64 11u
#define RSCABI_CALLCONV_SWIFT 12u
#define RSCABI_CALLCONV_GPU_KERNEL 13u
#define RSCABI_CALLCONV_INTERRUPT 14u
#define RSCABI_CALLCONV_CUSTOM 15u

#define RSCABI_REG_KIND_INTEGER 0u
#define RSCABI_REG_KIND_FLOAT 1u
#define RSCABI_REG_KIND_VECTOR 2u

#define RSCABI_AGG_HETEROGENEOUS 0u
#define RSCABI_AGG_HOMOGENEOUS 1u
#define RSCABI_AGG_NO_DATA 2u

#define RSCABI_CANON_C 0u
#define RSCABI_CANON_RUST 1u
#define RSCABI_CANON_RUST_COLD 2u
#define RSCABI_CANON_RUST_PRESERVE_NONE 3u
#define RSCABI_CANON_RUST_TAIL 4u
#define RSCABI_CANON_CUSTOM 5u
#define RSCABI_CANON_SWIFT 6u
#define RSCABI_CANON_ARM 7u
#define RSCABI_CANON_GPU_KERNEL 8u
#define RSCABI_CANON_INTERRUPT 9u
#define RSCABI_CANON_X86 10u

#define RSCABI_ARM_CALL_AAPCS 0u
#define RSCABI_ARM_CALL_CMSE_NONSECURE_CALL 1u
#define RSCABI_ARM_CALL_CMSE_NONSECURE_ENTRY 2u

#define RSCABI_X86_CALL_FASTCALL 0u
#define RSCABI_X86_CALL_STDCALL 1u
#define RSCABI_X86_CALL_SYSV64 2u
#define RSCABI_X86_CALL_THISCALL 3u
#define RSCABI_X86_CALL_VECTORCALL 4u
#define RSCABI_X86_CALL_WIN64 5u

#define RSCABI_INTERRUPT_AVR 0u
#define RSCABI_INTERRUPT_AVR_NON_BLOCKING 1u
#define RSCABI_INTERRUPT_MSP430 2u
#define RSCABI_INTERRUPT_RISCV_MACHINE 3u
#define RSCABI_INTERRUPT_RISCV_SUPERVISOR 4u
#define RSCABI_INTERRUPT_X86 5u

typedef struct {
    uint64_t size;
    uint64_t align;
    uint64_t unadjusted_abi_align;
    uint8_t uninhabited;
    uint8_t has_largest_niche;
    uint64_t niche_offset;
    rscabi_u128_t niche_start;
    rscabi_u128_t niche_end;
    uint32_t tag_encoding;
    uint32_t untagged_variant;
    uint32_t variant_count;
    uint32_t field_count;
    uint32_t backend_repr;
    uint32_t variants_kind;
} rscabi_layout_info_t;

typedef struct {
    uint64_t size;
    uint64_t align;
    uint32_t has_tag_range;
    rscabi_u128_t tag_start;
    rscabi_u128_t tag_end;
} rscabi_variant_info_t;

typedef struct {
    uint64_t offset;
    uint64_t size;
} rscabi_byte_range_t;

typedef struct {
    uint32_t kind;
    uint64_t size;
} rscabi_reg_t;

typedef struct {
    uint32_t kind;
    rscabi_reg_t reg;
} rscabi_homogeneous_aggregate_t;

typedef struct {
    uint32_t kind;
    uint32_t arm;
    uint32_t x86;
    uint32_t interrupt;
} rscabi_canon_abi_t;

const char *rscabi_rustc_version(void);
const char *rscabi_source_commit(void);
uint32_t rscabi_abi_version(void);

rscabi_status_t rscabi_target_new(uint32_t pointer_bits,
                                   uint32_t pointer_align_bits,
                                   uint32_t usize_bits,
                                   uint8_t little_endian,
                                   rscabi_target_t **out);
rscabi_status_t rscabi_target_from_llvm_datalayout(const char *data_layout,
                                                    rscabi_target_t **out);
void rscabi_target_free(rscabi_target_t *target);

rscabi_status_t rscabi_context_new(rscabi_target_t *target,
                                   rscabi_context_t **out);
void rscabi_context_free(rscabi_context_t *ctx);

rscabi_status_t rscabi_type_never(rscabi_context_t *ctx, rscabi_type_t **out);
rscabi_status_t rscabi_type_unit(rscabi_context_t *ctx, rscabi_type_t **out);
rscabi_status_t rscabi_type_bool(rscabi_context_t *ctx, rscabi_type_t **out);
rscabi_status_t rscabi_type_char(rscabi_context_t *ctx, rscabi_type_t **out);
rscabi_status_t rscabi_type_int(rscabi_context_t *ctx,
                                uint32_t bits,
                                int is_signed,
                                rscabi_type_t **out);
rscabi_status_t rscabi_type_float(rscabi_context_t *ctx,
                                  uint32_t bits,
                                  rscabi_type_t **out);
rscabi_status_t rscabi_type_fn_pointer(rscabi_context_t *ctx,
                                       rscabi_type_t **out);
rscabi_status_t rscabi_type_pointer(rscabi_context_t *ctx,
                                    rscabi_type_t *pointee,
                                    int fat,
                                    rscabi_type_t **out);
rscabi_status_t rscabi_type_reference(rscabi_context_t *ctx,
                                      rscabi_type_t *pointee,
                                      int is_mutable,
                                      rscabi_type_t **out);
rscabi_status_t rscabi_type_slice_ref(rscabi_context_t *ctx,
                                      rscabi_type_t *element,
                                      int is_mutable,
                                      rscabi_type_t **out);
rscabi_status_t rscabi_type_box(rscabi_context_t *ctx,
                                rscabi_type_t *inner,
                                rscabi_type_t **out);
rscabi_status_t rscabi_type_nonnull(rscabi_context_t *ctx,
                                    rscabi_type_t *inner,
                                    rscabi_type_t **out);
rscabi_status_t rscabi_type_nonzero(rscabi_context_t *ctx,
                                    rscabi_type_t *inner,
                                    rscabi_type_t **out);
rscabi_status_t rscabi_type_transparent_newtype(rscabi_context_t *ctx,
                                                rscabi_type_t *inner,
                                                rscabi_type_t **out);
rscabi_status_t rscabi_type_array(rscabi_context_t *ctx,
                                  rscabi_type_t *element,
                                  uint64_t count,
                                  rscabi_type_t **out);
rscabi_status_t rscabi_type_slice(rscabi_context_t *ctx,
                                  rscabi_type_t *element,
                                  rscabi_type_t **out);
rscabi_status_t rscabi_type_tuple_begin(rscabi_context_t *ctx,
                                        rscabi_type_t **out);
rscabi_status_t rscabi_type_struct_begin(rscabi_context_t *ctx,
                                         const rscabi_repr_t *repr,
                                         rscabi_type_t **out);
rscabi_status_t rscabi_type_union_begin(rscabi_context_t *ctx,
                                        const rscabi_repr_t *repr,
                                        rscabi_type_t **out);
rscabi_status_t rscabi_type_enum_begin(rscabi_context_t *ctx,
                                       const rscabi_repr_t *repr,
                                       rscabi_type_t **out);
rscabi_status_t rscabi_type_simd(rscabi_context_t *ctx,
                                 rscabi_type_t *element,
                                 uint64_t lanes,
                                 int packed,
                                 rscabi_type_t **out);
rscabi_status_t rscabi_type_coroutine_begin(rscabi_context_t *ctx,
                                            rscabi_type_t **out);
rscabi_status_t rscabi_type_coroutine_add_state(rscabi_context_t *ctx,
                                                rscabi_type_t *coroutine,
                                                rscabi_u128_t discriminant,
                                                size_t *out_index);
rscabi_status_t rscabi_type_coroutine_add_state_field(rscabi_context_t *ctx,
                                                      rscabi_type_t *coroutine,
                                                      size_t state_index,
                                                      rscabi_type_t *field);
rscabi_status_t rscabi_type_coroutine_set_discriminant(rscabi_context_t *ctx,
                                                       rscabi_type_t *coroutine,
                                                       size_t state_index,
                                                       rscabi_u128_t discriminant);
rscabi_status_t rscabi_type_add_field(rscabi_context_t *ctx,
                                      rscabi_type_t *aggregate,
                                      rscabi_type_t *field);
rscabi_status_t rscabi_type_enum_add_variant(rscabi_context_t *ctx,
                                             rscabi_type_t *aggregate,
                                             const rscabi_type_t *const *fields,
                                             size_t field_count,
                                             rscabi_u128_t discriminant,
                                             uint32_t flags);
rscabi_status_t rscabi_type_finish(rscabi_context_t *ctx,
                                   rscabi_type_t *type);
void rscabi_type_free(rscabi_type_t *type);

rscabi_status_t rscabi_layout_of(rscabi_context_t *ctx,
                                 rscabi_type_t *type,
                                 rscabi_layout_t **out);
rscabi_status_t rscabi_layout_info(const rscabi_layout_t *layout,
                                   rscabi_layout_info_t *out);
rscabi_status_t rscabi_layout_field_offset(const rscabi_layout_t *layout,
                                           size_t field_index,
                                           uint64_t *out_offset);
rscabi_status_t rscabi_layout_variant_count(const rscabi_layout_t *layout,
                                            size_t *out_count);
rscabi_status_t rscabi_layout_variant_info(const rscabi_layout_t *layout,
                                           size_t variant_index,
                                           rscabi_variant_info_t *out);
rscabi_status_t rscabi_layout_has_variant_dependent_padding(
    const rscabi_layout_t *layout, int *out);
rscabi_status_t rscabi_layout_variant_independent_padding_ranges(
    const rscabi_layout_t *layout,
    rscabi_byte_range_t *out_ranges,
    size_t capacity,
    size_t *out_count);
rscabi_status_t rscabi_layout_variant_dependent_padding_ranges(
    const rscabi_layout_t *layout,
    size_t variant_index,
    rscabi_byte_range_t *out_ranges,
    size_t capacity,
    size_t *out_count);

/* Internal layout details, useful for rustc layout cross-checks. */
rscabi_status_t rscabi_layout_field_offsets(const rscabi_layout_t *layout,
                                            uint64_t *out_offsets,
                                            size_t capacity,
                                            size_t *out_count);
rscabi_status_t rscabi_layout_field_sizes(const rscabi_layout_t *layout,
                                          uint64_t *out_sizes,
                                          size_t capacity,
                                          size_t *out_count);
rscabi_status_t rscabi_layout_memory_order(const rscabi_layout_t *layout,
                                           uint32_t *out_order,
                                           size_t capacity,
                                           size_t *out_count);
rscabi_status_t rscabi_layout_fields_kind(const rscabi_layout_t *layout,
                                          uint32_t *out_kind);
rscabi_status_t rscabi_layout_variant_field_offsets(const rscabi_layout_t *layout,
                                                    size_t variant_index,
                                                    uint64_t *out_offsets,
                                                    size_t capacity,
                                                    size_t *out_count);
rscabi_status_t rscabi_layout_variant_memory_order(const rscabi_layout_t *layout,
                                                   size_t variant_index,
                                                   uint32_t *out_order,
                                                   size_t capacity,
                                                   size_t *out_count);
rscabi_status_t rscabi_layout_variant_tag_range(const rscabi_layout_t *layout,
                                                size_t variant_index,
                                                rscabi_u128_t *out_start,
                                                rscabi_u128_t *out_end);
rscabi_status_t rscabi_layout_tag_encoding(const rscabi_layout_t *layout,
                                           uint32_t *out_encoding);
rscabi_status_t rscabi_layout_untagged_variant(const rscabi_layout_t *layout,
                                               uint32_t *out_variant);
rscabi_status_t rscabi_layout_niche_variants(const rscabi_layout_t *layout,
                                             uint32_t *out_start,
                                             uint32_t *out_end);
/* Extern ABI / canonical ABI / calling-convention queries. */
rscabi_status_t rscabi_extern_abi_from_str(const char *text, uint32_t *out);
const char *rscabi_extern_abi_as_str(uint32_t abi);
int rscabi_extern_abi_is_rustic(uint32_t abi);
int rscabi_extern_abi_supports_c_variadic(uint32_t abi);
rscabi_status_t rscabi_extern_abi_default_for_target(const char *target_triple,
                                                     uint32_t *out);
rscabi_status_t rscabi_extern_abi_resolve_system(uint32_t abi,
                                                 const char *target_triple,
                                                 uint32_t *out);
rscabi_status_t rscabi_canonize(uint32_t abi,
                                const char *target_triple,
                                rscabi_canon_abi_t *out);
const char *rscabi_canon_abi_as_str(const rscabi_canon_abi_t *abi);
int rscabi_canon_abi_is_rustic(const rscabi_canon_abi_t *abi);
rscabi_status_t rscabi_callconv_for_extern(uint32_t abi,
                                           const char *target_triple,
                                           uint32_t *out);
const char *rscabi_callconv_name(uint32_t callconv);
rscabi_status_t rscabi_layout_homogeneous_aggregate(rscabi_context_t *ctx,
                                                    const rscabi_layout_t *layout,
                                                    uint32_t abi,
                                                    const char *target_triple,
                                                    rscabi_homogeneous_aggregate_t *out);
void rscabi_layout_free(rscabi_layout_t *layout);

#ifdef __cplusplus
}
#endif

#endif
