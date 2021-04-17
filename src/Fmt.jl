module Fmt

export @f_str

using Base: StringVector, Ryu, IEEEFloat, is_id_start_char, significand_mask


# Arguments
# ---------

struct Positional
    position::Int
end

struct Keyword
    name::Symbol
    interp::Bool
end

const Argument = Union{Positional, Keyword}


# Fields
# ------

const FILL_DEFAULT = ' '
@enum Alignment::UInt8 ALIGN_UNSPECIFIED ALIGN_LEFT ALIGN_RIGHT ALIGN_CENTER
@enum Conversion::UInt8 CONV_UNSPECIFIED CONV_REPR CONV_STRING
@enum Sign::UInt8 SIGN_PLUS SIGN_MINUS SIGN_SPACE
const SIGN_DEFAULT = SIGN_MINUS
const WIDTH_UNSPECIFIED = nothing
@enum Grouping::UInt8 GROUPING_UNSPECIFIED GROUPING_COMMA GROUPING_UNDERSCORE
const PRECISION_UNSPECIFIED = nothing
const TYPE_UNSPECIFIED = nothing

struct Field
    argument::Argument
    conv::Conversion
    fill::Union{Char, Argument}
    align::Alignment
    sign::Sign
    altform::Bool
    zero::Bool  # zero padding
    width::Union{Int, Nothing, Argument}
    grouping::Grouping
    precision::Union{Int, Nothing, Argument}
    type::Union{Char, Nothing}
end

function Field(
        argument;
        conv = CONV_UNSPECIFIED,
        fill = FILL_DEFAULT,
        align = ALIGN_UNSPECIFIED,
        sign = SIGN_DEFAULT,
        altform = false,
        zero = false,
        width = WIDTH_UNSPECIFIED,
        grouping = GROUPING_UNSPECIFIED,
        precision = PRECISION_UNSPECIFIED,
        type = TYPE_UNSPECIFIED)
    return Field(argument, conv, fill, align, sign, altform, zero, width, grouping, precision, type)
end

function Field(
        f::Field;
        conv = f.conv,
        fill = f.fill,
        align = f.align,
        sign = f.sign,
        altform = f.altform,
        zero = f.zero,
        width = f.width,
        grouping = f.grouping,
        precision = f.precision,
        type = f.type)
    return Field(f.argument, conv, fill, align, sign, altform, zero, width, grouping, precision, type)
end


# Writer functions
# ----------------

# inlined copy of static data
macro copy(dst, p, src::String)
    block = Expr(:block)
    n = ncodeunits(src)
    for i in 1:n
        push!(block.args, :($dst[$p+$i-1] = $(codeunit(src, i))))
    end
    push!(block.args, :(p + $n))
    return esc(block)
end

@inline function paddingwidth(f::Field, width::Int)
    @assert f.width isa Int || f.width isa Nothing
    if f.width isa Int
        return max(f.width - width, 0)
    else
        return 0
    end
end
paddingsize(f::Field, width::Int) = f.fill === nothing ? 0 : paddingwidth(f, width) * ncodeunits(f.fill)

# generic fallback
function formatinfo(f::Field, x::Any)
    s = string(x)
    size = ncodeunits(s)
    width = length(s)
    f.width == WIDTH_UNSPECIFIED && return size, (s, width)
    return paddingsize(f, width) + size, (s, width)
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Any, (s, width)::Tuple{String, Int})
    return formatfield(data, p, f, s, width)
end

function formatinfo(f::Field, x::AbstractChar)
    c = Char(x)
    size = ncodeunits(c)
    f.width == WIDTH_UNSPECIFIED && return size, c
    return paddingsize(f, 1) + size, c
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, ::AbstractChar, c::Char)
    pw = paddingwidth(f, 1)
    if f.width != WIDTH_UNSPECIFIED
        if f.align == ALIGN_RIGHT
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw ÷ 2)
        end
    end
    p = char(data, p, c)
    if f.width != WIDTH_UNSPECIFIED
        if f.align == ALIGN_LEFT || f.align == ALIGN_UNSPECIFIED
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw - pw ÷ 2)
        end
    end
    return p
end

