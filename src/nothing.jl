function formatinfo(s::Spec, ::Nothing)
    size = 7  # ncodeunits("nothing")
    return size + paddingsize(s, size), nothing
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, ::Nothing, ::Nothing)
    align = default(s.align, ALIGN_LEFT)
    pw = paddingwidth(s, 7)
    p = padleft(data, p, s.fill, align, pw)
    p = @copy data p "nothing"
    p = padright(data, p, s.fill, align, pw)
    return p
end
