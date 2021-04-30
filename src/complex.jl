function formatinfo(f::Field, x::Complex)
    f′ = Field(f, width = nothing, sign = SIGN_NONE)
    size1, meta1 = formatinfo(f′, real(x))
    size2, meta2 = formatinfo(f′, imag(x))
    size = size1 + size2 + 5  # " + " and "im"
    return size, (meta1, meta2)
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Complex, (meta1, meta2))
    start = p
    p, _ = sign(data, p, real(x), f.sign)
    f′ = Field(f, width = nothing, sign = SIGN_NONE)
    p = formatfield(data, p, f′, real(x), meta1)
    if signbit(imag(x))
        p = @copy data p " - "
    else
        p = @copy data p " + "
    end
    p = formatfield(data, p, f′, imag(x), meta2)
    p = @copy data p "im"
    if f.width != WIDTH_UNSPECIFIED
        align = f.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : f.align
        p = aligncontent(data, p, start, p - start, f.fill, align, f.width)
    end
    return p
end