function formatinfo(f::Field, x::AbstractString)
    size = ncodeunits(x) * sizeof(codeunit(x)) 
    width = length(x)
    f.width == WIDTH_UNSPECIFIED && return size, width
    return paddingsize(f, width) + size, width
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::AbstractString, width::Int)
    pw = paddingwidth(f, width)
    if f.width != WIDTH_UNSPECIFIED
        if f.align == ALIGN_RIGHT
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw ÷ 2)
        end
    end
    n = ncodeunits(x)
    if f.precision != PRECISION_UNSPECIFIED
        n = min(nextind(x, 1, f.precision) - 1, n)
    end
    copyto!(data, p, codeunits(x), 1, n)
    p += n
    if f.width != WIDTH_UNSPECIFIED
        if f.align == ALIGN_LEFT || f.align == ALIGN_UNSPECIFIED
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw - pw ÷ 2)
        end
    end
    return p
end

const Z = UInt8('0')

function formatinfo(f::Field, x::Bool)
    width = f.type === nothing ? (x ? 4 : 5) : 1
    if f.altform
        width += 2
    end
    return paddingsize(f, width) + width, width
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Bool, width::Int)
    if f.type !== nothing
        return formatfield(data, p, f, Int(x), (1, width))
    end
    pw = paddingwidth(f, width)
    if f.width != WIDTH_UNSPECIFIED && !f.zero
        if f.align == ALIGN_RIGHT || f.align == ALIGN_UNSPECIFIED
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw ÷ 2)
        end
    end
    if x
        p = @copy data p "true"
    else
        p = @copy data p "false"
    end
    if f.width != WIDTH_UNSPECIFIED && !f.zero
        if f.align == ALIGN_LEFT
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw - pw ÷ 2)
        end
    end
    return p
end

@inline function formatinfo(f::Field, x::Integer)
    if f.type == 'c'
        char = Char(x)
        size = ncodeunits(char)
        f.width == WIDTH_UNSPECIFIED && return size, (0, 1)
        return paddingsize(f, 1) + size, (0, 1)
    end
    base = f.type == 'X' || f.type == 'x' ? 16 : f.type == 'o' ? 8 : f.type == 'B' || f.type == 'b' ? 2 : 10
    m = base == 10 ? ndigits_decimal(x) : ndigits(x; base)
    width = m + (x < 0 || f.sign ≠ SIGN_MINUS)
    if f.altform && base != 10
        width += 2  # prefix (0b, 0o, 0x)
    end
    if f.grouping == GROUPING_COMMA || f.grouping == GROUPING_UNDERSCORE
        if base == 10
            width += div(m - 1, 3)
        else
            width += div(m - 1, 4)
        end
    end
    f.width == WIDTH_UNSPECIFIED && return width, (m, width)
    return paddingsize(f, width) + width, (m, width)
end

@inline function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Integer, (m, width)::Tuple{Int, Int})
    base = f.type == 'X' || f.type == 'x' ? 16 : f.type == 'o' ? 8 : f.type == 'B' || f.type == 'b' ? 2 : 10
    pw = paddingwidth(f, width)
    if f.width != WIDTH_UNSPECIFIED && !f.zero
        if f.align == ALIGN_RIGHT || f.align == ALIGN_UNSPECIFIED
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw ÷ 2)
        end
    end
    if x < 0
        data[p] = UInt8('-')
        p += 1
    elseif f.sign == SIGN_SPACE || f.sign == SIGN_PLUS
        data[p] = f.sign == SIGN_SPACE ? UInt8(' ') : UInt8('+')
        p += 1
    end
    if f.altform && base ≠ 10
        data[p] = Z
        data[p+1] = UInt8(f.type)
        p += 2
    end
    if f.zero
        p = pad(data, p, '0', pw)
    end
    if f.type == 'c'
        p = pad(data, p, Char(x), 1)
    else
        u = unsigned(abs(x))
        if f.grouping == GROUPING_UNSPECIFIED
            p = base ==  2 ? binary(data, p, u, m) :
                base ==  8 ? octal(data, p, u, m) :
                base == 10 ? decimal(data, p, u, m) :
                hexadecimal(data, p, u, m, f.type == 'X')
        else
            p = base ==  2 ? binary_grouping(data, p, u, m) :
                base ==  8 ? octal_grouping(data, p, u, m) :
                base == 10 ? decimal_grouping(data, p, u, m, f.grouping == GROUPING_COMMA ? UInt8(',') : UInt8('_')) :
                hexadecimal_grouping(data, p, u, m, f.type == 'X')
        end
    end
    if f.width != WIDTH_UNSPECIFIED && !f.zero
        if f.align == ALIGN_LEFT
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw - pw ÷ 2)
        end
    end
    return p
