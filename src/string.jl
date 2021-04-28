function formatinfo(f::Field, x::AbstractString)
    size = ncodeunits(x) * sizeof(codeunit(x)) 
    width = length(x)
    return size + paddingsize(f, width), width
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::AbstractString, width::Int)
    align = f.align == ALIGN_UNSPECIFIED ? ALIGN_LEFT : f.align
    pw = paddingwidth(f, width)
    p = padleft(data, p, f.fill, align, pw)
    n = ncodeunits(x)
    if f.precision != PRECISION_UNSPECIFIED
        n = min(nextind(x, 1, f.precision) - 1, n)
    end
    copyto!(data, p, codeunits(x), 1, n)
    p += n
    p = padright(data, p, f.fill, align, pw)
    return p
end
