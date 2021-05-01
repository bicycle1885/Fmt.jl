function formatinfo(s::Spec, x::AbstractChar)
    c = Char(x)
    size = ncodeunits(c)
    return size + paddingsize(s, 1), c
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, ::AbstractChar, c::Char)
    align = default(s.align, ALIGN_LEFT)
    pw = paddingwidth(s, 1)
    p = padleft(data, p, s.fill, align, pw)
    p = char(data, p, c)
    p = padright(data, p, s.fill, align, pw)
    return p
end
