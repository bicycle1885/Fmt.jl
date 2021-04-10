module Fmt

export @f_str

using Base: StringVector, Ryu

const FILL_UNSPECIFIED = reinterpret(Char, 0xFFFFFFFF)
@enum Alignment::UInt8 ALIGN_UNSPECIFIED ALIGN_LEFT ALIGN_RIGHT
@enum Sign::UInt8 SIGN_PLUS SIGN_MINUS SIGN_SPACE
const SIGN_UNSPECIFIED = SIGN_MINUS
const WIDTH_UNSPECIFIED = nothing
const PRECISION_UNSPECIFIED = -1

# type (Char)         : type specifier ('?' means unspecified)
# arg (Int or Symbol) : argument position or name
struct Field{type, arg, W}
    interp::Bool  # interpolated
    fill::Char
    align::Alignment
    sign::Sign
    altform::Bool
    zero::Bool  # zero padding
    width::W
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
    return Field{type, arg, typeof(width)}(interp, fill, align, sign, altform, zero, width, precision)
end

argument(::Type{Field{_, arg, __}}) where {_, arg, __} = arg
argument(f::Field) = argument(typeof(f))
interpolated(f::Field) = f.interp

paddingwidth(f::Field{_, __, Int}, width::Int) where {_, __} = max(f.width - width, 0)
paddingwidth(f::Field{_, __, Nothing}, width::Int) where {_, __} = 0

paddingsize(f::Field, width::Int) = paddingwidth(f, width) * ncodeunits(f.fill)

# generic fallback
function formatinfo(f::Field, x::Any)
    s = string(x)
    size = ncodeunits(s)
    width = length(s)
    f.width == WIDTH_UNSPECIFIED && return size, (s, width)
    return paddingsize(f, width) + size, (s, width)
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Any, (s, width)::Tuple{String,Int})
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
    end
    n = ncodeunits(x)
    copyto!(data, p, codeunits(x), 1, n)
    p += n
    if f.align != ALIGN_RIGHT
        p = pad(data, p, f.fill, pw)
    end
    return p
end

const Z = UInt8('0')

function formatinfo(f::Field{'c'}, x::Integer)
    char = Char(x)
    size = ncodeunits(char)
    f.width == WIDTH_UNSPECIFIED && return size, char
    return paddingsize(f, 1) + size, char
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field{'c'}, x::Integer, char::Char)
    pw = paddingwidth(f, 1)
    if f.align != ALIGN_LEFT
        p = pad(data, p, f.fill, pw)
    end
    p = pad(data, p, char, 1)
    if f.align == ALIGN_LEFT
        p = pad(data, p, f.fill, pw)
    end
    return p
end

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

function formatinfo(f::Field{type}, x::Integer) where type
    base = type == 'X' || type == 'x' ? 16 : type == 'o' ? 8 : type == 'b' ? 2 : 10
    m = base == 10 ? ndigits_decimal(x) : ndigits(x; base)
    width = m + (x < 0 || f.sign ≠ SIGN_MINUS)
    if f.altform && base != 10
        width += 2  # prefix (0b, 0o, 0x)
    end
    f.width == WIDTH_UNSPECIFIED && return width, m
    return paddingsize(f, width) + width, m
end

@inline function formatfield(data::Vector{UInt8}, p::Int, f::Field{type}, x::Integer, m::Int) where type
    base = type == 'X' || type == 'x' ? 16 : type == 'o' ? 8 : type == 'b' ? 2 : 10
    width = m + (x < 0 || f.sign ≠ SIGN_MINUS) + (f.altform && base ≠ 10 && 2)
    pw = paddingwidth(f, width)
    if f.width != WIDTH_UNSPECIFIED && f.align != ALIGN_LEFT && !f.zero
        p = pad(data, p, f.fill, pw)
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
        p = pad(data, p, f.fill, pw)
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
        if type == 'F' || type == 'E'
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
        if type == 'F' || type == 'E'
            data[p  ] = UInt8('N')
            data[p+1] = UInt8('A')
            data[p+2] = UInt8('N')
        else
            data[p  ] = UInt8('n')
            data[p+1] = UInt8('a')
            data[p+2] = UInt8('n')
        end
        p += 3
    elseif type == 'F' || type == 'f'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = Ryu.writefixed(data, p, x, precision, plus, space, hash)
    elseif type == 'E' || type == 'e'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        expchar = type == 'E' ? UInt8('E') : UInt8('e')
        p = Ryu.writeexp(data, p, x, precision, plus, space, hash, expchar)
    elseif type == '%'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = Ryu.writefixed(data, p, 100x, precision, plus, space, hash)
        data[p] = UInt8('%')
        p += 1
    else
        @assert type == 'G' || type == 'g' || type == '?'
        if type == '?' && isinteger(x)
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
    elseif c == ':'
        serial += 1
        arg = serial
    elseif isdigit(c) && c != '0'
        arg = 0
        while isdigit(fmt[i])
            arg = 10arg + Int(fmt[i] - '0')
            i += 1
        end
    elseif isletter(c) || c == '_'  # FIXME
        arg, i = Meta.parse(fmt, i, greedy = false)
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
    if c in "dXxobcsFfEeGg%"
        # type
        type = c
        c = fmt[i+=1]
    end

    @assert c == '}'
    return (; fill, align, sign, altform, zero, width, precision), type, i
end


# Compiler
# --------

function compile(fmt::String)
    spec = parse_format(unescape_string(fmt))

    # no fields; return static string
    if isempty(spec)
        return "", nothing
    elseif length(spec) == 1 && spec[1] isa String
        return spec[1], nothing
    end

    n_positionals = 0
    keywords = Symbol[]
    interpolated = Symbol[]
    code_info = Expr(:block)
    code_data = Expr(:block)
    for (i, f) in enumerate(spec)
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
            if arg isa Int
                n_positionals = max(arg, n_positionals)
                arg = Symbol(:_, arg)
            else
                if arg ∉ keywords
                    push!(keywords, arg)
                    f.interp && push!(interpolated, arg)
                end
            end
            arg = esc(arg)
            meta = Symbol(:meta, i)
            info = quote
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
