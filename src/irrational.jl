function formatinfo(s::Spec, x::Irrational)
    if !isspecified(s.type) || s.type == 's'
        # string representation using String
        val = string(x)
        size, meta = formatinfo(Spec(s, align = default(s.align, ALIGN_RIGHT), type = 's'), val)
    else
        # numeric representation using BigFloat
        precision = default(s.precision, 6)
        val = BigFloat(x; precision = precision10to2(precision))
        size, meta = formatinfo(s, val)
    end
    return size, (val, meta)
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, ::Irrational, meta)
    if !isspecified(s.type) || s.type == 's'
        s = Spec(s, align = default(s.align, ALIGN_RIGHT), type = 's')
    end
    return formatfield(data, p, s, meta[1], meta[2])
end

precision10to2(prec) = ceil(Int, (prec + 1) * log2(10))