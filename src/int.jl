@inline function formatinfo(s::Spec, x::Integer)
    if s.type == 'c'
        char = Char(x)
        size = ncodeunits(char)
        isspecified(s.width) || return size, (0, 1)
        return paddingsize(s, 1) + size, (0, 1)
    end

    base = s.type == 'X' || s.type == 'x' ? 16 : s.type == 'o' ? 8 : s.type == 'B' || s.type == 'b' ? 2 : 10

    # sign and prefix width
    l = 0
    l += x < 0 || s.sign == SIGN_PLUS || s.sign == SIGN_SPACE
    l += (s.altform && base != 10) * 2

    # number of digits (including grouping separators)
    m = base == 10 ? ndigits_decimal(x) : ndigits(x; base)
    if isspecified(s.grouping)
        k = base == 10 ? 3 : 4
        if isspecified(s.width) && s.zero
            m += number_of_leading_zeros(m, k, s.width - l)
        end
        m += div(m - 1, k)
    elseif isspecified(s.width) && s.zero
        m = max(s.width - l, m)
    end

    width = l + m
    return width + paddingsize(s, width), (m, width)
end

@inline function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::Integer, (m, width)::Tuple{Int, Int})
    base = s.type == 'X' || s.type == 'x' ? 16 : s.type == 'o' ? 8 : s.type == 'B' || s.type == 'b' ? 2 : 10
    align = default(s.align, ALIGN_RIGHT)
    pw = paddingwidth(s, width)
    if !s.zero
        p = padleft(data, p, s.fill, align, pw)
    end
    p, _ = sign(data, p, x, s.sign)
    if s.altform && base ≠ 10
        data[p] = Z
        data[p+1] = UInt8(s.type)
        p += 2
    end
    if s.type == 'c'
        p = pad(data, p, Char(x), 1)
    else
        u = magnitude(x)
        if !isspecified(s.grouping)
            p = base ==  2 ? binary(data, p, u, m) :
                base ==  8 ? octal(data, p, u, m) :
                base == 10 ? decimal(data, p, u, m) :
                hexadecimal(data, p, u, m, s.type == 'X')
        else
            p = base ==  2 ? binary_grouping(data, p, u, m) :
                base ==  8 ? octal_grouping(data, p, u, m) :
                base == 10 ? decimal_grouping(data, p, u, m, s.grouping == GROUPING_COMMA ? UInt8(',') : UInt8('_')) :
                hexadecimal_grouping(data, p, u, m, s.type == 'X')
        end
    end
    if !s.zero
        p = padright(data, p, s.fill, align, pw)
    end
    return p
end

magnitude(x::Unsigned) = x
magnitude(x::Union{Int8, Int16, Int32, Int64, Int128}) = unsigned(abs(x))
magnitude(x::Bool) = UInt(x)
magnitude(x::BigInt) = abs(x)

function binary(data::Vector{UInt8}, p::Int, x::Integer, m::Int)
    n = m
    while n > 0
        r = (x & 0x1) % UInt8
        data[p+n-1] = r + Z
        x >>= 1
        n -= 1
    end
    return p + m
end

function binary_grouping(data::Vector{UInt8}, p::Int, x::Integer, m::Int)
    n = m
    while n ≥ 5
        r1 = (x & 0x1) % UInt8; x >>= 1
        r2 = (x & 0x1) % UInt8; x >>= 1
        r3 = (x & 0x1) % UInt8; x >>= 1
        r4 = (x & 0x1) % UInt8; x >>= 1
        data[p+n-1] = r1 + Z
        data[p+n-2] = r2 + Z
        data[p+n-3] = r3 + Z
        data[p+n-4] = r4 + Z
        data[p+n-5] = UInt8('_')
        n -= 5
    end
    binary(data, p, x, n)
    return p + m
end

function octal(data::Vector{UInt8}, p::Int, x::Integer, m::Int)
    n = m
    while n > 0
        r = (x & 0x7) % UInt8
        data[p+n-1] = r + Z
        x >>= 3
        n -= 1
    end
    return p + m
end

