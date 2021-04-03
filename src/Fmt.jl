module Fmt

export @f_str, format

struct Field{arg, T}
    width::Int  # minimum width
end

argument(::Type{Field{arg, _}}) where {arg, _} = arg

function formatfield(out::IO, field::Field, x)
    print(out, rpad(x, field.width))
end

function formatfield(out::IO, field::Field, x::Integer)
    print(out, lpad(x, field.width))
end

function genformat(fmt, positionals, keywords)
    body = Expr(:block)
    for (i, F) in enumerate(fmt.types)
        if F === String
            push!(body.args, :(print(out, fmt[$i])))
        else
            @assert F <: Field
            arg = argument(F)
            if arg isa Int
                push!(body.args, :(formatfield(out, fmt[$i], positionals[$arg])))
            else
                @assert arg isa Symbol
                push!(body.args, :(formatfield(out, fmt[$i], keywords[$(QuoteNode(arg))])))
            end
        end
    end
    return body
end

@generated format(out::IO, fmt::Tuple, positionals...; keywords...) =
    genformat(fmt, positionals, keywords)

function format(fmt::Tuple, positionals...; keywords...)
    buf = IOBuffer()
    format(buf, fmt, positionals...; keywords...)
    return String(take!(buf))
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
    if c == '}'
        serial += 1
        return Field{serial, Any}(-1), i + 1, serial
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
    c = fmt[i]
    width = -1
    if c == ':'
        i += 1
        width = 0
        while isdigit(fmt[i])
            width = 10*width + Int(fmt[i] - '0')
            i += 1
        end
    end
    @assert fmt[i] == '}'
    return Field{arg, Any}(width), i + 1, serial
end

macro f_str(s)
    parse_format(unescape_string(s))
end

end
