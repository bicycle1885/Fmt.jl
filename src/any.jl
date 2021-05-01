# generic fallback
function formatinfo(s::Spec, x::Any)
    str = string(x)
    size = ncodeunits(str)
    width = length(str)
    return size + paddingsize(s, width), (str, width)
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, ::Any, (str, width))
    return formatfield(data, p, s, str, width)
end