end

function binary(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int)
    n = m
    while n > 0
        r = (x & 0x1) % UInt8
        data[p+n-1] = r + Z
        x >>= 1
        n -= 1
    end
    return p + m
end

function binary_grouping(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int)
    k = div(m - 1, 4)
    n = m + k
    while n ≥ 5
        r1 = (x & 0x1) % UInt8; x >>= 1
        r2 = (x & 0x1) % UInt8; x >>= 1
        r3 = (x & 0x1) % UInt8; x >>= 1
        r4 = (x & 0x1) % UInt8; x >>= 1
        data[p+n-1] = r1 + Z
        data[p+n-2] = r2 + Z
        data[p+n-3] = r3 + Z
        data[p+n-4] = r4 + Z
        data[p+n-5] = UInt8('_')
        n -= 5
    end
    binary(data, p, x, n)
    return p + m + k
end

function octal(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int)
    n = m
    while n > 0
        r = (x & 0x7) % UInt8
        data[p+n-1] = r + Z
        x >>= 3
        n -= 1
    end
    return p + m
end

function octal_grouping(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int)
    k = div(m - 1, 4)
    n = m + k
    while n ≥ 5
        r1 = (x & 0x7) % UInt8; x >>= 3
        r2 = (x & 0x7) % UInt8; x >>= 3
        r3 = (x & 0x7) % UInt8; x >>= 3
        r4 = (x & 0x7) % UInt8; x >>= 3
        data[p+n-1] = r1 + Z
        data[p+n-2] = r2 + Z
        data[p+n-3] = r3 + Z
        data[p+n-4] = r4 + Z
        data[p+n-5] = UInt8('_')
        n -= 5
    end
    octal(data, p, x, n)
    return p + m + k
end

const DECIMAL_DIGITS = [let (d, r) = divrem(x, 10); ((d + Z) << 8) % UInt16 + (r + Z) % UInt8; end for x in 0:99]

function decimal(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int)
    n = m
    @inbounds while n ≥ 2
        x, r = divrem(x, 0x64)  # 0x64 = 100
        dd = DECIMAL_DIGITS[(r % Int) + 1]
        data[p+n-1] =  dd       % UInt8
        data[p+n-2] = (dd >> 8) % UInt8
        n -= 2
    end
    if n > 0
        data[p] = (rem(x, 0xa) % UInt8) + Z
    end
    return p + m
end

function decimal_grouping(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, sep::UInt8)
    k = div(m - 1, 3)
    n = m + k
    while n ≥ 4
        x, r = divrem(x, 0x64)  # 0x64 = 100
        dd = DECIMAL_DIGITS[(r % Int) + 1]
        data[p+n-1] = dd % UInt8
        data[p+n-2] = (dd >> 8) % UInt8
        x, r = divrem(x, 0xa)
        data[p+n-3] = r % UInt8 + Z
        data[p+n-4] = sep
        n -= 4
    end
    decimal(data, p, x, n)
    return p + m + k
end

const HEXADECIMAL_DIGITS_UPPERCASE = zeros(UInt16, 256)
const HEXADECIMAL_DIGITS_LOWERCASE = zeros(UInt16, 256)
for x in 0:255
    d, r = divrem(x, 16)
    A = UInt8('A')
    HEXADECIMAL_DIGITS_UPPERCASE[x+1] = ((d < 10 ? d + Z : d - 10 + A) << 8) % UInt16 + (r < 10 ? r + Z : r - 10 + A) % UInt8
    A = UInt8('a')
    HEXADECIMAL_DIGITS_LOWERCASE[x+1] = ((d < 10 ? d + Z : d - 10 + A) << 8) % UInt16 + (r < 10 ? r + Z : r - 10 + A) % UInt8
end

