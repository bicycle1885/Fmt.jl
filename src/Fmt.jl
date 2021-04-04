module Fmt

export @f_str, format

using Base: StringVector, Ryu

const FILL_UNSPECIFIED = reinterpret(Char, 0xFFFFFFFF)
@enum Alignment::UInt8 ALIGN_UNSPECIFIED ALIGN_LEFT ALIGN_RIGHT
@enum Sign::UInt8 SIGN_PLUS SIGN_MINUS SIGN_SPACE
const SIGN_UNSPECIFIED = SIGN_MINUS
const WIDTH_UNSPECIFIED = -1
const TYPE_UNSPECIFIED = reinterpret(Char, 0xFFFFFFFF)

# fields without spec
struct SimpleField{arg, T} end

argument(::Type{SimpleField{arg, _}}) where {arg, _} = arg

# generic fields
struct Field{arg, T}
    fill::Char
    align::Alignment
    sign::Sign
    altform::Bool
    zero::Bool  # zero padding
    width::Int  # minimum width
    type::Char
end

function Field{arg, T}(;
        fill = FILL_UNSPECIFIED,
        align = ALIGN_UNSPECIFIED,
        sign = SIGN_UNSPECIFIED,
        altform = false,
        zero = false,
        width = WIDTH_UNSPECIFIED,
        type = TYPE_UNSPECIFIED,
        ) where {arg, T}
    return Field{arg, T}(fill, align, sign, altform, zero, width, type)
end

argument(::Type{Field{arg, _}}) where {arg, _} = arg

function formatsize(::SimpleField, x::AbstractString)
    return ncodeunits(x) * sizeof(codeunit(x)) 
end

function formatsize(f::Field, x::AbstractString)
    size = ncodeunits(x) * sizeof(codeunit(x)) 
    f.width == WIDTH_UNSPECIFIED && return size
    return ncodeunits(f.fill) * max(f.width - length(x), 0) + size
end

function formatfield(data::Vector{UInt8}, p::Int, ::SimpleField, x::AbstractString)
    n = ncodeunits(x)
    copyto!(data, p, codeunits(x), 1, n)
    return p + n
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::AbstractString)
    width = length(x)
    padwidth = max(f.width - width, 0)
    if f.align == ALIGN_RIGHT
        p = pad(data, p, f.fill, padwidth)
    end
    n = ncodeunits(x)
    copyto!(data, p, codeunits(x), 1, n)
    p += n
    if f.align != ALIGN_RIGHT
        p = pad(data, p, f.fill, padwidth)
    end
    return p
end

const Z = UInt8('0')

function formatsize(::SimpleField, x::Integer)
    return ndigits_decimal(x) + (x < 0)
end

function formatsize(f::Field, x::Integer)
    base = f.type == 'X' || f.type == 'x' ? 16 : f.type == 'o' ? 8 : f.type == 'b' ? 2 : 10
    m = base == 10 ? ndigits_decimal(x) : ndigits(x; base)
    w = m + (x < 0 || f.sign ≠ SIGN_MINUS)
    if f.altform && base != 10
        w += 2  # prefix (0b, 0o, 0x)
    end
    f.width == WIDTH_UNSPECIFIED && return w
    return ncodeunits(f.fill) * max(f.width - w, 0) + w
end

function formatfield(data::Vector{UInt8}, p::Int, ::SimpleField, x::Integer)
    if x < 0
        data[p] = UInt8('-')
        p += 1
    end
    u = unsigned(abs(x))
    m = ndigits_decimal(u)
    return decimal(data, p, u, m)
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Integer)
    base = f.type == 'X' || f.type == 'x' ? 16 : f.type == 'o' ? 8 : f.type == 'b' ? 2 : 10
    u = unsigned(abs(x))
    m = base == 10 ? ndigits_decimal(u) : ndigits(x; base)
    width = m + (x < 0 || f.sign ≠ SIGN_MINUS) + (f.altform && base ≠ 10 && 2)
    padwidth = max(f.width - width, 0)
    if f.align != ALIGN_LEFT && !f.zero
        p = pad(data, p, f.fill, padwidth)
    end
    if x < 0
        data[p] = UInt8('-')
        p += 1
    elseif f.sign == SIGN_SPACE || f.sign == SIGN_PLUS
        data[p] = f.sign == SIGN_SPACE ? UInt8(' ') : UInt8('+')
        p += 1
    end
    if f.zero
        p = pad(data, p, '0', padwidth)
    end
    if base == 10
        p = decimal(data, p, u, m)
    elseif base == 16
        if f.altform
            data[p  ] = Z
            data[p+1] = UInt8(f.type)
            p += 2
        end
        p = hexadecimal(data, p, u, m, f.type == 'X')
    elseif base == 2
        if f.altform
            data[p  ] = Z
            data[p+1] = UInt8('b')
            p += 2
        end
        p = binary(data, p, u, m)
    elseif base == 8
        if f.altform
            data[p  ] = Z
            data[p+1] = UInt('o')
            p += 2
        end
        p = octal(data, p, u, m)
    else
        @assert false "invalid base"
    end
    if f.align == ALIGN_LEFT
        p = pad(data, p, f.fill, padwidth)
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

const DECIMAL_DIGITS = [let (d, r) = divrem(x, 10); ((d + Z) << 8) % UInt16 + (r + Z) % UInt8; end for x in 0:99]

