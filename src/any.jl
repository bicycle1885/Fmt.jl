# generic fallback
function formatinfo(f::Field, x::Any)
    s = string(x)
    size = ncodeunits(s)
    width = length(s)
    return size + paddingsize(f, width), (s, width)
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Any, (s, width)::Tuple{String, Int})
    return formatfield(data, p, f, s, width)
end
