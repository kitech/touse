#include "core.hpp"

#include <algorithm>
#include <limits>
#include <sstream>

namespace rscabi {

uint32_t max_u32(uint32_t a, uint32_t b)
{
    return a > b ? a : b;
}

uint64_t max_u64(uint64_t a, uint64_t b)
{
    return a > b ? a : b;
}

uint64_t min_u64(uint64_t a, uint64_t b)
{
    return a < b ? a : b;
}

bool bits_to_bytes(uint32_t bits, uint64_t *out)
{
    if (out == NULL)
    {
        return false;
    }
    if (bits == 0)
    {
        *out = 1;
        return true;
    }
    if ((bits % 8) != 0)
    {
        return false;
    }
    *out = bits / 8;
    return true;
}

uint64_t round_up(uint64_t value, uint64_t align)
{
    if (align <= 1)
    {
        return value;
    }
    uint64_t mask = align - 1;
    return (value + mask) & ~mask;
}

uint64_t log2_floor(uint64_t value)
{
    if (value == 0)
    {
        return 0;
    }
    return static_cast<uint64_t>(__builtin_ctzll(value));
}

U128 u128_negate(const U128 &value)
{
    return u128_add(u128_not(value), U128::from_u64(1));
}

U128 signed_abs(const U128 &value, uint32_t bits)
{
    U128 magnitude = u128_truncate(value, bits);
    if (bits == 0)
    {
        return magnitude;
    }
    U128 sign_bit = u128_shl(U128::from_u64(1), bits - 1);
    if (magnitude >= sign_bit)
    {
        return u128_truncate(u128_negate(magnitude), bits);
    }
    return magnitude;
}

uint64_t available_u64(const Niche &niche)
{
    U128 count = niche.available();
    if (count.hi != 0)
    {
        return std::numeric_limits<uint64_t>::max();
    }
    return count.lo;
}

bool parse_u64(const std::string &text, uint64_t *out)
{
    if (out == NULL || text.empty())
    {
        return false;
    }

    uint64_t value = 0;
    for (size_t i = 0; i < text.size(); i++)
    {
        char c = text[i];
        if (c < '0' || c > '9')
        {
            return false;
        }
        uint64_t digit = static_cast<uint64_t>(c - '0');
        if (value > (std::numeric_limits<uint64_t>::max() - digit) / 10)
        {
            return false;
        }
        value = value * 10 + digit;
    }
    *out = value;
    return true;
}

std::vector<std::string> split_colon(const std::string &text)
{
    std::vector<std::string> parts;
    std::string current;
    for (size_t i = 0; i < text.size(); i++)
    {
        if (text[i] == ':')
        {
            parts.push_back(current);
            current.clear();
        }
        else
        {
            current.push_back(text[i]);
        }
    }
    parts.push_back(current);
    return parts;
}

U128 add_one_truncated(const U128 &value, uint32_t bits)
{
    return u128_truncate(u128_add(value, U128::from_u64(1)), bits);
}

U128 sub_one_truncated(const U128 &value, uint32_t bits)
{
    return u128_truncate(u128_sub(value, U128::from_u64(1)), bits);
}

bool niche_better(const Niche &candidate, const Niche &current)
{
    return candidate.available() > current.available();
}

struct FieldSortKey
{
    uint64_t group;
    uint64_t niche_key;
    uint64_t inner_key;
    uint32_t index;