function hexadecimal(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, uppercase::Bool)
    n = m
    hexdigits = uppercase ? HEXADECIMAL_DIGITS_UPPERCASE : HEXADECIMAL_DIGITS_LOWERCASE
    while n ≥ 2
        x, r = divrem(x, 0x100)  # 0x100 = 256
        xx = hexdigits[(r % Int) + 1]
        data[p+n-1] =  xx       % UInt8
        data[p+n-2] = (xx >> 8) % UInt8
        n -= 2
    end
    if n > 0
        A = uppercase ? UInt8('A') : UInt8('a')
        r = rem(x, 0x10) % UInt8
        data[p] = r < 0xa ? r + Z : r - 0xa + A
    end
    return p + m
end

function hexadecimal_grouping(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, uppercase::Bool)
    k = div(m - 1, 4)
    n = m + k
    hexdigits = uppercase ? HEXADECIMAL_DIGITS_UPPERCASE : HEXADECIMAL_DIGITS_LOWERCASE
    while n ≥ 5
        x, r = divrem(x, 0x100)  # 0x100 = 256
        xx = hexdigits[(r % Int) + 1]
        data[p+n-1] = xx % UInt8
        data[p+n-2] = (xx >> 8) % UInt8
        x, r = divrem(x, 0x100)
        xx = hexdigits[(r % Int) + 1]
        data[p+n-3] = xx % UInt8
        data[p+n-4] = (xx >> 8) % UInt8
        data[p+n-5] = UInt8('_')
        n -= 5
    end
    hexadecimal(data, p, x, n, uppercase)
    return p + m + k
end

ndigits_decimal(x::Integer) =
    ndigits_decimal(unsigned(abs(x)))

function ndigits_decimal(x::Unsigned)
    n = 0
    while true
        if x < 10
            n += 1
            break
        elseif x < 100
            n += 2
            break
        elseif x < 1000
            n += 3
            break
        else
            n += 4
            x < 10000 && break
            x = div(x, oftype(x, 10000))
        end
    end
    return n
end

function formatinfo(f::Field, x::Ptr)
    width = 2sizeof(x) + 2
    f.width == WIDTH_UNSPECIFIED && return width, width
    return width + max(f.width - width, 0), width
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Ptr, width::Int)
    pw = paddingwidth(f, width)
    if f.width != WIDTH_UNSPECIFIED
        if f.align == ALIGN_RIGHT || f.align == ALIGN_UNSPECIFIED
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw ÷ 2)
        end
    end
    p = @copy data p "0x"
    p = hexadecimal(data, p, reinterpret(UInt, x), width - 2, false)
    if f.width != WIDTH_UNSPECIFIED
        if f.align == ALIGN_LEFT
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw - pw ÷ 2)
        end
    end
    return p
end

function formatinfo(f::Field, x::IEEEFloat)
    return Ryu.neededdigits(typeof(x)), nothing
end

@inline function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::IEEEFloat, info)
    start = p
    if x < 0 || x === -zero(x)
        data[p] = UInt8('-')
        p += 1
    elseif f.sign == SIGN_PLUS
        data[p] = UInt8('+')
        p += 1
    elseif f.sign == SIGN_SPACE
        data[p] = UInt8(' ')
        p += 1
    end
    x = abs(x)
    signed = p > start

    uppercase = f.type == 'F' || f.type == 'E' || f.type == 'A' || f.type == 'G'
    plus = false
    space = false
    hash = f.altform
    expchar = uppercase ? UInt8('E') : UInt8('e')
    if isinf(x)
        if uppercase
            p = @copy data p "INF"
        else
            p = @copy data p "inf"
        end
    elseif isnan(x)
        if uppercase
            p = @copy data p "NAN"
        else
            p = @copy data p "nan"
        end
    elseif f.type == 'F' || f.type == 'f'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = Ryu.writefixed(data, p, x, precision, plus, space, hash)
    elseif f.type == 'E' || f.type == 'e'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = Ryu.writeexp(data, p, x, precision, plus, space, hash, expchar)
    elseif f.type == 'A' || f.type == 'a'
        if uppercase
            p = @copy data p "0X"
        else
            p = @copy data p "0x"
        end
        precision = f.precision == PRECISION_UNSPECIFIED ? -1 : f.precision
        p = hexadecimal(data, p, x, precision, uppercase)
    elseif f.type == '%'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = Ryu.writefixed(data, p, 100x, precision, plus, space, hash)
        data[p] = UInt8('%')
        p += 1
    else
        @assert f.type == 'G' || f.type == 'g' || f.type === nothing
        hash = f.type === nothing
        padexp = false
        precision = -1
        if f.precision != PRECISION_UNSPECIFIED
            padexp = true
            precision = max(f.precision, 1)
            x = round(x, sigdigits = precision)
        end
        p = Ryu.writeshortest(data, p, x, plus, space, hash, precision, expchar, padexp)
    end

    if f.width != WIDTH_UNSPECIFIED
        width = p - start
        pw = paddingwidth(f, width)
        if f.zero
            if signed
                start += 1
                width -= 1
            end
            copyto!(data, start + pw, data, start, width)
            pad(data, start, '0', pw)
            p += pw
        elseif f.align == ALIGN_RIGHT || f.align == ALIGN_UNSPECIFIED
            ps = paddingsize(f, width)
            copyto!(data, start + ps, data, start, width)
            pad(data, start, f.fill, pw)
            p += ps
        elseif f.align == ALIGN_CENTER
            offset = ncodeunits(f.fill) * (pw ÷ 2)
            copyto!(data, start + offset, data, start, width)
            pad(data, start, f.fill, pw ÷ 2)
            pad(data, start + offset + width, f.fill, pw - pw ÷ 2)
            p += paddingsize(f, width)
        else
            p = pad(data, p, f.fill, pw)
        end
    end
    return p
