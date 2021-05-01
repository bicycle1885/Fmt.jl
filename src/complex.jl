function formatinfo(s::Spec, x::Complex)
    s′ = Spec(s, width = nothing, sign = SIGN_NONE)
    size1, meta1 = formatinfo(s′, real(x))
    size2, meta2 = formatinfo(s′, imag(x))
    size = size1 + size2 + 5  # " + " and "im"
    return size, (meta1, meta2)
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::Complex, (meta1, meta2))
    start = p
    p, _ = sign(data, p, real(x), s.sign)
    s′ = Spec(s, width = nothing, sign = SIGN_NONE)
    p = formatfield(data, p, s′, real(x), meta1)
    if signbit(imag(x))
        p = @copy data p " - "
    else
        p = @copy data p " + "
    end
    p = formatfield(data, p, s′, imag(x), meta2)
    p = @copy data p "im"
    if isspecified(s.width)
        p = aligncontent(data, p, start, p - start, s.fill, default(s.align, ALIGN_RIGHT), s.width)
    end
    return p
end