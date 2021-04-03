module Fmt

export @f_str, format

using Base: StringVector

const FILL_UNSPECIFIED = reinterpret(Char, 0xFFFFFFFF)
@enum Alignment::UInt8 ALIGN_UNSPECIFIED ALIGN_LEFT ALIGN_RIGHT
@enum Sign::UInt8 SIGN_PLUS SIGN_MINUS SIGN_SPACE
const SIGN_UNSPECIFIED = SIGN_MINUS
const WIDTH_UNSPECIFIED = -1

struct Field{arg, T}
    fill::Char
    align::Alignment
    sign::Sign
    width::Int  # minimum width
end

function Field{arg, T}(;
        fill = FILL_UNSPECIFIED,
        align = ALIGN_UNSPECIFIED,
        sign = SIGN_UNSPECIFIED,
        width = WIDTH_UNSPECIFIED,
        ) where {arg, T}
    return Field{arg, T}(fill, align, sign, width)
end

argument(::Type{Field{arg, _}}) where {arg, _} = arg

function formatfield(data::Vector{UInt8}, p::Int, field::Field, x::Any)
    if field.width == WIDTH_UNSPECIFIED
        s = string(x)
    else
        if field.align == ALIGN_RIGHT
            s = lpad(x, field.width, field.fill)
        else
            s = rpad(x, field.width, field.fill)
        end
    end
    n = ncodeunits(s)
    copyto!(data, p, codeunits(s), 1, n)
    return p + n
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Integer)
    width = ndigits(x) + (x < 0 || f.sign ≠ SIGN_MINUS)
    padwidth = max(f.width - width, 0)
    if f.align != ALIGN_LEFT
        p = pad(data, p, f.fill, padwidth)
    end
    if x ≥ 0 && f.sign == SIGN_SPACE
        data[p] = UInt8(' ')
        p += 1
    elseif x ≥ 0 && f.sign == SIGN_PLUS
        data[p] = UInt8('+')
        p += 1
    elseif x < 0
        data[p] = UInt8('-')
        p += 1
    end
    p = decimal(data, p, unsigned(abs(x)))
    if f.align == ALIGN_LEFT
        p = pad(data, p, f.fill, padwidth)
    end
    return p
end

const Z = UInt8('0')
const DECIMAL_DIGITS = [let (d, r) = divrem(x, 10); ((d + Z) << 8) % UInt16 + (r + Z) % UInt8; end for x in 0:99]

function decimal(data::Vector{UInt8}, p::Int, x::Unsigned)
    m = n = ndigits(x)
    while n ≥ 2
        x, r = divrem(x, 100)
        dd = DECIMAL_DIGITS[(r % Int) + 1]
        data[p+n-1] =  dd       % UInt8
        data[p+n-2] = (dd >> 8) % UInt8
        n -= 2
    end
    if n > 0
        data[p] = (rem(x, 10) % UInt8) + Z
    end
    return p + m
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

function formatsize(f::Field, x::AbstractString)
    size = ncodeunits(x) * sizeof(codeunit(x)) 
    f.width == WIDTH_UNSPECIFIED && return size
    return ncodeunits(f.fill) * max(f.width - length(x), 0) + size
end

function formatsize(f::Field, x::Integer)
    w = ndigits(x) + (x < 0 || f.sign ≠ SIGN_MINUS)
    f.width == WIDTH_UNSPECIFIED && return w
    return ncodeunits(f.fill) * max(f.width - w, 0) + w
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
            @assert F <: Field
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
        data
    end
end

@generated format(fmt::Tuple, positionals...; keywords...) =
    :(String($(genformat(fmt, positionals, keywords))))

function format(out::IO, fmt::Tuple, positionals...; keywords...)
    write(out, format(fmt, positionals...; keywords...))
    nothing
end

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
        return Field{serial, Any}(), i + 1, serial
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
        fill, align, sign, width, i = parse_spec(fmt, i + 1)
        return Field{arg, Any}(;fill, align, sign, width), i + 1, serial
    else
        return Field{arg, Any}(), i + 1, serial
    end
end

function parse_spec(fmt::String, i::Int)
    fill = FILL_UNSPECIFIED
    align = ALIGN_UNSPECIFIED
    sign = SIGN_UNSPECIFIED
    width = WIDTH_UNSPECIFIED
    c = fmt[i]  # the first character after ':'

    if c ∉ ('{', '}') && nextind(fmt, i) ≤ lastindex(fmt) && fmt[nextind(fmt, i)] ∈ ('<', '>')
        # fill + align
        fill = c
        i = nextind(fmt, i)
        align = fmt[i] == '<' ? ALIGN_LEFT : ALIGN_RIGHT
        i += 1
        c = fmt[i]
    elseif c ∈ ('<', '>')
        # align
        fill = ' '
        align = c == '<' ? ALIGN_LEFT : ALIGN_RIGHT
        i += 1
        c = fmt[i]
    end

    if c ∈ ('-', '+', ' ')
        # sign
        sign = c == '-' ? SIGN_MINUS : c == '+' ? SIGN_PLUS : SIGN_SPACE
        i += 1
        c = fmt[i]
    end

    if isdigit(c)
        # width
        if fill == FILL_UNSPECIFIED
            fill = ' '
        end
        width = 0
        while isdigit(fmt[i])
            width = 10*width + Int(fmt[i] - '0')
            i += 1
        end
    end

    @assert fmt[i] == '}'
    return fill, align, sign, width, i
end

macro f_str(s)
    parse_format(unescape_string(s))
end

end