end

# NOTE: the sign of `x` is ignored
function hexadecimal(data::Vector{UInt8}, p::Int, x::IEEEFloat, precision::Int, uppercase::Bool)
    if iszero(x)
        data[p] = Z
        p += 1
        if precision > 0
            data[p] = UInt8('.')
            p += 1
            p = pad(data, p, '0', precision)
        end
        exp = 0
    else
        # make fr ∈ [1, 2) so that the digit before point is always '1'
        fr, exp = frexp(abs(x))
        fr *= 2
        exp -= 1
        data[p] = UInt8('1')
        p += 1
        if isone(fr)
            if precision > 0
                data[p] = UInt8('.')
                p += 1
                p = pad(data, p, '0', precision)
            end
        else
            # fr ∈ (1, 2)
            if precision != 0
                data[p] = UInt8('.')
                p += 1
            end
            p, carry = hexadecimal_fraction(data, p, Float64(fr), precision, uppercase)
            exp += carry
        end
    end
    data[p] = uppercase ? UInt8('P') : UInt8('p')
    p += 1
    data[p] = exp < 0 ? UInt8('-') : UInt8('+')
    p += 1
    uexp = unsigned(abs(exp))
    return decimal(data, p, uexp, ndigits_decimal(uexp))
end

# fr must be in (1, 2)
function hexadecimal_fraction(data::Vector{UInt8}, p::Int, fr::Float64, precision::Int, uppercase::Bool)
    @assert 1 < fr < 2
    m = 13
    u = reinterpret(UInt64, fr) & significand_mask(Float64)
    if precision < 0
        # trim trailing zero nibbles
        tz = trailing_zeros(u) ÷ 4
        return hexadecimal(data, p, u >> 4tz, m - tz, uppercase), 0
    elseif precision ≥ m
        # emit all digits and padding zeros
        p = hexadecimal(data, p, u, m, uppercase)
        return pad(data, p, '0', precision - m), 0
    else
        # half-to-even rounding
        k = m - precision
        u1 = u >> 4k
        u2 = u & ((one(u) << 4k) - 0x1)
        half = oftype(u, 0x8) << 4(k - 1)
        carry = 0
        if u2 > half || u2 == half && (u1 & 0x1) > 0
            u1 += 1
            carry = Int(u1 ≥ (one(u) << 4precision))
        end
        return hexadecimal(data, p, u1, precision, uppercase), carry
    end
end

function pad(data::Vector{UInt8}, p::Int, fill::Char, w::Int)
    for _ in 1:w
        p = char(data, p, fill)
    end
    return p
end

function char(data::Vector{UInt8}, p::Int, char::Char)
    m = ncodeunits(char)
    x = reinterpret(UInt32, char) >> 8(4 - m)
    if m == 1
        data[p]   =  x        % UInt8
    elseif m == 2
        data[p+1] =  x        % UInt8
        data[p]   = (x >> 8)  % UInt8
    elseif m == 3
        data[p+2] =  x        % UInt8
        data[p+1] = (x >>  8) % UInt8
        data[p]   = (x >> 16) % UInt8
    else
        @assert m == 4
        data[p+3] =  x        % UInt8
        data[p+2] = (x >>  8) % UInt8
        data[p+1] = (x >> 16) % UInt8
        data[p]   = (x >> 24) % UInt8
    end
    return p + m
