#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

#include "../include/rscabi.h"
#include "../src/abi/abi_query.hpp"
#include "../src/abi/callconv.hpp"
#include "../src/abi/canon_abi.hpp"
#include "../src/abi/extern_abi.hpp"
#include "../src/model/abi_type.hpp"

namespace {

const char *kDefaultDataLayout =
    "e-m:e-p:64:64-p1:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-"
    "i128:128:128-f32:32:32-f64:64:64-v128:128:128-a:0:64:64-s0:64:64-f80:128:128-n8:16:32:64-S128";

class Parser
{
public:
    Parser(rscabi::TypeContext *ctx,
           const rscabi::TargetDataLayout &target,
           const std::string &text,
           std::string *error)
        : ctx_(ctx), target_(target), text_(text), pos_(0), error_(error)
    {
    }

    rscabi::AbiType *parse()
    {
        rscabi::AbiType *type = parse_type();
        skip_space();
        if (type != NULL && pos_ != text_.size())
        {
            set_error("unexpected trailing input");
            return NULL;
        }
        return type;
    }

private:
    rscabi::TypeContext *ctx_;
    rscabi::TargetDataLayout target_;
    std::string text_;
    size_t pos_;
    std::string *error_;

    void set_pointer_scalar(rscabi::AbiType *type, bool nonnull)
    {
        type->scalar.primitive = rscabi::PrimitiveKind::Pointer;
        type->scalar.bits = target_.pointer_bits;
        if (nonnull)
        {
            type->scalar.valid = rscabi::WrappingRange(
                rscabi::U128::from_u64(1), rscabi::u128_unsigned_max(target_.pointer_bits));
        }
        else
        {
            type->scalar.valid = rscabi::WrappingRange::full(target_.pointer_bits);
        }
    }

    void set_error(const std::string &message)
    {
        if (error_ != NULL && error_->empty())
        {
            *error_ = message;
        }
    }

    void skip_space()
    {
        while (pos_ < text_.size() && (text_[pos_] == ' ' || text_[pos_] == '\t'))
        {
            pos_++;
        }
    }

    bool consume(char c)
    {
        skip_space();
        if (pos_ < text_.size() && text_[pos_] == c)
        {
            pos_++;
            return true;
        }
        return false;
    }

    bool expect(char c)
    {
        if (!consume(c))
        {
            set_error(std::string("expected '") + c + "'");
            return false;
        }
        return true;
    }

    std::string peek_word() const
    {
        size_t p = pos_;
        while (p < text_.size() && (text_[p] == ' ' || text_[p] == '\t'))
        {
            p++;
        }
        size_t start = p;
        while (p < text_.size())
        {
            char c = text_[p];
            bool ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                      (c >= '0' && c <= '9') || c == '_' || c == '=' ||
                      c == '+' || c == ':' || c == '-';
            if (!ok)
            {
                break;
            }
            p++;
        }
        return text_.substr(start, p - start);
    }

    std::string parse_word()
    {
        skip_space();
        size_t start = pos_;
        while (pos_ < text_.size())
        {
            char c = text_[pos_];
            bool ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                      (c >= '0' && c <= '9') || c == '_' || c == '=' ||
                      c == '+' || c == ':' || c == '-';
            if (!ok)
            {
                break;
            }
            pos_++;
        }
        if (start == pos_)
        {
            set_error("expected type name");
            return std::string();
        }
        return text_.substr(start, pos_ - start);
    }

    bool parse_number(const std::string &word, uint64_t *out)
    {
        if (word.empty())
        {
            return false;
        }
        char *end = NULL;
        unsigned long long value = strtoull(word.c_str(), &end, 10);
        if (end == NULL || *end != '\0')
        {
            return false;
        }
        *out = static_cast<uint64_t>(value);
        return true;
    }

