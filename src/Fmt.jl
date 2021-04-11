module Fmt

export @f_str

using Base: StringVector, Ryu

const FILL_UNSPECIFIED = reinterpret(Char, 0xFFFFFFFF)
@enum Alignment::UInt8 ALIGN_UNSPECIFIED ALIGN_LEFT ALIGN_RIGHT ALIGN_CENTER
@enum Sign::UInt8 SIGN_PLUS SIGN_MINUS SIGN_SPACE
const SIGN_UNSPECIFIED = SIGN_MINUS
const WIDTH_UNSPECIFIED = nothing
@enum Grouping::UInt8 GROUPING_UNSPECIFIED GROUPING_COMMA GROUPING_UNDERSCORE
const PRECISION_UNSPECIFIED = nothing
const TYPE_UNSPECIFIED = nothing

struct Positional
    position::Int
end

struct Keyword
    name::Symbol
    interp::Bool
end

const Argument = Union{Positional, Keyword}

struct Field
    argument::Argument
    fill::Char
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
        fill = FILL_UNSPECIFIED,
        align = ALIGN_UNSPECIFIED,
        sign = SIGN_UNSPECIFIED,
        altform = false,
        zero = false,
        width = WIDTH_UNSPECIFIED,
        grouping = GROUPING_UNSPECIFIED,
        precision = PRECISION_UNSPECIFIED,
        type = TYPE_UNSPECIFIED
        )
    return Field(argument, fill, align, sign, altform, zero, width, grouping, precision, type)
end

function Field(f::Field; width = f.width, precision = f.precision)
    return Field(f.argument, f.fill, f.align, f.sign, f.altform, f.zero, width, f.grouping, precision, f.type)
end

argument(f::Field) = f.argument

@inline function paddingwidth(f::Field, width::Int)
    @assert f.width isa Int || f.width isa Nothing
    if f.width isa Int
        return max(f.width - width, 0)
    else
        return 0
    end
end
paddingsize(f::Field, width::Int) = paddingwidth(f, width) * ncodeunits(f.fill)

# generic fallback
function formatinfo(f::Field, x::Any)
    s = string(x)
    size = ncodeunits(s)
    width = length(s)
    f.width == WIDTH_UNSPECIFIED && return size, (s, width)
    return paddingsize(f, width) + size, (s, width)
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Any, (s, width)::Tuple{String, Int})
    pw = paddingwidth(f, width)
    if f.width != WIDTH_UNSPECIFIED && f.align == ALIGN_RIGHT
        p = pad(data, p, f.fill, pw)
    end
    n = ncodeunits(s)
    copyto!(data, p, codeunits(s), 1, n)
    p += n
    if f.width != WIDTH_UNSPECIFIED && f.align != ALIGN_RIGHT
        p = pad(data, p, f.fill, pw)
    end
    return p
end

function formatinfo(f::Field, x::AbstractChar)
    c = Char(x)
    size = ncodeunits(c)
    f.width == WIDTH_UNSPECIFIED && return size, c
    return paddingsize(f, 1) + size, c
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, ::AbstractChar, c::Char)
    pw = paddingwidth(f, 1)
    if f.width != WIDTH_UNSPECIFIED && f.align == ALIGN_RIGHT
        p = pad(data, p, f.fill, pw)
    end
    m = ncodeunits(c)
    x = reinterpret(UInt32, c) >> 8(4 - m)
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
    p += m
    if f.width != WIDTH_UNSPECIFIED && f.align != ALIGN_RIGHT
        p = pad(data, p, f.fill, pw)
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
    if f.align == ALIGN_RIGHT
        p = pad(data, p, f.fill, pw)
    elseif f.align == ALIGN_CENTER
        p = pad(data, p, f.fill, pw ÷ 2)
    end
    n = ncodeunits(x)
    copyto!(data, p, codeunits(x), 1, n)
    p += n
    if f.align == ALIGN_LEFT || f.align == ALIGN_UNSPECIFIED
        p = pad(data, p, f.fill, pw)
    elseif f.align == ALIGN_CENTER
        p = pad(data, p, f.fill, pw - pw ÷ 2)
    end
    return p