    FieldSortKey() : group(0), niche_key(0), inner_key(0), index(0) {}
};

uint64_t alignment_group_key(const LayoutData &field,
                             uint64_t max_field_align,
                             uint64_t largest_niche_size,
                             uint64_t pack_bytes,
                             NicheBias bias)
{
    if (pack_bytes != 0)
    {
        return min_u64(field.align, pack_bytes);
    }
    uint64_t align = field.align == 0 ? 1 : field.align;
    uint64_t size = field.size;
    uint64_t key = log2_floor(max_u64(align, size));
    if (largest_niche_size != 0 && field.has_niche)
    {
        uint64_t niche_size = available_u64(field.largest_niche);
        if (bias == NicheBias::Start)
        {
            key = min_u64(log2_floor(max_field_align), key);
        }
        else if (niche_size == largest_niche_size)
        {
            key = log2_floor(align);
        }
    }
    return key;
}

FieldSortKey field_sort_key(const LayoutData &field,
                            uint32_t index,
                            uint64_t max_field_align,
                            uint64_t largest_niche_size,
                            uint64_t pack_bytes,
                            NicheBias bias,
                            StructKind kind)
{
    FieldSortKey key;
    key.index = index;
    key.group = alignment_group_key(field, max_field_align, largest_niche_size, pack_bytes, bias);
    uint64_t available = field.has_niche ? available_u64(field.largest_niche) : 0;
    uint64_t niche_bytes = field.has_niche
                               ? static_cast<uint64_t>(Size::from_bits(field.largest_niche.bits).bytes)
                               : 0;
    if (kind == StructKind::Prefixed)
    {
        key.niche_key = available;
    }
    else if (bias == NicheBias::Start)
    {
        key.niche_key = ~available;
        key.inner_key = field.has_niche ? field.largest_niche.offset : 0;
    }
    else
    {
        key.niche_key = available;
        if (field.has_niche)
        {
            uint64_t tail = field.size >= niche_bytes + field.largest_niche.offset
                                ? field.size - niche_bytes - field.largest_niche.offset
                                : 0;
            key.inner_key = ~tail;
        }
    }
    return key;
}

bool field_key_less(const FieldSortKey &a, const FieldSortKey &b, bool reverse_group)
{
    if (a.group != b.group)
    {
        return reverse_group ? a.group > b.group : a.group < b.group;
    }
    if (a.niche_key != b.niche_key)
    {
        return a.niche_key < b.niche_key;
    }
    if (a.inner_key != b.inner_key)
    {
        return a.inner_key < b.inner_key;
    }
    return a.index < b.index;
}

Scalar tag_scalar_from_range(uint32_t bits, const WrappingRange &valid)
{
    Scalar scalar;
    scalar.primitive = PrimitiveKind::Int;
    scalar.bits = bits;
    scalar.is_signed = false;
    scalar.valid = valid;
    return scalar;
}

void copy_variant_layout(const LayoutData &layout, VariantLayout *out)
{
    out->size = layout.size;
    out->align = layout.align;
    out->unadjusted_abi_align = layout.unadjusted_abi_align;
    out->backend = layout.backend;
    out->field_offsets = layout.field_offsets;
    out->field_sizes = layout.field_sizes;
    out->in_memory_order = layout.in_memory_order;
    out->has_niche = layout.has_niche;
    out->largest_niche = layout.largest_niche;
    out->has_tag_range = false;
    out->tag_range = WrappingRange();
    out->uninhabited = layout.uninhabited;
}

StructKindSpec StructKindSpec::always()
{
    StructKindSpec spec;
    spec.kind = StructKind::AlwaysSized;
    return spec;
}

StructKindSpec StructKindSpec::maybe_unsized()
{
    StructKindSpec spec;
    spec.kind = StructKind::MaybeUnsized;
    return spec;
}

StructKindSpec StructKindSpec::prefixed(uint64_t size, uint64_t align)
{
    StructKindSpec spec;
    spec.kind = StructKind::Prefixed;
    spec.prefix_size = size;
    spec.prefix_align = align == 0 ? 1 : align;
    return spec;
}

WrappingRange WrappingRange::with_start(const WrappingRange &range, const U128 &start)
{
    return WrappingRange(start, range.end);
}

WrappingRange WrappingRange::with_end(const WrappingRange &range, const U128 &end)
{
    return WrappingRange(range.start, end);
}

U128 WrappingRange::count(uint32_t bits) const
{
    U128 max = u128_unsigned_max(bits);
    if (is_full(bits))
    {
        return max;
    }
    U128 result;
    if (start <= end)
    {
        result = add_one_truncated(u128_sub(end, start), bits);
    }
    else
    {
        U128 tail = add_one_truncated(u128_sub(max, start), bits);
        U128 head = add_one_truncated(end, bits);
        result = u128_add(tail, head);
    }
    return u128_truncate(result, bits);
}

uint32_t WrappingRange::available_log2(uint32_t bits) const
{
    U128 count = this->count(bits);
    if (count.is_zero() || count.is_one())
    {
        return 0;
    }
    return u128_bit_length(u128_sub(count, U128::from_u64(1)));
}

U128 Niche::available() const
{
    return value.count(bits);
}

uint64_t Niche::value_size_bytes() const
{
    return Size::from_bits(bits).bytes;
}

bool Niche::reserve(const U128 &count, U128 *niche_start, WrappingRange *new_valid) const
{
    if (niche_start == NULL || new_valid == NULL || bits == 0 || bits > 128 || count.is_zero())
    {
        return false;
    }
    U128 max = u128_unsigned_max(bits);
    U128 one = U128::from_u64(1);
    WrappingRange valid = valid_complement_niche(value, bits);
    U128 available = u128_truncate(u128_sub(u128_sub(valid.start, valid.end), one), bits);
    if (count > available)
    {
        return false;
    }

    bool move_start;
    if (count == one && !(valid.start.is_zero() && valid.end == one))
    {
        U128 next_up = signed_abs(u128_add(valid.end, one), bits);
        U128 next_down = signed_abs(u128_sub(valid.start, one), bits);
        move_start = next_down <= next_up;
    }
    else if (valid.start > valid.end)
    {
        move_start = false;
    }
    else
    {
        U128 distance_end_zero = u128_sub(max, valid.end);
        if (valid.start <= distance_end_zero)
        {
            move_start = count <= valid.start;
        }
        else
        {
            U128 moved_end = u128_truncate(u128_add(valid.end, count), bits);
            move_start = moved_end >= one && moved_end <= valid.end;
        }
    }

    if (move_start)
    {
        U128 start = u128_truncate(u128_sub(valid.start, count), bits);
        *niche_start = start;
        *new_valid = WrappingRange::with_start(valid, start);
    }
    else
    {
        U128 start = u128_truncate(u128_add(valid.end, one), bits);
        U128 end = u128_truncate(u128_add(valid.end, count), bits);
        *niche_start = start;
        *new_valid = WrappingRange::with_end(valid, end);
    }
    return true;
}

bool Niche::from_scalar(uint64_t offset, const Scalar &scalar, Niche *out)
{
    if (out == NULL || scalar.bits == 0 || scalar.bits > 128)
    {
        return false;
    }
    WrappingRange invalid = valid_complement_niche(scalar.valid, scalar.bits);
    Niche niche(offset, invalid, scalar.bits);
    if (niche.available().is_zero())
    {
        return false;
    }
    *out = niche;
    return true;
}

Align Align::max_aligned_factor(uint64_t size)
{
    return Align(static_cast<uint8_t>(log2_floor(size)));
}

Size Size::from_bits(uint64_t bits)
{
    return Size(bits == 0 ? 0 : (bits + 7) / 8);
}

Size Size::from_bytes(uint64_t bytes)
{
    return Size(bytes);
}

uint64_t Size::bits() const
{
    return bytes * 8;
}

Size Size::align_to(const Align &align) const
{
    return Size(round_up(bytes, align.bytes()));
}

bool Size::checked_add(const Size &other, Size *out) const
{
    if (out == NULL || bytes > std::numeric_limits<uint64_t>::max() - other.bytes)
    {
        return false;
    }
    *out = Size(bytes + other.bytes);
    return true;
}

bool Size::checked_mul(uint64_t count, Size *out) const
{
    if (out == NULL || (bytes != 0 && count > std::numeric_limits<uint64_t>::max() / bytes))
    {
        return false;
    }
    *out = Size(bytes * count);
    return true;
}

Align Align::one()
{
    return Align(0);
}

bool Align::from_bytes(uint64_t bytes, Align *out)
{
    if (out == NULL)
    {
        return false;
    }
    if (bytes <= 1)
    {
        *out = Align::one();
        return true;
    }
    if ((bytes & (bytes - 1)) != 0 || bytes > (static_cast<uint64_t>(1) << 29))
    {
        return false;
    }
    uint8_t pow = 0;
    uint64_t value = bytes;
    while (value > 1)
    {
        value >>= 1;
        pow++;
    }
    *out = Align(pow);
    return true;
}

Align Align::max_for_target(uint64_t pointer_bits)
{
    uint32_t pow = pointer_bits > 1 ? static_cast<uint32_t>(pointer_bits - 1) : 0;
    if (pow > 29)
    {
        pow = 29;
    }
    return Align(static_cast<uint8_t>(pow));
}

uint64_t Align::bytes() const
{
    return static_cast<uint64_t>(1) << pow2;
}

uint64_t Align::bits() const
{
    return bytes() * 8;
}

Size Align::align_size(const Size &size) const
{
    return size.align_to(*this);
}

U128 U128::from_u64(uint64_t value)
{
    return U128(value, 0);
}

U128 U128::from_u32(uint32_t value)
{
    return U128(static_cast<uint64_t>(value), 0);
}

bool U128::is_zero() const
{
    return lo == 0 && hi == 0;
}

bool U128::is_one() const
{
    return lo == 1 && hi == 0;
}

bool operator==(const U128 &a, const U128 &b)
{
    return a.lo == b.lo && a.hi == b.hi;
}

bool operator!=(const U128 &a, const U128 &b)
{
    return !(a == b);
}

bool operator<(const U128 &a, const U128 &b)
{
    if (a.hi != b.hi)
    {
        return a.hi < b.hi;
    }
    return a.lo < b.lo;
}

bool operator<=(const U128 &a, const U128 &b)
{
    return a < b || a == b;
}

bool operator>(const U128 &a, const U128 &b)
{
    return b < a;
}

bool operator>=(const U128 &a, const U128 &b)
{
    return b <= a;
}

U128 u128_add(const U128 &a, const U128 &b)
{
    uint64_t lo = a.lo + b.lo;
    uint64_t carry = lo < a.lo ? 1 : 0;
    return U128(lo, a.hi + b.hi + carry);
}

U128 u128_sub(const U128 &a, const U128 &b)
{
    uint64_t borrow = a.lo < b.lo ? 1 : 0;
    return U128(a.lo - b.lo, a.hi - b.hi - borrow);
}

U128 u128_and(const U128 &a, const U128 &b)
{
    return U128(a.lo & b.lo, a.hi & b.hi);
}

U128 u128_or(const U128 &a, const U128 &b)
{
    return U128(a.lo | b.lo, a.hi | b.hi);
}

U128 u128_not(const U128 &a)
{
    return U128(~a.lo, ~a.hi);
}

U128 u128_shl(const U128 &a, uint32_t bits)
{
    if (bits == 0)
    {
        return a;
    }
    if (bits < 64)
    {
        return U128(a.lo << bits, (a.hi << bits) | (a.lo >> (64 - bits)));
    }
    if (bits < 128)
    {
        return U128(0, a.lo << (bits - 64));
    }
    return U128();
}

U128 u128_shr(const U128 &a, uint32_t bits)
{
    if (bits == 0)
    {
        return a;
    }
    if (bits < 64)
    {
        return U128((a.lo >> bits) | (a.hi << (64 - bits)), a.hi >> bits);
    }
    if (bits < 128)
    {
        return U128(a.hi >> (bits - 64), 0);
    }
    return U128();
}

U128 u128_truncate(const U128 &a, uint32_t bits)
{
    return u128_and(a, u128_unsigned_max(bits));
}

U128 u128_unsigned_max(uint32_t bits)
{
    if (bits == 0)
    {
        return U128();
    }
    if (bits >= 128)
    {
        return U128(std::numeric_limits<uint64_t>::max(),
                    std::numeric_limits<uint64_t>::max());
    }
    if (bits == 64)
    {
        return U128(std::numeric_limits<uint64_t>::max(), 0);
    }
    if (bits < 64)
    {
        return U128((static_cast<uint64_t>(1) << bits) - 1, 0);
    }
    return U128(std::numeric_limits<uint64_t>::max(),
                (static_cast<uint64_t>(1) << (bits - 64)) - 1);
}

uint32_t u128_bit_length(const U128 &a)
{
    for (uint32_t i = 128; i > 0; i--)
    {
        if (!u128_shr(a, i - 1).is_zero())
        {
            return i;
        }
    }
    return 0;
}

U128 u128_from_c(uint64_t lo, uint64_t hi)
{
    return U128(lo, hi);
}

WrappingRange WrappingRange::full(uint32_t bits)
{
    return WrappingRange(U128(), u128_unsigned_max(bits));
}

WrappingRange WrappingRange::from_bounds(uint64_t start, uint64_t end)
{
    return WrappingRange(U128::from_u64(start), U128::from_u64(end));
}

bool WrappingRange::is_full(uint32_t bits) const
{
    return start.is_zero() && end == u128_unsigned_max(bits);
}

bool WrappingRange::is_empty_marker() const
{
    return start.is_one() && end.is_zero();
}

bool WrappingRange::contains(const U128 &value) const
{
    if (start <= end)
    {
        return value >= start && value <= end;
    }
    return value >= start || value <= end;
}

uint32_t range_bits(const WrappingRange &range)
{
    uint32_t bits = max_u32(u128_bit_length(range.start), u128_bit_length(range.end));
    if (bits <= 8)
    {
        return 8;
    }
    if (bits <= 16)
    {
        return 16;
    }
    if (bits <= 32)
    {
        return 32;
    }
    if (bits <= 64)
    {
        return 64;
    }
    return 128;
}

WrappingRange valid_complement_niche(const WrappingRange &valid, uint32_t bits)
{
    if (valid.is_full(bits))
    {
        return WrappingRange(U128::from_u64(1), U128());
    }
    return WrappingRange(add_one_truncated(valid.end, bits),
                         sub_one_truncated(valid.start, bits));
}

WrappingRange smallest_range_containing(const std::vector<U128> &values, uint32_t bits)
{
    if (values.empty())
    {
        return WrappingRange::full(bits);
    }
    U128 low = u128_truncate(values[0], bits);
    U128 high = low;
    for (size_t i = 1; i < values.size(); i++)
    {
        U128 value = u128_truncate(values[i], bits);
        if (value < low)
        {
            low = value;
        }
        if (value > high)
        {
            high = value;
        }
    }
    return WrappingRange(low, high);
}

bool ReprOptions::inhibit_enum_layout_opt() const
{
    return is_c || int_bits != 0;
}

bool ReprOptions::inhibit_field_reorder() const
{
    return is_c || is_packed || is_simd || is_scalable || int_bits != 0;
}

Align TargetDataLayout::integer_align(uint32_t bits) const
{
    uint32_t align_bits = aggregate_align_bits;
    if (bits <= 8)
    {
        align_bits = 8;
    }
    else if (bits == 16)
    {
        align_bits = i16_align_bits;
    }
    else if (bits == 32)
    {
        align_bits = i32_align_bits;
    }
    else if (bits == 64)
    {
        align_bits = i64_align_bits;
    }
    else if (bits >= 128)
    {
        align_bits = i128_align_bits;
    }
    Align align;
    uint64_t bytes = 0;
    if (!bits_to_bytes(align_bits, &bytes) || !Align::from_bytes(bytes, &align))
    {
        return Align::one();
    }
    return align;
}

Align TargetDataLayout::pointer_align() const
{
    Align align;
    uint64_t bytes = 0;
    if (!bits_to_bytes(pointer_align_bits, &bytes) || !Align::from_bytes(bytes, &align))
    {
        return Align::one();
    }
    return align;
}

uint64_t TargetDataLayout::rust_vector_align_bytes(uint64_t size) const
{
    std::map<uint64_t, uint64_t>::const_iterator it = vector_align_bits.find(size);
    if (it != vector_align_bits.end() && it->second != 0)
    {
        return it->second / 8;
    }
    if (size == 0)
    {
        return 1;
    }
    uint64_t alignment = 1;
    while (alignment < size)
    {
        alignment <<= 1;
    }
    return alignment;
}

bool parse_llvm_data_layout(const std::string &input, TargetDataLayout *out)
{
    if (out == NULL)
    {
        return false;
    }

    TargetDataLayout target;
    bool saw_default_pointer = false;
    uint64_t fallback_pointer_bits = 0;
    uint64_t fallback_pointer_align_bits = 0;

    std::stringstream stream(input);
    std::string token;
    while (std::getline(stream, token, '-'))
    {
        std::vector<std::string> parts = split_colon(token);
        if (parts.empty())
        {
            continue;
        }
        const std::string &head = parts[0];

        if (head == "e")
        {
            target.little_endian = true;
            continue;
        }
        if (head == "E")
        {
            target.little_endian = false;
            continue;
        }

        if (!head.empty() && head[0] == 'p')
        {
            if (parts.size() < 3)
            {
                continue;
            }
            uint64_t pointer_bits = 0;
            uint64_t pointer_align_bits = 0;
            if (!parse_u64(parts[1], &pointer_bits) ||
                !parse_u64(parts[2], &pointer_align_bits))
            {
                continue;
            }
            bool is_default = head == "p" || head == "p0";
            if (!saw_default_pointer && pointer_bits > fallback_pointer_bits)
            {
                fallback_pointer_bits = pointer_bits;
                fallback_pointer_align_bits = pointer_align_bits;
            }
            if (is_default)
            {
                saw_default_pointer = true;
                target.pointer_bits = static_cast<uint32_t>(pointer_bits);
                target.pointer_align_bits = static_cast<uint32_t>(pointer_align_bits);
                target.usize_bits = static_cast<uint32_t>(pointer_bits);
            }
            continue;
        }

        if (!head.empty() && head[0] == 'v')
        {
            if (parts.size() < 3)
            {
                continue;
            }
            uint64_t vector_bits = 0;
            uint64_t vector_align_bits = 0;
            if (parse_u64(head.substr(1), &vector_bits) && parse_u64(parts[1], &vector_align_bits))
            {
                target.vector_align_bits[vector_bits / 8] = vector_align_bits;
            }
            continue;
        }

        if (!head.empty() && head[0] == 'i')
        {
            if (parts.size() < 2)
            {
                continue;
            }
            uint64_t bits = 0;
            uint64_t align_bits = 0;
            if (!parse_u64(head.substr(1), &bits) || !parse_u64(parts[1], &align_bits))
            {
                continue;
            }
            if (bits == 16)
            {
                target.i16_align_bits = static_cast<uint32_t>(align_bits);
            }
            else if (bits == 32)
            {
                target.i32_align_bits = static_cast<uint32_t>(align_bits);
            }
            else if (bits == 64)
            {
                target.i64_align_bits = static_cast<uint32_t>(align_bits);
            }
            else if (bits >= 128)
            {
                target.i128_align_bits = static_cast<uint32_t>(align_bits);
            }
            continue;
        }

        if (head == "a" && parts.size() >= 2)
        {
            uint64_t align_bits = 0;
            if (parse_u64(parts[1], &align_bits))
            {
                target.aggregate_align_bits = static_cast<uint32_t>(align_bits);
            }
        }
    }

    if (!saw_default_pointer && fallback_pointer_bits != 0)
    {
        target.pointer_bits = static_cast<uint32_t>(fallback_pointer_bits);
        target.pointer_align_bits = static_cast<uint32_t>(fallback_pointer_align_bits);
        target.usize_bits = static_cast<uint32_t>(fallback_pointer_bits);
    }

    *out = target;
    return true;
}

LayoutCalculator::LayoutCalculator(const TargetDataLayout &target)
    : target_(target)
{
}

bool LayoutCalculator::layout_scalar(const Scalar &scalar, LayoutData *out) const
{
    if (out == NULL)
    {
        return false;
    }

    uint32_t bits = scalar.bits;
    Align align = target_.integer_align(bits);
    switch (scalar.primitive)
    {
        case PrimitiveKind::Bool:
            bits = 8;
            align = Align::one();
            break;
        case PrimitiveKind::Char:
            bits = 32;
            align = target_.integer_align(32);
            break;
        case PrimitiveKind::Int:
            align = target_.integer_align(bits);
            break;
        case PrimitiveKind::Float:
            align = target_.integer_align(bits);
            break;
        case PrimitiveKind::Pointer:
        case PrimitiveKind::FnPointer:
            bits = target_.pointer_bits;
            align = target_.pointer_align();
            break;
        default:
            return false;
    }

    if (bits == 0 || bits > 128)
    {
        return false;
    }

    Scalar normalized = scalar;
    normalized.bits = bits;
    *out = LayoutData();
    out->size = Size::from_bits(bits).bytes;
    out->align = align.bytes();
    out->unadjusted_abi_align = align.bytes();
    out->backend = BackendReprKind::Scalar;
    out->fields_kind = FieldsShapeKind::Primitive;
    out->variants_kind = VariantsKind::Single;
    out->has_tag_scalar = true;
    out->tag_scalar = normalized;
    Niche niche;
    if (Niche::from_scalar(0, normalized, &niche))
    {
        out->has_niche = true;
        out->largest_niche = niche;
    }
    return true;
}

bool LayoutCalculator::layout_never(LayoutData *out) const
{
    if (out == NULL)
    {
        return false;
    }
    *out = LayoutData();
    out->uninhabited = true;
    out->variants_kind = VariantsKind::Empty;
    return true;
}

bool LayoutCalculator::layout_unit(LayoutData *out) const
{
    if (out == NULL)
    {
        return false;
    }
    *out = LayoutData();
    out->variants_kind = VariantsKind::Single;
    return true;
}

bool LayoutCalculator::layout_array(const LayoutData &element,
                                    uint64_t count,
                                    LayoutData *out) const
{
    if (out == NULL)
    {
        return false;
    }
    Size size;
    if (!Size(element.size).checked_mul(count, &size))
    {
        return false;
    }

    *out = element;
    out->size = size.bytes;
    out->backend = BackendReprKind::Memory;
    out->fields_kind = FieldsShapeKind::Array;
    out->field_offsets.clear();
    out->field_sizes.clear();
    out->in_memory_order.clear();
    if (count > 0)
    {
        out->field_offsets.push_back(0);
        out->field_sizes.push_back(element.size);
        out->in_memory_order.push_back(0);
    }
    out->uninhabited = element.uninhabited && count != 0;
    if (count != 1)
    {
        out->has_niche = false;
        out->largest_niche = Niche();
    }
    return true;
}

bool LayoutCalculator::univariant_biased(const std::vector<LayoutData> &fields,
                                         const ReprOptions &repr,
                                         const StructKindSpec &kind,
                                         NicheBias bias,
                                         LayoutData *out) const
{
    if (out == NULL)
    {
        return false;
    }

    uint64_t aggregate_align_bytes = 0;
    uint64_t pack_bytes = 0;
    uint64_t repr_align_bytes = 0;
    if (!bits_to_bytes(target_.aggregate_align_bits, &aggregate_align_bytes))
    {
        return false;
    }
    if (repr.pack_bits != 0 && !bits_to_bytes(repr.pack_bits, &pack_bytes))
    {
        return false;
    }
    if (repr.align_bits != 0 && !bits_to_bytes(repr.align_bits, &repr_align_bytes))
    {
        return false;
    }

    std::vector<uint32_t> order(fields.size());
    for (uint32_t i = 0; i < static_cast<uint32_t>(fields.size()); i++)
    {
        order[i] = i;
    }

    if (!repr.inhibit_field_reorder() && fields.size() > 1)
    {
        uint64_t max_field_align = 1;
        uint64_t largest_niche_size = 0;
        for (size_t i = 0; i < fields.size(); i++)
        {
            max_field_align = max_u64(max_field_align, fields[i].align);
            if (fields[i].has_niche)
            {
                largest_niche_size = max_u64(largest_niche_size, available_u64(fields[i].largest_niche));
            }
        }
        std::vector<FieldSortKey> keys(fields.size());
        for (size_t i = 0; i < fields.size(); i++)
        {
            keys[i] = field_sort_key(fields[i], static_cast<uint32_t>(i), max_field_align,
                                     largest_niche_size, pack_bytes, bias, kind.kind);
        }
        bool reverse_group = kind.kind != StructKind::Prefixed;
        std::stable_sort(order.begin(), order.end(), [&](uint32_t a, uint32_t b)
        {
            return field_key_less(keys[a], keys[b], reverse_group);
        });
    }

    uint64_t align_bytes = pack_bytes != 0 ? 1 : aggregate_align_bytes;
    uint64_t offset = 0;
    if (kind.kind == StructKind::Prefixed)
    {
        uint64_t prefix_align = kind.prefix_align;
        if (pack_bytes != 0)
        {
            prefix_align = min_u64(prefix_align, pack_bytes);
        }
        align_bytes = max_u64(align_bytes, prefix_align);
        offset = round_up(kind.prefix_size, prefix_align == 0 ? 1 : prefix_align);
    }

    std::vector<uint64_t> offsets(fields.size(), 0);
    bool has_niche = false;
    Niche largest_niche;
    size_t non_zst_count = 0;
    size_t non_zst_index = 0;

    for (size_t i = 0; i < order.size(); i++)
    {
        uint32_t index = order[i];
        const LayoutData &field = fields[index];
        uint64_t field_align = field.align == 0 ? 1 : field.align;
        if (pack_bytes != 0)
        {
            field_align = min_u64(field_align, pack_bytes);
        }
        offset = round_up(offset, field_align);
        align_bytes = max_u64(align_bytes, field_align);
        offsets[index] = offset;

        if (field.size != 0)
        {
            non_zst_count++;
            non_zst_index = index;
        }

        if (field.has_niche)
        {
            uint64_t available = available_u64(field.largest_niche);
            bool prefer = !has_niche;
            if (has_niche)
            {
                uint64_t current = available_u64(largest_niche);
                prefer = bias == NicheBias::Start ? available > current : available >= current;
            }
            if (prefer)
            {
                has_niche = true;
                largest_niche = field.largest_niche;
                largest_niche.offset += offset;
            }
        }

        Size next;
        if (!Size(offset).checked_add(Size(field.size), &next))
        {
            return false;
        }
        offset = next.bytes;
    }

    uint64_t unadjusted_abi_align = align_bytes;
    if (repr_align_bytes != 0)
    {
        align_bytes = max_u64(align_bytes, repr_align_bytes);
    }
    uint64_t size = round_up(offset, align_bytes);

    *out = LayoutData();
    out->field_offsets = offsets;
    out->field_sizes.reserve(fields.size());
    for (size_t i = 0; i < fields.size(); i++)
    {
        out->field_sizes.push_back(fields[i].size);
    }
    out->in_memory_order = order;
    out->size = size;
    out->align = align_bytes;
    out->unadjusted_abi_align = unadjusted_abi_align;
    out->max_repr_align = repr_align_bytes;
    out->backend = BackendReprKind::Memory;
    out->fields_kind = FieldsShapeKind::Arbitrary;
    out->variants_kind = VariantsKind::Single;
    out->uninhabited = false;
    for (size_t i = 0; i < fields.size(); i++)
    {
        if (fields[i].uninhabited)
        {
            out->uninhabited = true;
            break;
        }
    }
    out->has_niche = has_niche;
    out->largest_niche = largest_niche;

    if (repr.is_transparent)
    {
        out->unadjusted_abi_align = non_zst_count == 1
                                        ? fields[non_zst_index].unadjusted_abi_align
                                        : align_bytes;
    }

    if (size != 0 && non_zst_count == 1)
    {
        const LayoutData &field = fields[non_zst_index];
        if (offsets[non_zst_index] == 0 && align_bytes == field.align && size == field.size)
        {
            if (field.backend == BackendReprKind::ScalarPair ||
                ((field.backend == BackendReprKind::Scalar ||
                  field.backend == BackendReprKind::SimdVector) && !repr.is_c))
            {
                out->backend = field.backend;
            }
        }
    }
    return true;
}

bool LayoutCalculator::univariant(const std::vector<LayoutData> &fields,
                                  const ReprOptions &repr,
                                  const StructKindSpec &kind,
                                  LayoutData *out) const
{
    if (out == NULL)
    {
        return false;
    }
    LayoutData layout;
    if (!univariant_biased(fields, repr, kind, NicheBias::Start, &layout))
    {
        return false;
    }
    if (kind.kind == StructKind::MaybeUnsized || fields.size() <= 1 || !layout.has_niche)
    {
        *out = layout;
        return true;
    }

    uint64_t niche_bytes = layout.largest_niche.value_size_bytes();
    uint64_t head_space = layout.largest_niche.offset;
    uint64_t tail_space = layout.size >= head_space + niche_bytes
                              ? layout.size - head_space - niche_bytes
                              : 0;
    if (head_space == 0 || tail_space == 0)
    {
        *out = layout;
        return true;
    }

    LayoutData alternate;
    if (!univariant_biased(fields, repr, kind, NicheBias::End, &alternate) ||
        !alternate.has_niche || alternate.size != layout.size)
    {
        *out = layout;
        return true;
    }
    uint64_t alternate_head = alternate.largest_niche.offset;
    if (alternate_head > head_space && alternate_head > tail_space)
    {
        *out = alternate;
    }
    else
    {
        *out = layout;
    }
    return true;
}

bool LayoutCalculator::layout_univariant(const std::vector<LayoutData> &fields,
                                         const ReprOptions &repr,
                                         LayoutData *out) const
{
    return univariant(fields, repr, StructKindSpec::always(), out);
}

bool LayoutCalculator::layout_union(const std::vector<LayoutData> &fields,
                                    const ReprOptions &repr,
                                    LayoutData *out) const
{
    if (out == NULL)
    {
        return false;
    }

    uint64_t size = 0;
    uint64_t align_bytes = 0;
    uint64_t pack_bytes = 0;
    uint64_t repr_align_bytes = 0;
    if (!bits_to_bytes(target_.aggregate_align_bits, &align_bytes))
    {
        return false;
    }
    if (repr.pack_bits != 0 && !bits_to_bytes(repr.pack_bits, &pack_bytes))
    {
        return false;
    }
    if (repr.align_bits != 0 && !bits_to_bytes(repr.align_bits, &repr_align_bytes))
    {
        return false;
    }

    for (size_t i = 0; i < fields.size(); i++)
    {
        size = max_u64(size, fields[i].size);
        align_bytes = max_u64(align_bytes, fields[i].align);
    }
    if (pack_bytes != 0)
    {
        align_bytes = pack_bytes;
    }
    if (repr_align_bytes != 0)
    {
        align_bytes = max_u64(align_bytes, repr_align_bytes);
    }

    *out = LayoutData();
    out->size = round_up(size, align_bytes);
    out->align = align_bytes;
    out->unadjusted_abi_align = align_bytes;
    out->max_repr_align = repr_align_bytes;
    out->backend = BackendReprKind::Memory;
    out->fields_kind = FieldsShapeKind::Union;
    out->field_offsets.assign(fields.size(), 0);
    out->field_sizes.reserve(fields.size());
    out->in_memory_order.reserve(fields.size());
    for (size_t i = 0; i < fields.size(); i++)
    {
        out->field_sizes.push_back(fields[i].size);
        out->in_memory_order.push_back(static_cast<uint32_t>(i));
    }
    out->variants_kind = VariantsKind::Single;
    return true;
}

uint32_t LayoutCalculator::integer_for_align(uint64_t align_bytes) const
{
    static const uint32_t candidates[] = {8, 16, 32, 64, 128};
    for (size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++)
    {
        uint32_t bits = candidates[i];
        if (bits / 8 == align_bytes && target_.integer_align(bits).bytes() == align_bytes)
        {
            return bits;
        }
    }
    return 0;
}

uint32_t LayoutCalculator::discriminant_bits(const std::vector<U128> &discriminants,
                                             const ReprOptions &repr) const
{
    if (repr.int_bits != 0)
    {
        return repr.int_bits;
    }
    if (repr.is_c)
    {
        return target_.c_enum_min_bits;
    }

    U128 max_value;
    for (size_t i = 0; i < discriminants.size(); i++)
    {
        if (discriminants[i] > max_value)
        {
            max_value = discriminants[i];
        }
    }
    if (max_value.hi != 0)
    {
        return 128;
    }
    if (max_value.lo <= 0xffULL)
    {
        return 8;
    }
    if (max_value.lo <= 0xffffULL)
    {
        return 16;
    }
    if (max_value.lo <= 0xffffffffULL)
    {
        return 32;
    }
    return 64;
}

bool LayoutCalculator::layout_tagged_enum(const std::vector<std::vector<LayoutData> > &variants,
                                          const std::vector<U128> &discriminants,
                                          const ReprOptions &repr,
                                          LayoutData *out) const
{
    if (out == NULL || variants.empty())
    {
        return false;
    }

    uint32_t min_bits = discriminant_bits(discriminants, repr);
    uint64_t min_tag_size = Size::from_bits(min_bits).bytes;
    uint64_t prefix_align_bytes = target_.integer_align(min_bits).bytes();
    if (repr.is_c)
    {
        for (size_t v = 0; v < variants.size(); v++)
        {
            for (size_t f = 0; f < variants[v].size(); f++)
            {
                prefix_align_bytes = max_u64(prefix_align_bytes, variants[v][f].align);
            }
        }
    }

    StructKindSpec prefixed = StructKindSpec::prefixed(min_tag_size, prefix_align_bytes);
    uint64_t start_align_bytes = 256;
    std::vector<LayoutData> variant_layouts(variants.size());
    for (size_t v = 0; v < variants.size(); v++)
    {
        if (!univariant(variants[v], repr, prefixed, &variant_layouts[v]))
        {
            return false;
        }
        for (size_t f = 0; f < variants[v].size(); f++)
        {
            const LayoutData &field = variants[v][f];
            if (field.size == 0 && field.align == 1)
            {
                continue;
            }
            start_align_bytes = min_u64(start_align_bytes, field.align);
            break;
        }
    }

    uint32_t tag_bits = min_bits;
    if (!repr.is_c && repr.int_bits == 0)
    {
        uint32_t aligned_bits = integer_for_align(start_align_bytes);
        if (aligned_bits != 0 && aligned_bits > min_bits)
        {
            tag_bits = aligned_bits;
        }
    }
    uint64_t tag_size = Size::from_bits(tag_bits).bytes;
    if (tag_size != min_tag_size)
    {
        for (size_t v = 0; v < variant_layouts.size(); v++)
        {
            for (size_t f = 0; f < variant_layouts[v].field_offsets.size(); f++)
            {
                uint64_t offset = variant_layouts[v].field_offsets[f];
                if (offset != 0 && offset <= min_tag_size)
                {
                    variant_layouts[v].field_offsets[f] = tag_size;
                }
            }
            if (variant_layouts[v].size <= min_tag_size)
            {
                variant_layouts[v].size = tag_size;
            }
        }
    }

    uint64_t total_size = 0;
    uint64_t total_align_bytes = target_.integer_align(tag_bits).bytes();
    std::vector<VariantLayout> final_variants;
    for (size_t v = 0; v < variant_layouts.size(); v++)
    {
        VariantLayout info;
        copy_variant_layout(variant_layouts[v], &info);
        U128 tag = v < discriminants.size() ? discriminants[v] : U128::from_u64(v);
        tag = u128_truncate(tag, tag_bits);
        info.has_tag_range = true;
        info.tag_range = WrappingRange(tag, tag);
        total_size = max_u64(total_size, variant_layouts[v].size);
        total_align_bytes = max_u64(total_align_bytes, variant_layouts[v].align);
        final_variants.push_back(info);
    }
    total_size = round_up(total_size, total_align_bytes);

    Scalar tag_scalar;
    tag_scalar.primitive = PrimitiveKind::Int;
    tag_scalar.bits = tag_bits;
    tag_scalar.is_signed = false;
    tag_scalar.valid = smallest_range_containing(discriminants, tag_bits);
    Niche tag_niche;
    bool has_tag_niche = Niche::from_scalar(0, tag_scalar, &tag_niche);

    *out = LayoutData();
    out->size = total_size;
    out->align = total_align_bytes;
    out->unadjusted_abi_align = total_align_bytes;
    out->backend = total_size == tag_size ? BackendReprKind::Scalar : BackendReprKind::Memory;
    out->fields_kind = FieldsShapeKind::Arbitrary;
    out->field_offsets.push_back(0);
    out->field_sizes.push_back(tag_size);
    out->in_memory_order.push_back(0);
    out->variants_kind = VariantsKind::Multiple;
    out->tag_encoding = TagEncodingKind::Direct;
    out->tag_bits = tag_bits;
    out->has_tag_scalar = true;
    out->tag_scalar = tag_scalar;
    out->variants = final_variants;
    if (has_tag_niche)
    {
        out->has_niche = true;
        out->largest_niche = tag_niche;
    }
    return true;
}

bool LayoutCalculator::layout_niche_enum(const std::vector<std::vector<LayoutData> > &variants,
                                         const std::vector<U128> &discriminants,
                                         const ReprOptions &repr,
                                         LayoutData *out) const
{
    (void)discriminants;
    if (out == NULL || repr.inhibit_enum_layout_opt() || variants.size() < 2)
    {
        return false;
    }

    uint64_t total_align_bytes = 0;
    if (!bits_to_bytes(target_.aggregate_align_bits, &total_align_bytes))
    {
        return false;
    }
    std::vector<LayoutData> variant_layouts(variants.size());
    std::vector<VariantLayout> final_variants(variants.size());
    for (size_t v = 0; v < variants.size(); v++)
    {
        if (!univariant(variants[v], repr, StructKindSpec::always(), &variant_layouts[v]))
        {
            return false;
        }
        copy_variant_layout(variant_layouts[v], &final_variants[v]);
        total_align_bytes = max_u64(total_align_bytes, variant_layouts[v].align);
    }

    size_t largest = 0;
    for (size_t i = 1; i < variant_layouts.size(); i++)
    {
        if (variant_layouts[i].size >= variant_layouts[largest].size)
        {
            largest = i;
        }
    }
    if (!variant_layouts[largest].has_niche)
    {
        return false;
    }

    uint64_t niche_variants_start = 0;
    uint64_t niche_variants_end = 0;
    bool found_start = false;
    for (uint64_t i = 0; i < static_cast<uint64_t>(variants.size()); i++)
    {
        if (i == static_cast<uint64_t>(largest))
        {
            continue;
        }
        if (!found_start)
        {
            niche_variants_start = i;
            found_start = true;
        }
        niche_variants_end = i;
    }
    if (!found_start)
    {
        return false;
    }
    U128 count = U128::from_u64(niche_variants_end - niche_variants_start + 1);

    Niche niche = variant_layouts[largest].largest_niche;
    U128 niche_start;
    WrappingRange reserved_valid;
    if (!niche.reserve(count, &niche_start, &reserved_valid))
    {
        return false;
    }
    uint64_t niche_offset = niche.offset;
    uint64_t niche_size = niche.value_size_bytes();
    uint64_t total_size = round_up(variant_layouts[largest].size, total_align_bytes);

    for (size_t i = 0; i < variant_layouts.size(); i++)
    {
        if (i == largest)
        {
            continue;
        }
        VariantLayout &info = final_variants[i];
        info.has_niche = false;
        info.largest_niche = Niche();
        if (variant_layouts[i].size <= niche_offset)
        {
            continue;
        }
        uint64_t variant_align = variant_layouts[i].align == 0 ? 1 : variant_layouts[i].align;
        uint64_t this_offset = round_up(niche_offset + niche_size, variant_align);
        if (this_offset > total_size || variant_layouts[i].size > total_size - this_offset)
        {
            return false;
        }
        for (size_t f = 0; f < info.field_offsets.size(); f++)
        {
            info.field_offsets[f] += this_offset;
        }
        if (!info.uninhabited)
        {
            info.backend = BackendReprKind::Memory;
        }
        info.size += this_offset;
    }

    Niche remaining;
    bool has_remaining = Niche::from_scalar(
        niche_offset, tag_scalar_from_range(niche.bits, reserved_valid), &remaining);

    bool same_size = total_size == variant_layouts[largest].size;
    bool same_align = total_align_bytes == variant_layouts[largest].align;
    bool others_zst = true;
    for (size_t i = 0; i < variant_layouts.size(); i++)
    {
        if (i != largest && variant_layouts[i].size != 0)
        {
            others_zst = false;
            break;
        }
    }
    BackendReprKind backend = BackendReprKind::Memory;
    if (same_size && same_align && others_zst)
    {
        if (variant_layouts[largest].backend == BackendReprKind::Scalar)
        {
            backend = BackendReprKind::Scalar;
        }
        else if (variant_layouts[largest].backend == BackendReprKind::ScalarPair)
        {
            backend = BackendReprKind::ScalarPair;
        }
    }

    for (size_t i = 0; i < final_variants.size(); i++)
    {
        if (i == largest)
        {
            final_variants[i].has_tag_range = true;
            final_variants[i].tag_range = reserved_valid;
            continue;
        }
        U128 tag = u128_add(niche_start, U128::from_u64(i - niche_variants_start));
        tag = u128_truncate(tag, niche.bits);
        final_variants[i].has_tag_range = true;
        final_variants[i].tag_range = WrappingRange(tag, tag);
    }

    *out = LayoutData();
    out->size = total_size;
    out->align = total_align_bytes;
    out->unadjusted_abi_align = total_align_bytes;
    out->backend = backend;
    out->fields_kind = FieldsShapeKind::Arbitrary;
    out->field_offsets.push_back(niche_offset);
    out->field_sizes.push_back(niche_size);
    out->in_memory_order.push_back(0);
    out->variants_kind = VariantsKind::Multiple;
    out->tag_encoding = TagEncodingKind::Niche;
    out->untagged_variant = largest;
    out->niche_variants_start = niche_variants_start;
    out->niche_variants_end = niche_variants_end;
    out->niche_start = niche_start;
    out->tag_bits = niche.bits;
    out->has_tag_scalar = true;
    out->tag_scalar = tag_scalar_from_range(niche.bits, reserved_valid);
    out->variants = final_variants;
    out->has_niche = has_remaining;
    if (has_remaining)
    {
        out->largest_niche = remaining;
    }
    return true;
}

bool LayoutCalculator::layout_enum(const std::vector<std::vector<LayoutData> > &variants,
                                   const std::vector<U128> &discriminants,
                                   const ReprOptions &repr,
                                   LayoutData *out) const
{
    if (out == NULL || variants.empty())
    {
        return false;
    }

    LayoutData tagged;
    if (!layout_tagged_enum(variants, discriminants, repr, &tagged))
    {
        return false;
    }

    LayoutData niched;
    if (!layout_niche_enum(variants, discriminants, repr, &niched))
    {
        *out = tagged;
        return true;
    }

    U128 tagged_available = tagged.has_niche ? tagged.largest_niche.available() : U128();
    U128 niched_available = niched.has_niche ? niched.largest_niche.available() : U128();
    bool use_niche = niched.size < tagged.size;
    if (niched.size == tagged.size)
    {
        use_niche = niched_available > tagged_available;
    }
    *out = use_niche ? niched : tagged;
    return true;
}

bool LayoutCalculator::layout_simd(const LayoutData &element,
                                   uint64_t lanes,
                                   bool packed,
                                   LayoutData *out) const
{
    if (out == NULL || lanes == 0 || lanes > 65535 ||
        element.backend != BackendReprKind::Scalar)
    {
        return false;
    }
    Size size;
    if (!Size(element.size).checked_mul(lanes, &size))
    {
        return false;
    }

    uint64_t align_bytes = 0;
    bool power_of_two = (lanes & (lanes - 1)) == 0;
    if (packed && !power_of_two)
    {
        align_bytes = Align::max_aligned_factor(size.bytes).bytes();
    }
    else
    {
        align_bytes = target_.rust_vector_align_bytes(size.bytes);
        Align align;
        if (!Align::from_bytes(align_bytes, &align))
        {
            return false;
        }
        align_bytes = align.bytes();
    }
    uint64_t total_size = round_up(size.bytes, align_bytes);

    *out = LayoutData();
    out->size = total_size;
    out->align = align_bytes;
    out->unadjusted_abi_align = element.align;
    out->backend = (packed && !power_of_two) ? BackendReprKind::Memory
                                             : BackendReprKind::SimdVector;
    out->fields_kind = FieldsShapeKind::Arbitrary;
    out->field_offsets.push_back(0);
    out->field_sizes.push_back(element.size);
    out->in_memory_order.push_back(0);
    out->variants_kind = VariantsKind::Single;
    out->has_niche = element.has_niche;
    out->largest_niche = element.largest_niche;
    return true;
}

bool LayoutCalculator::layout_coroutine(const std::vector<LayoutData> &local_layouts,
                                        const std::vector<LayoutData> &prefix_layouts,
                                        const std::vector<std::vector<uint32_t> > &variant_locals,
                                        const std::vector<std::vector<bool> > &storage_conflicts,
                                        LayoutData *out) const
{
    if (out == NULL || variant_locals.empty())
    {
        return false;
    }
    size_t local_count = local_layouts.size();
    for (size_t v = 0; v < variant_locals.size(); v++)
    {
        for (size_t i = 0; i < variant_locals[v].size(); i++)
        {
            if (variant_locals[v][i] >= local_count)
            {
                return false;
            }
        }
    }

    // -1 = unassigned, -2 = ineligible (promoted to prefix), >= 0 = variant.
    std::vector<int64_t> assignments(local_count, -1);
    std::vector<bool> ineligible(local_count, false);
    for (size_t v = 0; v < variant_locals.size(); v++)
    {
        for (size_t i = 0; i < variant_locals[v].size(); i++)
        {
            uint32_t local = variant_locals[v][i];
            if (assignments[local] == -1)
            {
                assignments[local] = static_cast<int64_t>(v);
            }
            else if (assignments[local] >= 0)
            {
                ineligible[local] = true;
                assignments[local] = -2;
            }
        }
    }
    for (size_t a = 0; a < local_count; a++)
    {
        if (ineligible[a] || a >= storage_conflicts.size())
        {
            continue;
        }
        for (size_t b = 0; b < local_count; b++)
        {
            if (a == b || ineligible[b] || b >= storage_conflicts[a].size() ||
                !storage_conflicts[a][b])
            {
                continue;
            }
            if (assignments[b] == assignments[a])
            {
                continue;
            }
            uint64_t conflicts_a = 0;
            uint64_t conflicts_b = 0;
            for (size_t k = 0; k < local_count; k++)
            {
                if (k < storage_conflicts[a].size() && storage_conflicts[a][k])
                {
                    conflicts_a++;
                }
                if (k < storage_conflicts[b].size() && storage_conflicts[b][k])
                {
                    conflicts_b++;
                }
            }
            size_t remove = conflicts_a > conflicts_b ? a : b;
            ineligible[remove] = true;
            assignments[remove] = -2;
        }
    }

    std::vector<bool> used_variants(variant_locals.size(), false);
    for (size_t i = 0; i < local_count; i++)
    {
        if (assignments[i] >= 0)
        {
            used_variants[static_cast<size_t>(assignments[i])] = true;
        }
    }
    size_t used_count = 0;
    for (size_t v = 0; v < used_variants.size(); v++)
    {
        if (used_variants[v])
        {
            used_count++;
        }
    }
    if (used_count < 2)
    {
        for (size_t i = 0; i < local_count; i++)
        {
            ineligible[i] = true;
            assignments[i] = -2;
        }
    }

    std::vector<int64_t> promoted_field(local_count, -1);
    int64_t promoted_count = 0;
    for (size_t i = 0; i < local_count; i++)
    {
        if (ineligible[i])
        {
            promoted_field[i] = promoted_count++;
            assignments[i] = -2;
        }
    }

    uint64_t tag_index = prefix_layouts.size();
    U128 max_discriminant = U128::from_u64(variant_locals.size() - 1);
    uint32_t tag_bits = 8;
    if (max_discriminant.hi != 0)
    {
        tag_bits = 128;
    }
    else if (max_discriminant.lo > 0xffffffffULL)
    {
        tag_bits = 64;
    }
    else if (max_discriminant.lo > 0xffffULL)
    {
        tag_bits = 32;
    }
    else if (max_discriminant.lo > 0xffULL)
    {
        tag_bits = 16;
    }
    Scalar tag;
    tag.primitive = PrimitiveKind::Int;
    tag.bits = tag_bits;
    tag.is_signed = false;
    tag.valid = WrappingRange(U128(), max_discriminant);

    std::vector<LayoutData> prefix_fields = prefix_layouts;
    std::vector<uint32_t> promoted_locals;
    LayoutData tag_layout;
    if (!layout_scalar(tag, &tag_layout))
    {
        return false;
    }
    prefix_fields.push_back(tag_layout);
    for (size_t i = 0; i < local_count; i++)
    {
        if (ineligible[i])
        {
            prefix_fields.push_back(local_layouts[i]);
            promoted_locals.push_back(static_cast<uint32_t>(i));
        }
    }

    LayoutData prefix;
    if (!univariant(prefix_fields, ReprOptions(), StructKindSpec::always(), &prefix))
    {
        return false;
    }
    uint64_t b_start = tag_index + 1;
    std::vector<uint64_t> outer_offsets;
    std::vector<uint64_t> outer_sizes;
    std::vector<uint32_t> outer_order;
    if (b_start > prefix.field_offsets.size())
    {
        return false;
    }
    for (uint64_t i = 0; i < b_start; i++)
    {
        outer_offsets.push_back(prefix.field_offsets[static_cast<size_t>(i)]);
        outer_sizes.push_back(prefix.field_sizes[static_cast<size_t>(i)]);
    }
    std::vector<uint64_t> promoted_offsets;
    for (size_t i = static_cast<size_t>(b_start); i < prefix.field_offsets.size(); i++)
    {
        promoted_offsets.push_back(prefix.field_offsets[i]);
    }
    std::vector<uint32_t> promoted_inverse(promoted_locals.size(), 0);
    for (size_t i = 0; i < prefix.in_memory_order.size(); i++)
    {
        uint32_t field = prefix.in_memory_order[i];
        if (field < b_start)
        {
            outer_order.push_back(field);
        }
        else
        {
            size_t promoted_index = static_cast<size_t>(field - b_start);
            if (promoted_index >= promoted_inverse.size())
            {
                return false;
            }
            promoted_inverse[promoted_index] = static_cast<uint32_t>(i - outer_order.size() - b_start + outer_order.size());
            // The order position among promoted fields only.
        }
    }
    for (size_t i = 0; i < prefix.in_memory_order.size(); i++)
    {
        uint32_t field = prefix.in_memory_order[i];
        if (field < b_start)
        {
            continue;
        }
        size_t promoted_index = static_cast<size_t>(field - b_start);
        uint32_t position = 0;
        for (size_t j = 0; j < prefix.in_memory_order.size(); j++)
        {
            uint32_t other = prefix.in_memory_order[j];
            if (other < b_start)
            {
                continue;
            }
            if (other == field)
            {
                break;
            }
            position++;
        }
        promoted_inverse[promoted_index] = position;
    }

    uint64_t total_size = prefix.size;
    uint64_t total_align = prefix.align;
    std::vector<VariantLayout> final_variants(variant_locals.size());
    for (size_t v = 0; v < variant_locals.size(); v++)
    {
        std::vector<LayoutData> variant_only;
        for (size_t i = 0; i < variant_locals[v].size(); i++)
        {
            uint32_t local = variant_locals[v][i];
            if (assignments[local] == static_cast<int64_t>(v))
            {
                variant_only.push_back(local_layouts[local]);
            }
        }
        LayoutData variant;
        if (!univariant(variant_only, ReprOptions(),
                        StructKindSpec::prefixed(prefix.size, prefix.align), &variant))
        {
            return false;
        }

        size_t invalid_slot = promoted_locals.size() + variant_only.size();
        std::vector<uint32_t> inverse(invalid_slot, static_cast<uint32_t>(invalid_slot));
        std::vector<uint64_t> combined_offsets(variant_locals[v].size(), 0);
        size_t next_variant_field = 0;
        for (size_t i = 0; i < variant_locals[v].size(); i++)
        {
            uint32_t local = variant_locals[v][i];
            uint32_t memory_slot = 0;
            if (assignments[local] == static_cast<int64_t>(v))
            {
                uint32_t field_index = variant.in_memory_order[next_variant_field];
                combined_offsets[i] = variant.field_offsets[field_index];
                memory_slot = static_cast<uint32_t>(promoted_locals.size()) +
                              static_cast<uint32_t>(next_variant_field);
                next_variant_field++;
            }
            else
            {
                int64_t promoted = promoted_field[local];
                if (promoted < 0 || static_cast<size_t>(promoted) >= promoted_offsets.size())
                {
                    return false;
                }
                combined_offsets[i] = promoted_offsets[static_cast<size_t>(promoted)];
                memory_slot = promoted_inverse[static_cast<size_t>(promoted)];
            }
            if (memory_slot >= inverse.size())
            {
                return false;
            }
            inverse[memory_slot] = static_cast<uint32_t>(i);
        }
        std::vector<uint32_t> combined_order;
        for (size_t i = 0; i < inverse.size(); i++)
        {
            if (inverse[i] != invalid_slot)
            {
                combined_order.push_back(inverse[i]);
            }
        }

        VariantLayout info;
        copy_variant_layout(variant, &info);
        info.field_offsets = combined_offsets;
        info.field_sizes.clear();
        info.in_memory_order = combined_order;
        for (size_t i = 0; i < variant_locals[v].size(); i++)
        {
            info.field_sizes.push_back(local_layouts[variant_locals[v][i]].size);
        }
        info.has_tag_range = true;
        info.tag_range = WrappingRange(U128::from_u64(v), U128::from_u64(v));
        final_variants[v] = info;
        total_size = max_u64(total_size, variant.size);
        total_align = max_u64(total_align, variant.align);
    }
    total_size = round_up(total_size, total_align);

    *out = LayoutData();
    out->size = total_size;
    out->align = total_align;
    out->unadjusted_abi_align = total_align;
    out->backend = BackendReprKind::Memory;
    out->fields_kind = FieldsShapeKind::Arbitrary;
    out->field_offsets = outer_offsets;
    out->field_sizes = outer_sizes;
    out->in_memory_order = outer_order;
    out->variants_kind = VariantsKind::Multiple;
    out->tag_encoding = TagEncodingKind::Direct;
    out->tag_bits = tag_bits;
    out->has_tag_scalar = true;
    out->tag_scalar = tag;
    out->variants = final_variants;
    out->uninhabited = prefix.uninhabited;
    out->has_niche = false;
    out->largest_niche = Niche();
    return true;
}

Numeric Numeric::from_integer(IntegerClass i, bool signedness)
{
    Numeric result;
    result.kind = Numeric::Kind::Int;
    result.integer = i;
    result.is_signed = signedness;
    return result;
}

Numeric Numeric::from_float(FloatClass f)
{
    Numeric result;
    result.kind = Numeric::Kind::Float;
    result.float_type = f;
    return result;
}

uint32_t Numeric::bits() const
{
    if (kind == Numeric::Kind::Float)
    {
        switch (float_type)
        {
            case FloatClass::F16:
            case FloatClass::F16B: return 16;
            case FloatClass::F32: return 32;
            case FloatClass::F64: return 64;
            case FloatClass::F128: return 128;
        }
    }
    switch (integer)
    {
        case IntegerClass::I8: return 8;
        case IntegerClass::I16: return 16;
        case IntegerClass::I32: return 32;
        case IntegerClass::I64: return 64;
        case IntegerClass::I128: return 128;
    }
    return 0;
}

const TargetDataLayout *LayoutCalculator::data_layout() const
{
    return &target_;
}

} // namespace rscabi