end


# Parser
# ------

struct FormatError <: Exception
    msg::String
end

function Base.showerror(out::IO, e::FormatError)
    print(out, "FormatError: ", e.msg)
end

function parse(fmt::String)
    list = Union{String, Field}[]
    serial = 0
    str = IOBuffer()
    last = lastindex(fmt)
    i = firstindex(fmt)
    while i ≤ last
        c = fmt[i]
        if c == '{'
            while i + 1 ≤ last && fmt[i] == fmt[i+1] == '{'
                write(str, '{')
                i += 2
            end
            if i ≤ last && fmt[i] == '{'
                i == last && throw(FormatError("single '{' is not allowed; use '{{' instead"))
                str.size > 0 && push!(list, String(take!(str)))
                field, i, serial = parse_field(fmt, i + 1, serial)
                push!(list, field)
            end
        elseif c == '}'
            while i + 1 ≤ last && fmt[i] == fmt[i+1] == '}'
                write(str, '}')
                i += 2
            end
            if i ≤ last && fmt[i] == '}' && !(i + 1 ≤ last && fmt[i+1] == '}')
                throw(FormatError("single '}' is not allowed; use '}}' instead"))
            end
        else
            write(str, c)
            i = nextind(fmt, i)
        end
    end
    str.size > 0 && push!(list, String(take!(str)))
    return list
end

function parse_field(fmt::String, i::Int, serial::Int)
    incomplete_field() = throw(FormatError("incomplete field"))
    last = lastindex(fmt)
    arg, i, serial = parse_argument(fmt, i, serial)
    i ≤ last || incomplete_field()
    conv = CONV_UNSPECIFIED
    if fmt[i] == '!'
        i + 1 ≤ last || incomplete_field()
        conv, i = parse_conv(fmt, i + 1)
        i ≤ last || incomplete_field()
    end
    spec = ()
    if fmt[i] == ':'
        i + 1 ≤ last || incomplete_field()
        spec, i, serial = parse_spec(fmt, i + 1, serial)
        i ≤ last || incomplete_field()
    end
    fmt[i] == '}' || throw(FormatError("invalid character $(repr(fmt[i]))"))
    return Field(arg; conv, spec...), i + 1, serial
end

function parse_argument(s::String, i::Int, serial::Int)
    c = s[i]  # the first character after '{'
    if isdigit(c)
        n, i = parse_digits(s, i)
        n == 0 && throw(FormatError("argument 0 is not allowed; use 1 or above"))
        arg = Positional(n)
    elseif c == '$'
        i < lastindex(s) && is_id_start_char(s[i+1]) ||
            throw(FormatError("identifier is expected after '\$'"))
        name, i = Meta.parse(s, i + 1, greedy = false)
        arg = Keyword(name, true)
    elseif is_id_start_char(c)
        name, i = Meta.parse(s, i, greedy = false)
        arg = Keyword(name, false)
    else
        serial += 1
        arg = Positional(serial)
    end
    return arg, i, serial
end

function parse_conv(fmt::String, i::Int)
    c = fmt[i]
    if c == 'r'
        return CONV_REPR, i + 1
    elseif c == 's'
        return CONV_STRING, i + 1
    else
        throw(FormatError("invalid conversion character $(repr(c))"))
    end
end