    bool parse_repr(const std::string &word, rscabi::ReprOptions *out)
    {
        *out = rscabi::ReprOptions();
        if (word.compare(0, 5, "repr=") != 0)
        {
            return true;
        }
        std::string body = word.substr(5);
        size_t start = 0;
        while (start <= body.size())
        {
            size_t end = body.find('+', start);
            std::string part = body.substr(start, end == std::string::npos
                                                      ? std::string::npos
                                                      : end - start);
            if (part == "C")
            {
                out->is_c = true;
            }
            else if (part == "packed")
            {
                out->is_packed = true;
                out->pack_bits = 8;
            }
            else if (part == "simd")
            {
                out->is_simd = true;
            }
            else if (part.compare(0, 6, "align=") == 0)
            {
                uint64_t value = 0;
                if (!parse_number(part.substr(6), &value))
                {
                    return false;
                }
                out->align_bits = static_cast<uint32_t>(value);
            }
            else if (part.compare(0, 5, "pack=") == 0)
            {
                uint64_t value = 0;
                if (!parse_number(part.substr(5), &value))
                {
                    return false;
                }
                out->pack_bits = static_cast<uint32_t>(value);
            }
            else if (part.compare(0, 4, "int=") == 0)
            {
                uint64_t value = 0;
                if (!parse_number(part.substr(4), &value))
                {
                    return false;
                }
                out->int_bits = static_cast<uint32_t>(value);
            }
            else if (!part.empty())
            {
                set_error("unknown repr flag: " + part);
                return false;
            }
            if (end == std::string::npos)
            {
                break;
            }
            start = end + 1;
        }
        return true;
    }

    std::vector<const rscabi::AbiType *> parse_field_list(char close)
    {
        std::vector<const rscabi::AbiType *> fields;
        if (consume(close))
        {
            return fields;
        }
        while (true)
        {
            rscabi::AbiType *field = parse_type();
            if (field == NULL)
            {
                return std::vector<const rscabi::AbiType *>();
            }
            fields.push_back(field);
            if (consume(','))
            {
                continue;
            }
            if (!expect(close))
            {
                return std::vector<const rscabi::AbiType *>();
            }
            break;
        }
        return fields;
    }

    rscabi::AbiType *parse_int(const std::string &word)
    {
        bool signed_kind = word[0] == 'i';
        uint64_t bits = 0;
        if (word == "isize" || word == "usize")
        {
            bits = target_.usize_bits;
        }
        else if (!parse_number(word.substr(1), &bits))
        {
            set_error("bad integer type: " + word);
            return NULL;
        }
        if (bits == 0 || bits > 128 || (bits % 8) != 0)
        {
            set_error("unsupported integer width: " + word);
            return NULL;
        }
        rscabi::AbiType *type = ctx_->create(rscabi::TypeKind::Int);
        type->scalar.primitive = rscabi::PrimitiveKind::Int;
        type->scalar.bits = static_cast<uint32_t>(bits);
        type->scalar.is_signed = signed_kind;
        type->scalar.valid = rscabi::WrappingRange::full(static_cast<uint32_t>(bits));
        return type;
    }

    rscabi::AbiType *parse_float(const std::string &word)
    {
        uint64_t bits = 0;
        if (!parse_number(word.substr(1), &bits))
        {
            set_error("bad float type: " + word);
            return NULL;
        }
        rscabi::AbiType *type = ctx_->create(rscabi::TypeKind::Float);
        type->scalar.primitive = rscabi::PrimitiveKind::Float;
        type->scalar.bits = static_cast<uint32_t>(bits);
        type->scalar.valid = rscabi::WrappingRange::full(static_cast<uint32_t>(bits));
        return type;
    }

    rscabi::AbiType *parse_enum(bool option_shorthand)
    {
        if (!expect('('))
        {
            return NULL;
        }
        rscabi::AbiType *type = ctx_->create(rscabi::TypeKind::Enum);
        if (!option_shorthand)
        {
            size_t save = pos_;
            std::string repr_word = peek_word();
            if (repr_word.compare(0, 5, "repr=") == 0)
            {
                pos_ += repr_word.size();
                if (!parse_repr(repr_word, &type->repr) || !consume(','))
                {
                    set_error("expected ',' after repr");
                    return NULL;
                }
            }
            else
            {
                pos_ = save;
            }
        }
        if (option_shorthand)
        {
            rscabi::EnumVariant none;
            none.discriminant = rscabi::U128::from_u64(0);
            type->variants.push_back(none);
            rscabi::EnumVariant some;
            some.fields.push_back(parse_type());
            if (some.fields[0] == NULL)
            {
                return NULL;
            }
            some.discriminant = rscabi::U128::from_u64(1);
            type->variants.push_back(some);
            if (!expect(')'))
            {
                return NULL;
            }
            return type;
        }

        uint64_t discriminant = 0;
        while (true)
        {
            rscabi::EnumVariant variant;
            if (consume('('))
            {
                variant.fields = parse_field_list(')');
                if (variant.fields.empty() && error_ != NULL && !error_->empty())
                {
                    return NULL;
                }
            }
            else if (consume(')'))
            {
                break;
            }
            else
            {
                rscabi::AbiType *field = parse_type();
                if (field == NULL)
                {
                    return NULL;
                }
                variant.fields.push_back(field);
            }
            variant.discriminant = rscabi::U128::from_u64(discriminant++);
            type->variants.push_back(variant);
            if (consume('|'))
            {
                continue;
            }
            if (!expect(')'))
            {
                return NULL;
            }
            break;
        }
        return type;
    }

