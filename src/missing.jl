function formatinfo(s::Spec, ::Missing)
    size = 7  # ncodeunits("missing")
    return size + paddingsize(s, size), nothing
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, ::Missing, ::Nothing)
    align = default(s.align, ALIGN_RIGHT)
    pw = paddingwidth(s, 7)
    p = padleft(data, p, s.fill, align, pw)
    p = @copy data p "missing"
    p = padright(data, p, s.fill, align, pw)
    return p
end
