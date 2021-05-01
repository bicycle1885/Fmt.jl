function formatinfo(s::Spec, x::Irrational)
    if s.type == TYPE_UNSPECIFIED
        # string representation using String
        val = string(x)
        size, meta = formatinfo(Spec(s, type = 's'), val)
    else
        # numeric representation using BigFloat
        precision = s.precision == PRECISION_UNSPECIFIED ? 6 : s.precision
        val = BigFloat(x; precision = precision10to2(precision))
        size, meta = formatinfo(s, val)
    end
    return size, (val, meta)
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, ::Irrational, meta)
    if s.type == TYPE_UNSPECIFIED
        s = Spec(s, type = 's')
    end
    return formatfield(data, p, s, meta[1], meta[2])
end

precision10to2(prec) = ceil(Int, (prec + 1) * log2(10))