    rscabi::AbiType *parse_simd(bool packed)
    {
        if (!expect('('))
        {
            return NULL;
        }
        rscabi::AbiType *element = parse_type();
        if (element == NULL || !consume(','))
        {
            return NULL;
        }
        std::string lanes_word = parse_word();
        uint64_t lanes = 0;
        if (!parse_number(lanes_word, &lanes) || lanes == 0 || lanes > 65535 ||
            !expect(')'))
        {
            set_error("bad SIMD lane count");
            return NULL;
        }
        rscabi::AbiType *type = ctx_->create(rscabi::TypeKind::Simd);
        type->inner = element;
        type->array_count = lanes;
        type->repr.is_simd = true;
        type->repr.is_packed = packed;
        return type;
    }

    rscabi::AbiType *parse_coroutine()
    {
        if (!expect('('))
        {
            return NULL;
        }
        std::string kind = parse_word();
        if (kind != "async" && kind != "gen")
        {
            set_error("coroutine kind must be async or gen");
            return NULL;
        }
        if (!consume(','))
        {
            set_error("expected ',' after coroutine kind");
            return NULL;
        }
        rscabi::AbiType *type = ctx_->create(rscabi::TypeKind::Coroutine);
        uint64_t discriminant = 0;
        while (true)
        {
            std::string state_word = parse_word();
            if (state_word != "state" || !expect('('))
            {
                set_error("expected state(...) in coroutine");
                return NULL;
            }
            rscabi::CoroutineState state;
            state.discriminant = rscabi::U128::from_u64(discriminant++);
            if (!consume(')'))
            {
                while (true)
                {
                    rscabi::AbiType *field = parse_type();
                    if (field == NULL)
                    {
                        return NULL;
                    }
                    state.fields.push_back(field);
                    if (consume(','))
                    {
                        continue;
                    }
                    if (!expect(')'))
                    {
                        return NULL;
                    }
                    break;
                }
            }
            type->coroutine_states.push_back(state);
            if (consume('|'))
            {
                continue;
            }
            if (!expect(')'))
            {
                return NULL;
            }
            break;
        }
        return type;
    }