end

const Z = UInt8('0')

function formatinfo(f::Field, x::Bool)
    # true (4) or false (5)
    width = x ? 4 : 5
    return paddingsize(f, width) + width, nothing
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Bool, ::Nothing)
    width = x ? 4 : 5
    pw = paddingwidth(f, 0)
    if f.width != WIDTH_UNSPECIFIED && f.align != ALIGN_LEFT
        p = pad(data, p, f.fill, pw)
    end
    if x
        data[p]   = UInt8('t')
        data[p+1] = UInt8('r')
        data[p+2] = UInt8('u')
        data[p+3] = UInt8('e')
        p += 4
    else
        data[p]   = UInt8('f')
        data[p+1] = UInt8('a')
        data[p+2] = UInt8('l')
        data[p+3] = UInt8('s')
        data[p+4] = UInt8('e')
        p += 5
    end
    if f.width != WIDTH_UNSPECIFIED && f.align == ALIGN_LEFT
        p = pad(data, p, f.fill, pw)
    end
    return p
end

@inline function formatinfo(f::Field, x::Integer)
    if f.type == 'c'
        char = Char(x)
        size = ncodeunits(char)
        f.width == WIDTH_UNSPECIFIED && return size, 0
        return paddingsize(f, 1) + size, 0
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
    f.width == WIDTH_UNSPECIFIED && return width, m
    return paddingsize(f, width) + width, m
end

@inline function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Integer, m::Int)
    base = f.type == 'X' || f.type == 'x' ? 16 : f.type == 'o' ? 8 : f.type == 'B' || f.type == 'b' ? 2 : 10
    if f.type == 'c'
        width = 1
    else
        width = m + (x < 0 || f.sign ≠ SIGN_MINUS) + (f.altform && base ≠ 10 && 2)
    end
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
    if f.zero
        p = pad(data, p, '0', pw)
    end
    if f.type == 'c'
        p = pad(data, p, Char(x), 1)
        @goto right
    end
    u = unsigned(abs(x))
    if f.grouping == GROUPING_UNSPECIFIED
        if base == 16
            p = hexadecimal(data, p, u, m, f.type == 'X', f.altform)
        elseif base == 10
            p = decimal(data, p, u, m)
        elseif base == 8
            p = octal(data, p, u, m, f.altform)
        elseif base == 2
            p = binary(data, p, u, m, f.type == 'B', f.altform)
        else
            @assert false "invalid base"
        end
    else
        if base == 16
            p = hexadecimal_grouping(data, p, u, m, f.type == 'X', f.altform)
        elseif base == 10
            p = decimal_grouping(data, p, u, m, f.grouping == GROUPING_COMMA ? UInt8(',') : UInt8('_'))
        elseif base == 8
            p = octal_grouping(data, p, u, m, f.altform)
        elseif base == 2
            p = binary_grouping(data, p, u, m, f.type == 'B', f.altform)
        else
            @assert false "invalid base"
        end
    end
    @label right
    if f.width != WIDTH_UNSPECIFIED && !f.zero
        if f.align == ALIGN_LEFT
            p = pad(data, p, f.fill, pw)
        elseif f.align == ALIGN_CENTER
            p = pad(data, p, f.fill, pw - pw ÷ 2)
        end
    end
    return p
end

function binary(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, uppercase::Bool, altform::Bool)
    if altform
        data[p  ] = Z
        data[p+1] = uppercase ? UInt8('B') : UInt8('b')
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

function binary_grouping(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, uppercase::Bool, altform::Bool)
    if altform
        data[p  ] = Z
        data[p+1] = uppercase ? UInt8('B') : UInt8('b')
        p += 2
    end
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
    binary(data, p, x, n, false, false)
    return p + m + k
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

function octal_grouping(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, altform::Bool)
    if altform
        data[p  ] = Z
        data[p+1] = UInt8('o')
        p += 2
    end
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
    octal(data, p, x, n, false)
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