function octal_grouping(data::Vector{UInt8}, p::Int, x::Integer, m::Int)
    n = m
    while n ≥ 5
        r1 = (x & 0x7) % UInt8; x >>= 3
        r2 = (x & 0x7) % UInt8; x >>= 3
        r3 = (x & 0x7) % UInt8; x >>= 3
        r4 = (x & 0x7) % UInt8; x >>= 3
        data[p+n-1] = r1 + Z
        data[p+n-2] = r2 + Z
        data[p+n-3] = r3 + Z
        data[p+n-4] = r4 + Z
        data[p+n-5] = UInt8('_')
        n -= 5
    end
    octal(data, p, x, n)
    return p + m
end

const DECIMAL_DIGITS = [let (d, r) = divrem(x, 10); ((d + Z) << 8) % UInt16 + (r + Z) % UInt8; end for x in 0:99]

function decimal(data::Vector{UInt8}, p::Int, x::Integer, m::Int)
    n = m
    @inbounds while n ≥ 2
        x, r = divrem(x, 0x64)  # 0x64 = 100
        dd = DECIMAL_DIGITS[(r % Int) + 1]
        data[p+n-1] =  dd       % UInt8
        data[p+n-2] = (dd >> 8) % UInt8
        n -= 2
    end
    if n > 0
        data[p] = (rem(x, 0xa) % UInt8) + Z
    end
    return p + m
end

function decimal_grouping(data::Vector{UInt8}, p::Int, x::Integer, m::Int, sep::UInt8)
    n = m
    while n ≥ 4
        x, r = divrem(x, 0x64)  # 0x64 = 100
        dd = DECIMAL_DIGITS[(r % Int) + 1]
        data[p+n-1] = dd % UInt8
        data[p+n-2] = (dd >> 8) % UInt8
        x, r = divrem(x, 0xa)
        data[p+n-3] = r % UInt8 + Z
        data[p+n-4] = sep
        n -= 4
    end
    decimal(data, p, x, n)
    return p + m
end

const HEXADECIMAL_DIGITS_UPPERCASE = zeros(UInt16, 256)
const HEXADECIMAL_DIGITS_LOWERCASE = zeros(UInt16, 256)
for x in 0:255
    d, r = divrem(x, 16)
    A = UInt8('A')
    HEXADECIMAL_DIGITS_UPPERCASE[x+1] = ((d < 10 ? d + Z : d - 10 + A) << 8) % UInt16 + (r < 10 ? r + Z : r - 10 + A) % UInt8
    A = UInt8('a')
    HEXADECIMAL_DIGITS_LOWERCASE[x+1] = ((d < 10 ? d + Z : d - 10 + A) << 8) % UInt16 + (r < 10 ? r + Z : r - 10 + A) % UInt8
end

function hexadecimal(data::Vector{UInt8}, p::Int, x::Integer, m::Int, uppercase::Bool)
    n = m
    hexdigits = uppercase ? HEXADECIMAL_DIGITS_UPPERCASE : HEXADECIMAL_DIGITS_LOWERCASE
    while n ≥ 2
        x, r = divrem(x, 0x100)  # 0x100 = 256
        xx = hexdigits[(r % Int) + 1]
        data[p+n-1] =  xx       % UInt8
        data[p+n-2] = (xx >> 8) % UInt8
        n -= 2
    end
    if n > 0
        A = uppercase ? UInt8('A') : UInt8('a')
        r = rem(x, 0x10) % UInt8
        data[p] = r < 0xa ? r + Z : r - 0xa + A
    end
    return p + m
end

function hexadecimal_grouping(data::Vector{UInt8}, p::Int, x::Integer, m::Int, uppercase::Bool)
    n = m
    hexdigits = uppercase ? HEXADECIMAL_DIGITS_UPPERCASE : HEXADECIMAL_DIGITS_LOWERCASE
    while n ≥ 5
        x, r = divrem(x, 0x100)  # 0x100 = 256
        xx = hexdigits[(r % Int) + 1]
        data[p+n-1] = xx % UInt8
        data[p+n-2] = (xx >> 8) % UInt8
        x, r = divrem(x, 0x100)
        xx = hexdigits[(r % Int) + 1]
        data[p+n-3] = xx % UInt8
        data[p+n-4] = (xx >> 8) % UInt8
        data[p+n-5] = UInt8('_')
        n -= 5
    end
    hexadecimal(data, p, x, n, uppercase)
    return p + m
end