    rscabi::AbiType *parse_type()
    {
        std::string word = parse_word();
        if (word.empty())
        {
            return NULL;
        }

        if (word == "never")
        {
            return ctx_->create(rscabi::TypeKind::Never);
        }
        if (word == "unit" || word == "()")
        {
            return ctx_->create(rscabi::TypeKind::Unit);
        }
        if (word == "bool")
        {
            return ctx_->create(rscabi::TypeKind::Bool);
        }
        if (word == "char")
        {
            return ctx_->create(rscabi::TypeKind::Char);
        }
        if (word == "fnptr")
        {
            rscabi::AbiType *type = ctx_->create(rscabi::TypeKind::FnPointer);
            type->scalar.primitive = rscabi::PrimitiveKind::FnPointer;
            set_pointer_scalar(type, true);
            type->scalar.primitive = rscabi::PrimitiveKind::FnPointer;
            return type;
        }
        if ((word[0] == 'i' || word[0] == 'u') && word != "unit" && word != "union")
        {
            return parse_int(word);
        }
        if (word[0] == 'f' && word != "fatptr")
        {
            return parse_float(word);
        }
        if (word == "ptr" || word == "fatptr" || word == "ref" || word == "refslice" ||
            word == "refmut" || word == "box" || word == "nonnull" || word == "nonzero" ||
            word == "transparent" || word == "slice")
        {
            if (!expect('('))
            {
                return NULL;
            }
            rscabi::AbiType *inner = parse_type();
            if (inner == NULL)
            {
                return NULL;
            }
            if (!expect(')'))
            {
                return NULL;
            }
            rscabi::TypeKind kind = rscabi::TypeKind::Pointer;
            if (word == "ref" || word == "refmut" || word == "refslice")
            {
                kind = rscabi::TypeKind::Reference;
            }
            else if (word == "box")
            {
                kind = rscabi::TypeKind::Box;
            }
            else if (word == "nonnull")
            {
                kind = rscabi::TypeKind::NonNull;
            }
            else if (word == "nonzero")
            {
                kind = rscabi::TypeKind::NonZero;
            }
            else if (word == "transparent")
            {
                kind = rscabi::TypeKind::Transparent;
            }
            else if (word == "slice")
            {
                kind = rscabi::TypeKind::Slice;
            }
            rscabi::AbiType *type = ctx_->create(kind);
            type->inner = inner;
            set_pointer_scalar(type, word != "ptr" && word != "fatptr");
            if (word == "refmut" || word == "refslice")
            {
                type->is_mutable = word == "refmut";
            }
            if (word == "fatptr" || word == "refslice")
            {
                type->is_fat_pointer = true;
            }
            return type;
        }
        if (word == "array")
        {
            if (!expect('('))
            {
                return NULL;
            }
            rscabi::AbiType *inner = parse_type();
            if (inner == NULL || !consume(','))
            {
                return NULL;
            }
            std::string count_word = parse_word();
            uint64_t count = 0;
            if (!parse_number(count_word, &count) || !expect(')'))
            {
                set_error("bad array count");
                return NULL;
            }
            rscabi::AbiType *type = ctx_->create(rscabi::TypeKind::Array);
            type->inner = inner;
            type->array_count = count;
            return type;
        }
        if (word == "tuple" || word == "struct" || word == "union")
        {
            if (!expect('('))
            {
                return NULL;
            }
            rscabi::ReprOptions repr;
            if (word != "tuple")
            {
                size_t save = pos_;
                std::string repr_word = parse_word();
                if (error_ != NULL && !error_->empty())
                {
                    return NULL;
                }
                if (repr_word.compare(0, 5, "repr=") == 0)
                {
                    if (!parse_repr(repr_word, &repr))
                    {
                        return NULL;
                    }
                    if (!consume(','))
                    {
                        set_error("expected ',' after repr");
                        return NULL;
                    }
                }
                else
                {
                    pos_ = save;
                }
            }
            std::vector<const rscabi::AbiType *> fields = parse_field_list(')');
            if (fields.empty() && error_ != NULL && !error_->empty())
            {
                return NULL;
            }
            rscabi::TypeKind kind = word == "tuple" ? rscabi::TypeKind::Tuple
                                                    : (word == "struct" ? rscabi::TypeKind::Struct
                                                                        : rscabi::TypeKind::Union);
            rscabi::AbiType *type = ctx_->create(kind);
            type->repr = repr;
            type->fields = fields;
            return type;
        }
        if (word == "enum" || word == "option")
        {
            return parse_enum(word == "option");
        }
        if (word == "simd")
        {
            return parse_simd(false);
        }
        if (word == "simd_packed")
        {
            return parse_simd(true);
        }
        if (word == "coroutine")
        {
            return parse_coroutine();
        }

        set_error("unknown type: " + word);
        return NULL;
    }
};

const char *backend_name(uint32_t code)
{
    switch (code)
    {
        case RSCABI_BACKEND_SCALAR:
            return "scalar";
        case RSCABI_BACKEND_SCALAR_PAIR:
            return "scalar_pair";
        case RSCABI_BACKEND_SIMD_VECTOR:
            return "simd_vector";
        default:
            return "memory";
    }
}

const char *tag_name(uint32_t code)
{
    switch (code)
    {
        case RSCABI_TAG_DIRECT:
            return "direct";
        case RSCABI_TAG_NICHE:
            return "niche";
        default:
            return "none";
    }
}

void print_u128(const rscabi::U128 &value)
{
    if (value.hi != 0)
    {
        printf("0x%016llx%016llx", static_cast<unsigned long long>(value.hi),
               static_cast<unsigned long long>(value.lo));
    }
    else
    {
        printf("0x%llx", static_cast<unsigned long long>(value.lo));
    }
}

void print_usage()
{
    fprintf(stderr,
            "usage: rscabi_dump [--target <llvm-datalayout|x86_64|i686|aarch64>] "
            "[--target-triple <triple>] [--extern-abi <abi>] "
            "[--callconv <callconv>] [--dump-internals] --type <type-expr>\n"
            "examples:\n"
            "  rscabi_dump --type 'option(ref(u8))'\n"
            "  rscabi_dump --type 'struct(u8,u32,u64)'\n"
            "  rscabi_dump --type 'enum(unit,u8,option(u16))'\n"
            "  rscabi_dump --type 'simd(u8,16)' --dump-internals\n"
            "  rscabi_dump --type 'coroutine(async,state(u8)|state(u64))'\n"
            "  rscabi_dump --type 'u32' --target-triple 'aarch64-unknown-linux-gnu' "
            "--extern-abi aapcs\n");
}

} // namespace