function hexadecimal_grouping(data::Vector{UInt8}, p::Int, x::Unsigned, m::Int, uppercase::Bool, altform::Bool)
    if altform
        data[p  ] = Z
        data[p+1] = uppercase ? UInt8('X') : UInt8('x')
        p += 2
    end
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
    hexadecimal(data, p, x, n, uppercase, false)
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

function formatinfo(f::Field, x::AbstractFloat)
    return Ryu.neededdigits(typeof(x)), nothing
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::AbstractFloat, info)
    # default parameters of Ryu.writeshortest
    precision = -1
    expchar = UInt8('e')
    padexp = false
    decchar = UInt8('.')
    typed = false
    compact = false

    if f.sign == SIGN_SPACE
        plus = false
        space = true
    elseif f.sign == SIGN_PLUS
        plus = true
        space = false
    else
        plus = false
        space = false
    end
    
    if f.altform
        hash = true
    else
        hash = false
    end

    start = p
    if isinf(x)
        if x < 0
            data[p] = UInt8('-')
            p += 1
        elseif plus
            data[p] = UInt8('+')
            p += 1
        elseif space
            data[p] = UInt8(' ')
            p += 1
        end
        if f.type == 'F' || f.type == 'E'
            data[p  ] = UInt8('I')
            data[p+1] = UInt8('N')
            data[p+2] = UInt8('F')
        else
            data[p  ] = UInt8('i')
            data[p+1] = UInt8('n')
            data[p+2] = UInt8('f')
        end
        p += 3
    elseif isnan(x)
        if f.type == 'F' || f.type == 'E'
            data[p  ] = UInt8('N')
            data[p+1] = UInt8('A')
            data[p+2] = UInt8('N')
        else
            data[p  ] = UInt8('n')
            data[p+1] = UInt8('a')
            data[p+2] = UInt8('n')
        end
        p += 3
    elseif f.type == 'F' || f.type == 'f'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = Ryu.writefixed(data, p, x, precision, plus, space, hash)
    elseif f.type == 'E' || f.type == 'e'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        expchar = f.type == 'E' ? UInt8('E') : UInt8('e')
        p = Ryu.writeexp(data, p, x, precision, plus, space, hash, expchar)
    elseif f.type == '%'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = Ryu.writefixed(data, p, 100x, precision, plus, space, hash)
        data[p] = UInt8('%')
        p += 1
    else
        @assert f.type == 'G' || f.type == 'g' || f.type == nothing
        if f.type == nothing && isinteger(x)
            hash = true
        end
        if f.precision != PRECISION_UNSPECIFIED
            padexp = true
            precision = max(f.precision, 1)
            x = round(x, sigdigits = precision)
        end
        p = Ryu.writeshortest(data, p, x, plus, space, hash, precision, expchar, padexp, decchar, typed, compact)
    end

    if f.width != WIDTH_UNSPECIFIED
        width = p - start
        pw = paddingwidth(f, width)
        if f.zero
            if x < 0 || x === -zero(x) || f.sign == SIGN_PLUS || f.sign == SIGN_SPACE
                start += 1
                width -= 1
            end
            copyto!(data, start + pw, data, start, width)
            pad(data, start, '0', pw)
            p += pw
        elseif f.align != ALIGN_LEFT
            ps = paddingsize(f, width)
            copyto!(data, start + ps, data, start, width)
            pad(data, start, f.fill, pw)
            p += ps
        elseif f.align == ALIGN_LEFT
            p = pad(data, p, f.fill, pw)
        end
    end
    return p
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


# Parser
# ------

function parse_format(fmt::String)
    list = []
    serial = 0
    i = firstindex(fmt)
    while (j = findnext('{', fmt, i)) !== nothing
        j - 1 ≥ i && push!(list, fmt[i:prevind(fmt, j)])
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
        return Field(Positional(serial)), i + 1, serial
    elseif c == ':'
        serial += 1
        arg = Positional(serial)
    else
        arg, i, serial = parse_argument(fmt, i, serial)
    end

    # check spec
    if fmt[i] == ':'
        spec, i, serial = parse_spec(fmt, i + 1, serial)
        return Field(arg; spec...), i + 1, serial
    else
        return Field(arg), i + 1, serial
    end
