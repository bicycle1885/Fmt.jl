module Fmt

export @f_str, format

using Base: StringVector, Ryu

const FILL_UNSPECIFIED = reinterpret(Char, 0xFFFFFFFF)
@enum Alignment::UInt8 ALIGN_UNSPECIFIED ALIGN_LEFT ALIGN_RIGHT
@enum Sign::UInt8 SIGN_PLUS SIGN_MINUS SIGN_SPACE
const SIGN_UNSPECIFIED = SIGN_MINUS
const WIDTH_UNSPECIFIED = -1
const PRECISION_UNSPECIFIED = -1

# type (Char)         : type specifier ('?' means unspecified)
# arg (Int or Symbol) : argument position or name
struct Field{type, arg}
    interp::Bool  # interpolated
    fill::Char
    align::Alignment
    sign::Sign
    altform::Bool
    zero::Bool  # zero padding
    width::Int  # minimum width
    precision::Int  # precision
end

function Field{type, arg}(
        interp;
        fill = FILL_UNSPECIFIED,
        align = ALIGN_UNSPECIFIED,
        sign = SIGN_UNSPECIFIED,
        altform = false,
        zero = false,
        width = WIDTH_UNSPECIFIED,
        precision = PRECISION_UNSPECIFIED,
        ) where {type, arg}
    return Field{type, arg}(interp, fill, align, sign, altform, zero, width, precision)
end

argument(::Type{Field{_, arg}}) where {_, arg} = arg
argument(f::Field) = argument(typeof(f))
interpolated(f::Field) = f.interp

function formatinfo(f::Field, x::AbstractString)
    size = ncodeunits(x) * sizeof(codeunit(x)) 
    len = length(x)
    f.width == WIDTH_UNSPECIFIED && return size, len
    return ncodeunits(f.fill) * max(f.width - len, 0) + size, len
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::AbstractString, len::Int)
    padwidth = max(f.width - len, 0)
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

function formatinfo(f::Field{'c'}, x::Integer)
    char = Char(x)
    size = ncodeunits(char)
    f.width == WIDTH_UNSPECIFIED && return size, char
    return ncodeunits(f.fill) * max(f.width - 1, 0) + size, char
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field{'c'}, x::Integer, char::Char)
    width = 1
    padwidth = max(f.width - width, 0)
    if f.align != ALIGN_LEFT
        p = pad(data, p, f.fill, padwidth)
    end
    p = pad(data, p, char, 1)
    if f.align == ALIGN_LEFT
        p = pad(data, p, f.fill, padwidth)
    end
    return p
end

function formatinfo(f::Field{type}, x::Integer) where type
    base = type == 'X' || type == 'x' ? 16 : type == 'o' ? 8 : type == 'b' ? 2 : 10
    m = base == 10 ? ndigits_decimal(x) : ndigits(x; base)
    w = m + (x < 0 || f.sign ≠ SIGN_MINUS)
    if f.altform && base != 10
        w += 2  # prefix (0b, 0o, 0x)
    end
    f.width == WIDTH_UNSPECIFIED && return w, m
    return ncodeunits(f.fill) * max(f.width - w, 0) + w, m
end

@inline function formatfield(data::Vector{UInt8}, p::Int, f::Field{type}, x::Integer, m::Int) where type
    base = type == 'X' || type == 'x' ? 16 : type == 'o' ? 8 : type == 'b' ? 2 : 10
    width = m + (x < 0 || f.sign ≠ SIGN_MINUS) + (f.altform && base ≠ 10 && 2)
    padwidth = max(f.width - width, 0)
    if f.width != WIDTH_UNSPECIFIED && f.align != ALIGN_LEFT && !f.zero
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
    u = unsigned(abs(x))
    if base == 16
        p = hexadecimal(data, p, u, m, type == 'X', f.altform)
    elseif base == 10
        p = decimal(data, p, u, m)
    elseif base == 8
        p = octal(data, p, u, m, f.altform)
    elseif base == 2
        p = binary(data, p, u, m, f.altform)
    else
        @assert false "invalid base"
    end
    if f.width != WIDTH_UNSPECIFIED && f.align == ALIGN_LEFT
        p = pad(data, p, f.fill, padwidth)
    end
    return p
end

function binary(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, altform::Bool)
    if altform
        data[p  ] = Z
        data[p+1] = UInt8('b')
        p += 2
    end
    n = m
    while n > 0
        r = (x & 0x1) % UInt8
        data[p+n-1] = r + Z
        x >>= 1
        n -= 1
    end
    return p + m
end

function octal(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, altform::Bool)
    if altform
        data[p  ] = Z
        data[p+1] = UInt8('o')
        p += 2
    end
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

const HEXADECIMAL_DIGITS_UPPERCASE = zeros(UInt16, 256)
const HEXADECIMAL_DIGITS_LOWERCASE = zeros(UInt16, 256)
for x in 0:255
    d, r = divrem(x, 16)
    A = UInt8('A')
    HEXADECIMAL_DIGITS_UPPERCASE[x+1] = ((d < 10 ? d + Z : d - 10 + A) << 8) % UInt16 + (r < 10 ? r + Z : r - 10 + A) % UInt8
    A = UInt8('a')
    HEXADECIMAL_DIGITS_LOWERCASE[x+1] = ((d < 10 ? d + Z : d - 10 + A) << 8) % UInt16 + (r < 10 ? r + Z : r - 10 + A) % UInt8
