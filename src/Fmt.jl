module Fmt

export @f_str, format

struct Field{arg, T}
end

argument(::Type{Field{arg, _}}) where {arg, _} = arg

function formatfield(out::IO, field::Field, x)
    print(out, x)
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
    n = 0
    i = firstindex(fmt)
    while (j = findnext('{', fmt, i)) !== nothing
        j - 1 ≥ i && push!(list, fmt[i:j-1])
        j += 1
        if fmt[j] == '}'
            # automatically numbered field
            n += 1
            push!(list, Field{n, Any}())
        elseif isdigit(fmt[j])
            # numbered field
            number = Int(fmt[j] - '0')
            push!(list, Field{number, Any}())
            j += 1
        else
            # named field
            name = Symbol(fmt[j])
            push!(list, Field{name, Any}())
            j += 1
        end
        i = j + 1
    end
    lastindex(fmt) ≥ i && push!(list, fmt[i:end])
    return (list...,)
end

macro f_str(s)
    parse_format(unescape_string(s))
end

end
