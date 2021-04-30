const Z = UInt8('0')

ndigits_decimal(x::Signed) =
    ndigits_decimal(unsigned(abs(x)))

function ndigits_decimal(x::Unsigned)
    n = 0
    while true
        if x < 10
            n += 1
            break
        elseif x < 100
            n += 2
            break
        elseif x < 1000
            n += 3
            break
        else
            n += 4
            x < 10000 && break
            x = div(x, oftype(x, 10000))
        end
    end
    return n
end

ndigits_decimal(x::BigInt) = ndigits(x, base = 10)

# inlined copy of static data
macro copy(dst, p, src::String)
    block = Expr(:block)
    n = ncodeunits(src)
    for i in 1:n
        push!(block.args, :($dst[$p+$i-1] = $(codeunit(src, i))))
    end
    push!(block.args, :(p + $n))
    return esc(block)
end

# write sign mark
function sign(data, p, x, sgn)
    signed = false
    if sgn == SIGN_NONE
        # pass
    elseif signbit(x)
        data[p] = UInt8('-')
        signed = true
    elseif sgn == SIGN_PLUS
        data[p] = UInt8('+')
        signed = true
    elseif sgn == SIGN_SPACE
        data[p] = UInt8(' ')
        signed = true
    end
    return p + signed, signed
end

# calculate the number of leading zeros for padding
function number_of_leading_zeros(m, k, minwidth)
    n = div(m - 1, k)  # number of separators
    m + n < minwidth || return 0
    width = minwidth + (rem(minwidth, k + 1) == 0)
    ndigits = width - div(width - 1, k + 1)
    return ndigits - m
end

function insert_zeros(data, start, p, n)
    n > 0 || return p
    copyto!(data, start + n, data, start, p - start)
    for i in 1:n
        data[start+i-1] = Z
    end
    return p + n
end

# post-hoc alignment
function aligncontent(data, p, start, width::Int, fill::Char, align::Alignment, minwidth::Int)
    pw = max(minwidth - width, 0)  # padding width
    ps = pw * ncodeunits(fill)     # padding size
    size = p - start
    if align == ALIGN_RIGHT
        copyto!(data, start + ps, data, start, size)
        pad(data, start, fill, pw)
        p += ps
    elseif align == ALIGN_CENTER
        offset = ncodeunits(fill) * (pw ÷ 2)
        copyto!(data, start + offset, data, start, size)
        pad(data, start, fill, pw ÷ 2)
        pad(data, start + offset + size, fill, pw - pw ÷ 2)
        p += ps
    else
        p = pad(data, p, fill, pw)
    end
    return p
end

@inline function paddingwidth(f::Field, width::Int)
    @assert f.width isa Int || f.width isa Nothing
    return f.width isa Int ? max(f.width - width, 0) : 0
end

paddingsize(f::Field, width::Int) =
    f.fill === nothing ? 0 : paddingwidth(f, width) * ncodeunits(f.fill)

@inline function padleft(data::Vector{UInt8}, p::Int, fill::Char, align::Alignment, pw::Int)
    @assert align != ALIGN_UNSPECIFIED
    if align == ALIGN_RIGHT
        p = pad(data, p, fill, pw)
    elseif align == ALIGN_CENTER
        p = pad(data, p, fill, pw ÷ 2)
    end
    return p
end

@inline function padright(data::Vector{UInt8}, p::Int,fill::Char, align::Alignment, pw::Int)
    @assert align != ALIGN_UNSPECIFIED
    if align == ALIGN_LEFT
        p = pad(data, p, fill, pw)
    elseif align == ALIGN_CENTER
        p = pad(data, p, fill, pw - pw ÷ 2)
    end
    return p
end

function pad(data::Vector{UInt8}, p::Int, fill::Char, w::Int)
    for _ in 1:w
        p = char(data, p, fill)
    end
    return p
end

function char(data::Vector{UInt8}, p::Int, char::Char)
    m = ncodeunits(char)
    x = reinterpret(UInt32, char) >> 8(4 - m)
    if m == 1
        data[p]   =  x        % UInt8
    elseif m == 2
        data[p+1] =  x        % UInt8
        data[p]   = (x >> 8)  % UInt8
    elseif m == 3
        data[p+2] =  x        % UInt8
        data[p+1] = (x >>  8) % UInt8
        data[p]   = (x >> 16) % UInt8
    else
        @assert m == 4
        data[p+3] =  x        % UInt8
        data[p+2] = (x >>  8) % UInt8
        data[p+1] = (x >> 16) % UInt8
        data[p]   = (x >> 24) % UInt8
    end
    return p + m
end
