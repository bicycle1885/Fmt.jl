function formatinfo(f::Field, x::Bool)
    if f.type !== nothing
        return formatinfo(f, Int(x))
    end
    width = x ? 4 : 5
    return paddingsize(f, width) + width, (0, width)
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Bool, (m, width)::Tuple{Int, Int})
    if f.type !== nothing
        return formatfield(data, p, f, Int(x), (m, width))
    end
    align = f.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : f.align
    pw = paddingwidth(f, width)
    p = padleft(data, p, f.fill, align, pw)
    if x
        p = @copy data p "true"
    else
        p = @copy data p "false"
    end
    p = padright(data, p, f.fill, align, pw)
    return p
end
