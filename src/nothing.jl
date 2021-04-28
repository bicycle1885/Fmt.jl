function formatinfo(f::Field, ::Nothing)
    size = ncodeunits("nothing")  # 7 bytes
    return size + paddingsize(f, size), nothing
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, ::Nothing, ::Nothing)
    align = f.align == ALIGN_UNSPECIFIED ? ALIGN_LEFT : f.align
    pw = paddingwidth(f, 7)
    p = padleft(data, p, f.fill, align, pw)
    p = @copy data p "nothing"
    p = padright(data, p, f.fill, align, pw)
    return p
end
