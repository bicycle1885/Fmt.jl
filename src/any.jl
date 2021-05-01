# generic fallback
function formatinfo(s::Spec, x::Any)
    str = string(x)
    size, meta = formatinfo(s, str)
    return size, (str, meta)
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, ::Any, (str, meta))
    return formatfield(data, p, s, str, meta)
end
