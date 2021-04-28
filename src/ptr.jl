function formatinfo(f::Field, x::Ptr)
    width = 2sizeof(x) + 2
    return width + paddingsize(f, width), nothing
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Ptr, ::Nothing)
    w = 2sizeof(x) + 2
    pw = paddingwidth(f, w)
    align = f.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : f.align
    p = padleft(data, p, f.fill, align, pw)
    p = @copy data p "0x"
    p = hexadecimal(data, p, reinterpret(UInt, x), w - 2, false)
    p = padright(data, p, f.fill, align, pw)
    return p
end