end

function hexadecimal(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, uppercase::Bool, altform::Bool)
    if altform
        data[p  ] = Z
        data[p+1] = uppercase ? UInt8('X') : UInt8('x')
        p += 2
    end
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

function formatinfo(f::Field, x::AbstractFloat)
    return Ryu.neededdigits(typeof(x)), nothing
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field{type}, x::AbstractFloat, info) where type
    # default parameters of Ryu.writeshortest
    plus = false
    space = false
    hash = true
    precision = -1
    expchar = UInt8('e')
    padexp = false
    decchar = UInt8('.')
    typed = false
    compact = false
    if type == 'f'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        return Ryu.writefixed(data, p, x, precision)
    elseif f.precision != PRECISION_UNSPECIFIED
        precision = f.precision
        x = round(x, sigdigits = precision)
    end
    return Ryu.writeshortest(data, p, x, plus, space, hash, precision, expchar, padexp, decchar, typed, compact)
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
    code_info = Expr(:block)  # compute data size and other info
    code_data = Expr(:block)  # write data
    for (i, F) in enumerate(fmt.types)
        if F === String
            info = :(size += ncodeunits(fmt[$i]))
            data = quote
                n = ncodeunits(fmt[$i])
                copyto!(data, p, codeunits(fmt[$i]), 1, n)
                p += n
            end
        else
            @assert F <: Field
            arg = argument(F)
            if arg isa Int
                arg = :(positionals[$arg])
            else
                @assert arg isa Symbol
                arg = :(keywords[$(QuoteNode(arg))])
            end
            info = quote
                s, $(Symbol(:info, i)) = formatinfo(fmt[$i], $arg)
                size += s
            end
            data = :(p = formatfield(data, p, fmt[$i], $arg, $(Symbol(:info, i))))
        end
        push!(code_info.args, info)
        push!(code_data.args, data)
    end
    return quote
        size = 0  # size
        $(code_info)
        data = StringVector(size)
        p = 1  # position
        $(code_data)
        if p - 1 < size
            resize!(data, p - 1)
        end
        data
    end
end

function genformatstring(fmt)
    if length(fmt) == 0
        return ""
    elseif length(fmt) == 1 && fmt[1] isa String
        return fmt[1]
    end
    code_info = Expr(:block)  # compute data size and other info
    code_data = Expr(:block)  # write data
    for (i, f) in enumerate(fmt)
        if f isa String
            info = :(size += ncodeunits($f))
            n = ncodeunits(f)
            data = if n < 8
                # expand short copy loop
                quote
                    @inbounds $(genstrcopy(f))
                    p += $n
                end
            else
                quote
                    copyto!(data, p, codeunits($f), 1, $n)
                    p += $n
                end
            end
        else
            @assert f isa Field
            arg = argument(f)
            @assert arg isa Symbol
            arg = esc(arg)
            info = quote
                s, $(Symbol(:info, i)) = formatinfo($f, $arg)
                size += s
            end
            data = :(p = formatfield(data, p, $f, $arg, $(Symbol(:info, i))))
        end
        push!(code_info.args, info)
        push!(code_data.args, data)
    end
    return quote
        size = 0  # size
        $(code_info)
        data = StringVector(size)
        p = 1  # position
        $(code_data)
        if p - 1 < size
            resize!(data, p - 1)
        end
        String(data)
    end
end

function genstrcopy(s::String)
    n = ncodeunits(s)
    code = Expr(:block)
    for i in 1:n
        push!(code.args, :(data[p+$i-1] = $(codeunit(s, i))))
    end
    return code
end

@generated format(fmt::Tuple, positionals...; keywords...) =
    :(String($(genformat(fmt, positionals, keywords))))

@generated format(out::IO, fmt::Tuple, positionals...; keywords...) =
    :(write(out, $(genformat(fmt, positionals, keywords))))

format(s::String) = s

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
    interp = false
    if fmt[i] == '$'
        # interpolation
        interp = true
        c = fmt[i+=1]
    end

    # check field name
    if c == '}'
        serial += 1
        return Field{'?', serial}(false), i + 1, serial
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
        spec, type, i = parse_spec(fmt, i + 1)
        return Field{type, arg}(interp; spec...), i + 1, serial
    else
        return Field{'?', arg}(interp), i + 1, serial
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

    precision = PRECISION_UNSPECIFIED
    if c == '.'
        # precision
        i += 1
        precision = 0
        while isdigit(fmt[i])
            precision = 10precision + Int(fmt[i] - '0')
            i += 1
        end
        c = fmt[i]
    end

    type = '?'  # unspecified
    if c in ('d', 'X', 'x', 'o', 'b', 'c', 's', 'f')
        # type
        type = c
        c = fmt[i+=1]
    end

    @assert c == '}'
    return (; fill, align, sign, altform, zero, width, precision), type, i
end

is_all_interpolated(fmt) =
    all(f isa String || interpolated(f) for f in fmt)

macro f_str(s)
    fmt = parse_format(unescape_string(s))
    if is_all_interpolated(fmt)
        genformatstring(fmt)
    else
        fmt
    end
end

end