function decimal(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int)
    n = m
    while n ≥ 2
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

function formatsize(::SimpleField, x::AbstractFloat)
    return Ryu.neededdigits(typeof(x))
end

function formatsize(f::Field, x::AbstractFloat)
    return Ryu.neededdigits(typeof(x))
end

function formatfield(data::Vector{UInt8}, p::Int, ::SimpleField, x::AbstractFloat)
    return Ryu.writeshortest(data, p, x)
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::AbstractFloat)
    return Ryu.writeshortest(data, p, x)
end

function pad(data::Vector{UInt8}, p::Int, fill::Char, w::Int)
    m = ncodeunits(fill)
    x = reinterpret(UInt32, fill) >> 8(4 - m)
    while w > 0
        n = m
        y = x
        while n > 0
            data[p+n-1] = y % UInt8
            y >>= 8
            n -= 1
        end
        p += m
        w -= 1
    end
    return p
end

function genformat(fmt, positionals, keywords)
    code_size = Expr(:block)  # compute data size
    code_data = Expr(:block)  # write data
    for (i, F) in enumerate(fmt.types)
        if F === String
            size = :(s += ncodeunits(fmt[$i]))
            data = quote
                n = ncodeunits(fmt[$i])
                copyto!(data, p, codeunits(fmt[$i]), 1, n)
                p += n
            end
        else
            @assert F <: Field || F <: SimpleField
            arg = argument(F)
            if arg isa Int
                arg = :(positionals[$arg])
            else
                @assert arg isa Symbol
                arg = :(keywords[$(QuoteNode(arg))])
            end
            size = :(s += formatsize(fmt[$i], $arg))
            data = :(p  = formatfield(data, p, fmt[$i], $arg))
        end
        push!(code_size.args, size)
        push!(code_data.args, data)
    end
    return quote
        s = 0  # size
        $(code_size)
        data = StringVector(s)
        p = 1  # position
        $(code_data)
        if p - 1 < length(data)
            resize!(data, p - 1)
        end
        data
    end
end

@generated format(fmt::Tuple, positionals...; keywords...) =
    :(String($(genformat(fmt, positionals, keywords))))

@generated format(out::IO, fmt::Tuple, positionals...; keywords...) =
    :(write(out, $(genformat(fmt, positionals, keywords))))

function parse_format(fmt::String)
    list = []
    serial = 0
    i = firstindex(fmt)
    while (j = findnext('{', fmt, i)) !== nothing
        j - 1 ≥ i && push!(list, fmt[i:j-1])
        field, i, serial = parse_field(fmt, j + 1, serial)
        push!(list, field)
    end
    lastindex(fmt) ≥ i && push!(list, fmt[i:end])
    return (list...,)
end

function parse_field(fmt::String, i::Int, serial::Int)
    c = fmt[i]  # the first character after '{'
    # check field name
    if c == '}'
        serial += 1
        return SimpleField{serial, Any}(), i + 1, serial
    elseif isdigit(c)
        arg = Int(c - '0')
        i += 1
    elseif 'a' ≤ c ≤ 'z'
        arg = Symbol(c)
        i += 1
    elseif c == ':'
        serial += 1
        arg = serial
    end
    # check spec
    if fmt[i] == ':'
        spec, i = parse_spec(fmt, i + 1)
        return Field{arg, Any}(; spec...), i + 1, serial
    else
        return SimpleField{arg, Any}(), i + 1, serial
    end
end

function parse_spec(fmt::String, i::Int)
    c = fmt[i]  # the first character after ':'

    fill = FILL_UNSPECIFIED
    align = ALIGN_UNSPECIFIED
    if c ∉ ('{', '}') && nextind(fmt, i) ≤ lastindex(fmt) && fmt[nextind(fmt, i)] ∈ ('<', '>')
        # fill + align
        fill = c
        i = nextind(fmt, i)
        align = fmt[i] == '<' ? ALIGN_LEFT : ALIGN_RIGHT
        c = fmt[i+=1]
    elseif c ∈ ('<', '>')
        # align
        fill = ' '
        align = c == '<' ? ALIGN_LEFT : ALIGN_RIGHT
        c = fmt[i+=1]
    end

    sign = SIGN_UNSPECIFIED
    if c ∈ ('-', '+', ' ')
        # sign
        sign = c == '-' ? SIGN_MINUS : c == '+' ? SIGN_PLUS : SIGN_SPACE
        c = fmt[i+=1]
    end

    altform = false
    if c == '#'
        # alternative form (altform)
        altform = true
        c = fmt[i+=1]
    end

    zero = false
    width = WIDTH_UNSPECIFIED
    if isdigit(c)
        # minimum width
        if c == '0' && isdigit(fmt[i+1])
            # preceded by zero
            zero = true
            i += 1
        end
        if fill == FILL_UNSPECIFIED
            fill = ' '
        end
        width = 0
        while isdigit(fmt[i])
            width = 10*width + Int(fmt[i] - '0')
            i += 1
        end
        c = fmt[i]
    end

    type = TYPE_UNSPECIFIED
    if c in ('d', 'X', 'x', 'o', 'b', 's')
        # type
        type = c
        c = fmt[i+=1]
    end

    @assert c == '}'
    return (; fill, align, sign, altform, zero, width, type), i
end

macro f_str(s)
    parse_format(unescape_string(s))
end

end