int main(int argc, char **argv)
{
    std::string data_layout = kDefaultDataLayout;
    std::string type_expr;
    std::string target_triple = "x86_64-unknown-linux-gnu";
    std::string extern_abi_text = "Rust";
    std::string callconv_text;
    bool dump_internals = false;
    for (int i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "--target") == 0 && i + 1 < argc)
        {
            std::string value = argv[++i];
            if (value == "x86_64")
            {
                data_layout = kDefaultDataLayout;
            }
            else if (value == "i686")
            {
                data_layout = "e-m:e-p:32:32-i16:16:16-i32:32:32-i64:32:64-a:0:32:32";
            }
            else if (value == "aarch64")
            {
                data_layout = kDefaultDataLayout;
            }
            else
            {
                data_layout = value;
            }
        }
        else if (strcmp(argv[i], "--type") == 0 && i + 1 < argc)
        {
            type_expr = argv[++i];
        }
        else if (strcmp(argv[i], "--target-triple") == 0 && i + 1 < argc)
        {
            target_triple = argv[++i];
        }
        else if (strcmp(argv[i], "--extern-abi") == 0 && i + 1 < argc)
        {
            extern_abi_text = argv[++i];
        }
        else if (strcmp(argv[i], "--callconv") == 0 && i + 1 < argc)
        {
            callconv_text = argv[++i];
        }
        else if (strcmp(argv[i], "--dump-internals") == 0)
        {
            dump_internals = true;
        }
        else if (strcmp(argv[i], "--help") == 0)
        {
            print_usage();
            return 0;
        }
        else
        {
            print_usage();
            return 2;
        }
    }

    if (type_expr.empty())
    {
        print_usage();
        return 2;
    }

    rscabi::ExternAbi extern_abi;
    if (!rscabi::extern_abi_from_str(extern_abi_text, &extern_abi))
    {
        fprintf(stderr, "rscabi_dump: bad extern ABI: %s\n", extern_abi_text.c_str());
        return 2;
    }
    rscabi::CallingConv requested_callconv = rscabi::CallingConv::C;
    if (!callconv_text.empty() &&
        !rscabi::parse_callconv(callconv_text, &requested_callconv))
    {
        fprintf(stderr, "rscabi_dump: bad callconv: %s\n", callconv_text.c_str());
        return 2;
    }

    rscabi::TargetDataLayout target;
    if (!rscabi::parse_llvm_data_layout(data_layout, &target))
    {
        fprintf(stderr, "rscabi_dump: bad target data layout\n");
        return 2;
    }

    rscabi::TypeContext ctx(target);
    std::string error;
    Parser parser(&ctx, target, type_expr, &error);
    rscabi::AbiType *type = parser.parse();
    if (type == NULL)
    {
        fprintf(stderr, "rscabi_dump: %s\n", error.empty() ? "parse error" : error.c_str());
        return 2;
    }

    rscabi::LayoutData layout;
    if (!ctx.layout_of(type, &layout))
    {
        fprintf(stderr, "rscabi_dump: layout computation failed\n");
        return 3;
    }

    printf("rustc: 1.100.0\n");
    printf("type: %s\n", type_expr.c_str());
    printf("target_triple: %s\n", target_triple.c_str());
    printf("extern_abi: %s\n", rscabi::extern_abi_as_str(extern_abi));
    rscabi::CanonAbi canon = rscabi::canonize(extern_abi, target_triple.c_str());
    printf("canon_abi: %s\n", canon.as_str());
    rscabi::CallingConv callconv =
        callconv_text.empty() ? rscabi::callconv_for_extern(extern_abi,
                                                             target_triple.c_str())
                              : requested_callconv;
    printf("callconv: %s\n", rscabi::callconv_name(callconv));
    if (!callconv_text.empty())
    {
        printf("callconv_requested: %s\n", rscabi::callconv_name(requested_callconv));
    }
    printf("size: %llu\n", static_cast<unsigned long long>(layout.size));
    printf("align: %llu\n", static_cast<unsigned long long>(layout.align));
    printf("unadjusted_abi_align: %llu\n",
           static_cast<unsigned long long>(layout.unadjusted_abi_align));
    printf("backend: %s\n", backend_name(static_cast<uint32_t>(layout.backend)));
    printf("variants: %llu\n", static_cast<unsigned long long>(layout.variants.size()));
    printf("tag: %s\n", tag_name(static_cast<uint32_t>(layout.tag_encoding)));
    if (layout.has_niche)
    {
        printf("niche: offset=%llu range=[",
               static_cast<unsigned long long>(layout.largest_niche.offset));
        print_u128(layout.largest_niche.value.start);
        printf(", ");
        print_u128(layout.largest_niche.value.end);
        printf("]\n");
    }
    for (size_t i = 0; i < layout.field_offsets.size(); i++)
    {
        printf("field[%llu]: offset=%llu size=%llu\n",
               static_cast<unsigned long long>(i),
               static_cast<unsigned long long>(layout.field_offsets[i]),
               i < layout.field_sizes.size()
                   ? static_cast<unsigned long long>(layout.field_sizes[i])
                   : 0ULL);
    }
    for (size_t i = 0; i < layout.variants.size(); i++)
    {
        const rscabi::VariantLayout &variant = layout.variants[i];
        printf("variant[%llu]: size=%llu align=%llu tag=[",
               static_cast<unsigned long long>(i),
               static_cast<unsigned long long>(variant.size),
               static_cast<unsigned long long>(variant.align));
        print_u128(variant.tag_range.start);
        printf(", ");
        print_u128(variant.tag_range.end);
        printf("]\n");
    }

    rscabi::HomogeneousAggregate aggregate;
    if (rscabi::homogeneous_aggregate(ctx,
                                      layout,
                                      extern_abi,
                                      target_triple.c_str(),
                                      &aggregate))
    {
        if (aggregate.kind == rscabi::HomogeneousAggregateKind::NoData)
        {
            printf("aggregate: no-data\n");
        }
        else
        {
            printf("aggregate: homogeneous kind=%u size=%llu\n",
                   static_cast<uint32_t>(aggregate.reg.kind),
                   static_cast<unsigned long long>(aggregate.reg.size.bytes));
        }
    }

    if (dump_internals)
    {
        static const char *kFieldsKinds[] = {"primitive", "arbitrary", "array", "union"};
        uint32_t fields_kind = static_cast<uint32_t>(layout.fields_kind);
        printf("fields_kind: %s\n",
               fields_kind < 4 ? kFieldsKinds[fields_kind] : "unknown");

        printf("memory_order:");
        for (size_t i = 0; i < layout.in_memory_order.size(); i++)
        {
            printf(" %u", layout.in_memory_order[i]);
        }
        printf("\n");

        printf("tag_encoding: %s\n", tag_name(static_cast<uint32_t>(layout.tag_encoding)));
        printf("untagged_variant: %llu\n",
               static_cast<unsigned long long>(layout.untagged_variant));
        if (layout.tag_encoding == rscabi::TagEncodingKind::Niche)
        {
            printf("niche_variants: %llu..%llu\n",
                   static_cast<unsigned long long>(layout.niche_variants_start),
                   static_cast<unsigned long long>(layout.niche_variants_end));
            printf("niche_start: ");
            print_u128(layout.niche_start);
            printf("\n");
        }
        if (layout.has_niche)
        {
            printf("largest_niche_available: ");
            print_u128(layout.largest_niche.available());
            printf("\n");
        }
        for (size_t i = 0; i < layout.variants.size(); i++)
        {
            const rscabi::VariantLayout &variant = layout.variants[i];
            printf("variant[%llu].memory_index:", static_cast<unsigned long long>(i));
            for (size_t f = 0; f < variant.in_memory_order.size(); f++)
            {
                printf(" %u", variant.in_memory_order[f]);
            }
            printf("\n");
            printf("variant[%llu].field_offsets:", static_cast<unsigned long long>(i));
            for (size_t f = 0; f < variant.field_offsets.size(); f++)
            {
                printf(" %llu", static_cast<unsigned long long>(variant.field_offsets[f]));
            }
            printf("\n");
        }
    }
    return 0;
}
