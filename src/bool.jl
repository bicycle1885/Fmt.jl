function formatinfo(s::Spec, x::Bool)
    if s.type !== nothing
        return formatinfo(s, Int(x))
    end
    width = x ? 4 : 5
    return paddingsize(s, width) + width, (0, width)
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::Bool, (m, width)::Tuple{Int, Int})
    if s.type !== nothing
        return formatfield(data, p, s, Int(x), (m, width))
    end
    align = s.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : s.align
    pw = paddingwidth(s, width)
    p = padleft(data, p, s.fill, align, pw)
    if x
        p = @copy data p "true"
    else
        p = @copy data p "false"
    end
    p = padright(data, p, s.fill, align, pw)
    return p
end
