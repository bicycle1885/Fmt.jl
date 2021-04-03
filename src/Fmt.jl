module Fmt

export @f_str, format

using Base: StringVector

const FILL_UNSPECIFIED = reinterpret(Char, 0xFFFFFFFF)
@enum Alignment::UInt8 ALIGN_UNSPECIFIED ALIGN_LEFT ALIGN_RIGHT
const WIDTH_UNSPECIFIED = -1

struct Field{arg, T}
    fill::Char
    align::Alignment
    width::Int  # minimum width
end

function Field{arg, T}(;
        fill = FILL_UNSPECIFIED,
        align = ALIGN_UNSPECIFIED,
        width = WIDTH_UNSPECIFIED,
        ) where {arg, T}
    return Field{arg, T}(fill, align, width)
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
    return n
end

function formatfield(data::Vector{UInt8}, p::Int, field::Field, x::Integer)
    # TODO: optimize
    if field.width == WIDTH_UNSPECIFIED
        s = string(x)
    else
        if field.align == ALIGN_LEFT
            s = rpad(x, field.width, field.fill)
        else
            s = lpad(x, field.width, field.fill)
        end
    end
    n = ncodeunits(s)
    copyto!(data, p, codeunits(s), 1, n)
    return n
end

function formatsize(f::Field, x::AbstractString)
    size = ncodeunits(x) * sizeof(codeunit(x)) 
    return size + max(f.width - length(x), 0)
end

formatsize(f::Field, x::Integer) = max(f.width, ndigits(x) + (x < 0))

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
            data = :(p += formatfield(data, p, fmt[$i], $arg))
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
        fill, align, width, i = parse_spec(fmt, i + 1)
        return Field{arg, Any}(;fill, align, width), i + 1, serial
    else
        return Field{arg, Any}(), i + 1, serial
    end
end

function parse_spec(fmt::String, i::Int)
    fill = FILL_UNSPECIFIED
    align = ALIGN_UNSPECIFIED
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
    return fill, align, width, i
end

macro f_str(s)
    parse_format(unescape_string(s))
end

end