end

function parse_spec(fmt::String, i::Int, serial::Int)
    c = fmt[i]  # the first character after ':'

    fill = ' '
    align = ALIGN_UNSPECIFIED
    if c ∉ ('{', '}') && nextind(fmt, i) ≤ lastindex(fmt) && fmt[nextind(fmt, i)] ∈ ('<', '^', '>')
        # fill + align
        fill = c
        i = nextind(fmt, i)
        align = fmt[i] == '<' ? ALIGN_LEFT : fmt[i] == '^' ? ALIGN_CENTER : ALIGN_RIGHT
        c = fmt[i+=1]
    elseif c ∈ ('<', '^', '>')
        # align
        fill = ' '
        align = c == '<' ? ALIGN_LEFT : c == '^' ? ALIGN_CENTER : ALIGN_RIGHT
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
    if c == '{'
        width, i, serial = parse_argument(fmt, i + 1, serial)
        @assert fmt[i] == '}'
        c = fmt[i+=1]
    elseif isdigit(c)
        # minimum width
        if c == '0' && isdigit(fmt[i+1])
            # preceded by zero
            zero = true
            i += 1
        end
        width = 0
        while isdigit(fmt[i])
            width = 10*width + Int(fmt[i] - '0')
            i += 1
        end
        c = fmt[i]
    end

    grouping = GROUPING_UNSPECIFIED
    if c == ','
        grouping = GROUPING_COMMA
        c = fmt[i+=1]
    elseif c == '_'
        grouping = GROUPING_UNDERSCORE
        c = fmt[i+=1]
    end

    precision = PRECISION_UNSPECIFIED
    if c == '.'
        # precision
        i += 1
        if fmt[i] == '{'
            precision, i, serial = parse_argument(fmt, i + 1, serial)
            @assert fmt[i] == '}'
            c = fmt[i+=1]
        else
            @assert isdigit(fmt[i])
            precision = 0
            while isdigit(fmt[i])
                precision = 10precision + Int(fmt[i] - '0')
                i += 1
            end
            c = fmt[i]
        end
    end

    type = TYPE_UNSPECIFIED
    if c in "dXxoBbcsFfEeGg%"
        type = c
        c = fmt[i+=1]
    end

    @assert c == '}'
    return (; fill, align, sign, altform, zero, width, grouping, precision, type), i, serial
end

function parse_argument(s::String, i::Int, serial::Int)
    c = s[i]  # the first character after '{'
    if c == '}'
        serial += 1
        arg = Positional(serial)
    elseif isdigit(c)
        n = 0
        while isdigit(s[i])
            n = 10n + Int(s[i] - '0')
            i += 1
        end
        arg = Positional(n)
    elseif c == '$'
        name, i = Meta.parse(s, i + 1, greedy = false)
        arg = Keyword(name, true)
    elseif isletter(c) || c == '_'
        name, i = Meta.parse(s, i, greedy = false)
        arg = Keyword(name, false)
    else
        @assert false
    end
    @assert s[i] == '}' || s[i] == ':'
    return arg, i, serial
end


# Compiler
# --------

function compile(fmt::String)
    format = parse_format(unescape_string(fmt))

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
            arg = argument(f)
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

            f = :(Field($f, width = $(esc(width)), precision = $(esc(precision))))
            meta = Symbol(:meta, i)
            info = quote
                s, $meta = formatinfo($f, $x)
                size += s
            end
            data = :(p = formatfield(data, p, $f, $x, $meta))
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

struct Format{F}
    str::String
    fun::F
end

Base.show(out::IO, fmt::Format) = print(out, "f\"", fmt.str, '"')

format(fmt::String) = fmt
format(fmt::Format, positionals...; keywords...) = fmt.fun(positionals...; keywords...)
format(out::IO, fmt::Format, positionals...; keywords...) = write(out, fmt.fun(positionals...; keywords...))

macro f_str(s)
    code, interped = compile(s)
    if code isa String
        code
    elseif isempty(interped)
        :(Format($s, $code))
    else
        :($(code)(; $(esc.(interped)...)))
    end
end

end
