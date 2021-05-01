function formatinfo(s::Spec, ::Missing)
    size = ncodeunits("missing")  # 7 bytes
    return size + paddingsize(s, size), nothing
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, ::Missing, ::Nothing)
    align = s.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : s.align
    pw = paddingwidth(s, 7)
    p = padleft(data, p, s.fill, align, pw)
    p = @copy data p "missing"
    p = padright(data, p, s.fill, align, pw)
    return p
end
