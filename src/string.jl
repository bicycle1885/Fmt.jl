function formatinfo(s::Spec, x::AbstractString)
    size = ncodeunits(x) * sizeof(codeunit(x)) 
    width = length(x)
    return size + paddingsize(s, width), width
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::AbstractString, width::Int)
    align = default(s.align, ALIGN_LEFT)
    pw = paddingwidth(s, width)
    p = padleft(data, p, s.fill, align, pw)
    n = ncodeunits(x)
    if isspecified(s.precision)
        n = min(nextind(x, 1, s.precision) - 1, n)
    end
    copyto!(data, p, codeunits(x), 1, n)
    p += n
    p = padright(data, p, s.fill, align, pw)
    return p
end
