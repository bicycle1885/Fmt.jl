function formatinfo(f::Field, x::Irrational)
    # FIXME
    return 512, nothing
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Irrational, ::Nothing)
    if f.type === TYPE_UNSPECIFIED
        s = string(x)
        return formatfield(data, p, Field(f, type = 's'), s, length(s))
    else
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        precision2 = precision10to2(precision)
        return formatfield(data, p, Field(f; precision), BigFloat(x; precision = precision2), nothing)
    end
end

precision10to2(prec) = ceil(Int, (prec + 1) * log2(10))