function parse_spec(fmt::String, i::Int, serial::Int)
    # default
    fill = FILL_DEFAULT
    align = ALIGN_UNSPECIFIED
    sign = SIGN_DEFAULT
    altform = false
    zero = false
    width = WIDTH_UNSPECIFIED
    grouping = GROUPING_UNSPECIFIED
    precision = PRECISION_UNSPECIFIED
    type = TYPE_UNSPECIFIED

    incomplete_argument() = throw(FormatError("incomplete argument"))
    char2align(c) = c == '<' ? ALIGN_LEFT :
                    c == '^' ? ALIGN_CENTER :
                    c == '>' ? ALIGN_RIGHT : @assert false

    # align
    last = lastindex(fmt)
    if fmt[i] == '{'
        # dynamic fill or dynamic width?
        _arg, _i, _serial = parse_argument(fmt, i + 1, serial)
        _i ≤ last && fmt[_i] == '}' || incomplete_argument()
        if _i + 1 ≤ last && fmt[_i+1] ∈ "<^>"
            # it was a dynamic fill
            fill = _arg
            align = char2align(fmt[_i+1])
            serial = _serial
            i = _i + 2
            i ≤ last || @goto END
        end
    elseif fmt[i] != '}' && nextind(fmt, i) ≤ last && fmt[nextind(fmt, i)] ∈ "<^>"
        # fill + align
        fill = fmt[i]
        i = nextind(fmt, i)
        align = char2align(fmt[i])
        i += 1
        i ≤ last || @goto END
    elseif fmt[i] ∈ "<^>"
        # align only
        align = char2align(fmt[i])
        i += 1
        i ≤ last || @goto END
    end

    # sign
    if fmt[i] ∈ "-+ "
        sign = fmt[i] == '-' ? SIGN_MINUS : fmt[i] == '+' ? SIGN_PLUS : SIGN_SPACE
        i += 1
        i ≤ last || @goto END
    end

    # alternative form
    if fmt[i] == '#'
        altform = true
        i += 1
        i ≤ last || @goto END
    end

    # width
    if fmt[i] == '{'
        width, i, serial = parse_argument(fmt, i + 1, serial)
        i ≤ last && fmt[i] == '}' || incomplete_argument()
        i += 1
        i ≤ last || @goto END
    elseif isdigit(fmt[i])
        if fmt[i] == '0' && i + 1 ≤ last && isdigit(fmt[i+1])
            # preceded by zero
            zero = true
            i += 1
        end
        width, i = parse_digits(fmt, i)
        i ≤ last || @goto END
    end

    # grouping
    if fmt[i] == ','
        grouping = GROUPING_COMMA
        i += 1
        i ≤ last || @goto END
    elseif fmt[i] == '_'
        grouping = GROUPING_UNDERSCORE
        i += 1
        i ≤ last || @goto END
    end

    # precision
    if fmt[i] == '.'
        i += 1
        i ≤ last || @goto END
        if fmt[i] == '{'
            precision, i, serial = parse_argument(fmt, i + 1, serial)
            i ≤ last && fmt[i] == '}' || incomplete_argument()
            i += 1
            i ≤ last || @goto END
        elseif isdigit(fmt[i])
            precision, i = parse_digits(fmt, i)
            i ≤ last || @goto END
        else
            throw(FormatError("unexpected $(repr(fmt[i])) after '.'"))
        end
    end

    # type
    if fmt[i] ∈ "dXxoBbcpsFfEeGgAa%"
        type = fmt[i]
        i += 1
        i ≤ last || @goto END
    end

    @label END
    return (; fill, align, sign, altform, zero, width, grouping, precision, type), i, serial
end

function parse_digits(s::String, i::Int)
    n = 0
    last = lastindex(s)
    while i ≤ last && isdigit(s[i])
        n′ = 10n + Int(s[i] - '0')
        n′ ≥ n || throw(FormatError("number overflows"))
        n = n′
        i += 1
    end
    return n, i
end


# Compiler
# --------

