function formatinfo(s::Spec, x::Ptr)
    width = 2sizeof(x) + 2
    return width + paddingsize(s, width), nothing
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::Ptr, ::Nothing)
    w = 2sizeof(x) + 2
    pw = paddingwidth(s, w)
    align = s.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : s.align
    p = padleft(data, p, s.fill, align, pw)
    p = @copy data p "0x"
    p = hexadecimal(data, p, reinterpret(UInt, x), w - 2, false)
    p = padright(data, p, s.fill, align, pw)
    return p
end
