function formatinfo(s::Spec, ::Nothing)
    size = ncodeunits("nothing")  # 7 bytes
    return size + paddingsize(s, size), nothing
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, ::Nothing, ::Nothing)
    align = s.align == ALIGN_UNSPECIFIED ? ALIGN_LEFT : s.align
    pw = paddingwidth(s, 7)
    p = padleft(data, p, s.fill, align, pw)
    p = @copy data p "nothing"
    p = padright(data, p, s.fill, align, pw)
    return p
end