function compile(fmt::String)
    format = parse(fmt)

    # no fields; return static string
    if isempty(format)
        return "", nothing
    elseif length(format) == 1 && format[1] isa String
        return format[1], nothing
    end

    n_positionals = 0
    keywords = Symbol[]
    interpolated = Symbol[]
    code_info = Expr(:block)
    code_data = Expr(:block)
    for (i, f) in enumerate(format)
        if f isa String
            n = ncodeunits(f)
            info = :(size += $n)
            data = if n < 8
                quote
                    @inbounds $(genstrcopy(f))
                    p += $n
                end
            else
                quote
                    copyto!(data, p, $(codeunits(f)), 1, $n)
                    p += $n
                end
            end
        else
            arg = f.argument
            if arg isa Positional
                n_positionals = max(arg.position, n_positionals)
                x = esc(Symbol(:_, arg.position))
            else
                if arg.name ∉ keywords
                    push!(keywords, arg.name)
                    arg.interp && push!(interpolated, arg.name)
                end
                x = esc(arg.name)
            end

            # dynamic fill
            fill = if f.fill isa Positional
                position = f.fill.position
                n_positionals = max(position, n_positionals)
                Symbol(:_, position)
            elseif f.fill isa Keyword
                keyword = f.fill.name
                if keyword ∉ keywords
                    push!(keywords, keyword)
                    f.fill.interp && push!(interpolated, keyword)
                end
                keyword
            else
                f.fill
            end

            # dynamic width
            width = if f.width isa Positional
                position = f.width.position
                n_positionals = max(position, n_positionals)
                Symbol(:_, position)
            elseif f.width isa Keyword
                keyword = f.width.name
                if keyword ∉ keywords
                    push!(keywords, keyword)
                    f.width.interp && push!(interpolated, keyword)
                end
                keyword
            else
                f.width
            end

            # dynamic precision
            precision = if f.precision isa Positional
                position = f.precision.position
                n_positionals = max(position, n_positionals)
                Symbol(:_, position)
            elseif f.precision isa Keyword
                keyword = f.precision.name
                if keyword ∉ keywords
                    push!(keywords, keyword)
                    f.precision.interp && push!(interpolated, keyword)
                end
                keyword
            else
                f.precision
            end

            conv = f.conv == CONV_REPR ? repr : f.conv == CONV_STRING ? string : identity
            f = :(Field($f, fill = $(esc(fill)), width = $(esc(width)), precision = $(esc(precision))))
            arg = Symbol(:arg, i)
            meta = Symbol(:meta, i)
            info = quote
                $arg = $(conv)($x)
                s, $meta = formatinfo($f, $arg)
                size += s
            end
            data = :(p = formatfield(data, p, $f, $arg, $meta))
        end
        push!(code_info.args, info)
        push!(code_data.args, data)
    end
    arguments = Expr(:tuple, Expr(:parameters, esc.(keywords)...), [esc(Symbol(:_, i)) for i in 1:n_positionals]...)
    body = quote
        size = 0
        $(code_info)
        data = StringVector(size)
        p = 1
        $(code_data)
        p - 1 < size && resize!(data, p - 1)
        return String(data)
    end
    return Expr(:function, arguments, body), interpolated
end

function genstrcopy(s::String)
    n = ncodeunits(s)
    code = Expr(:block)
    for i in 1:n
        push!(code.args, :(data[p+$i-1] = $(codeunit(s, i))))
    end
    return code
end


# Interface
# ---------

"""
A data type to represent a string format. Instances of this type are
generated by the [`@f_str`](@ref) macro.
"""
struct Format{F}
    str::String
    fun::F
end

Base.show(out::IO, fmt::Format) = print(out, "f\"", fmt.str, '"')

"""
    format(fmt::Fmt.Format, positionals...; keywords...)
    format(out::IO, fmt::Fmt.Format, positionals...; keywords...)

Create or output a formatted string.

The first method creates a new string. The second method outputs the data of
the formatted string to `out` and returns the number of the written bytes. In
both methods, positional and keyword arguments can be supplied to replace
fields in `fmt`.
"""
format(fmt::Format, positionals...; keywords...) = fmt.fun(positionals...; keywords...)
format(out::IO, fmt::Format, positionals...; keywords...) = write(out, fmt.fun(positionals...; keywords...))
format(fmt::String, positionals...; keywords...) = fmt
format(out::IO, fmt::String, positionals...; keywords...) = write(out, fmt)

"""
    @f_str fmt

Create a formatted string or a formatter object from string `fmt`.

If all argument names of replacement fields are preceded by `\$`, it creates
a new formatted string with all fields being interpolated. If there are no
replacement fields, it returns the string as it is. Otherwise, it creates a
formatting object of the [`Fmt.Format`](@ref) type, which can be passed to
the [`Fmt.format`](@ref) function to create or output formatted strings.

# Examples
```jldoctest
julia> using Fmt

julia> x, y = 42, -8;

julia> f"({\$x}, {\$y})"  # all variables are interpolated
"(42, -8)"

julia> fmt = f"({x}, {y})"  # x and y are now a placeholder
f"({x}, {y})"

julia> Fmt.format(fmt; x, y)  # substitute variables
"(42, -8)"
```
"""
macro f_str(s)
    code, interped = compile(unescape_string(s))
    if code isa String
        code
    elseif isempty(interped)
        :(Format($s, $code))
    else
        :($(code)(; $(esc.(interped)...)))
    end
end

end
