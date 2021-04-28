function formatinfo(f::Field, x::AbstractChar)
    c = Char(x)
    size = ncodeunits(c)
    return size + paddingsize(f, 1), c
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, ::AbstractChar, c::Char)
    align = f.align == ALIGN_UNSPECIFIED ? ALIGN_LEFT : f.align
    pw = paddingwidth(f, 1)
    p = padleft(data, p, f.fill, align, pw)
    p = char(data, p, c)
    p = padright(data, p, f.fill, align, pw)
    return p
end
