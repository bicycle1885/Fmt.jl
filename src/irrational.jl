function formatinfo(s::Spec, x::Irrational)
    # FIXME
    return 512, nothing
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::Irrational, ::Nothing)
    if s.type === TYPE_UNSPECIFIED
        str = string(x)
        return formatfield(data, p, Spec(s, type = 's'), str, length(str))
    else
        precision = s.precision == PRECISION_UNSPECIFIED ? 6 : s.precision
        precision2 = precision10to2(precision)
        return formatfield(data, p, Spec(s; precision), BigFloat(x; precision = precision2), nothing)
    end
end

precision10to2(prec) = ceil(Int, (prec + 1) * log2(10))