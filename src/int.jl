function formatinfo(f::Field, x::Bool)
    if f.type !== nothing
        return formatinfo(f, Int(x))
    end
    width = x ? 4 : 5
    return paddingsize(f, width) + width, (0, width)
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Bool, (m, width)::Tuple{Int, Int})
    if f.type !== nothing
        return formatfield(data, p, f, Int(x), (m, width))
    end
    align = f.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : f.align
    pw = paddingwidth(f, width)
    p = padleft(data, p, f.fill, align, pw)
    if x
        p = @copy data p "true"
    else
        p = @copy data p "false"
    end
    p = padright(data, p, f.fill, align, pw)
    return p
end

@inline function formatinfo(f::Field, x::Integer)
    if f.type == 'c'
        char = Char(x)
        size = ncodeunits(char)
        f.width == WIDTH_UNSPECIFIED && return size, (0, 1)
        return paddingsize(f, 1) + size, (0, 1)
    end
    base = f.type == 'X' || f.type == 'x' ? 16 : f.type == 'o' ? 8 : f.type == 'B' || f.type == 'b' ? 2 : 10
    k = base == 10 ? 3 : 4  # number of digits between grouping separators

    # sign + prefix width
    l = 0
    if x < 0 || f.sign != SIGN_MINUS
        l += 1
    end
    if f.altform && base != 10
        l += 2
    end

    # digits width (excluding leading zeros for sign-aware padding)
    m = base == 10 ? ndigits_decimal(x) : ndigits(x; base)

    # content width (including leading zeros for sign-aware padding)
    width = l + m
    if f.width == WIDTH_UNSPECIFIED || !f.zero
        if f.grouping != GROUPING_UNSPECIFIED
            width += div(m - 1, k)
        end
    elseif f.grouping != GROUPING_UNSPECIFIED
        if f.width - l ≤ m + div(m - 1, k)
            # no leading zeros
            width += div(m - 1, k)
        else
            # some leading zeros
            width = l + (f.width - l) + (rem(f.width - l, k + 1) == 0)
            m = (width - l) - div(width - l, k + 1)
        end
    else
        m = max(f.width - l, m)
        width = l + m
    end

    # add padding size and return
    return width + paddingsize(f, width), (m, width)
end

@inline function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Integer, (m, width)::Tuple{Int, Int})
    base = f.type == 'X' || f.type == 'x' ? 16 : f.type == 'o' ? 8 : f.type == 'B' || f.type == 'b' ? 2 : 10
    align = f.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : f.align
    pw = paddingwidth(f, width)
    if !f.zero
        p = padleft(data, p, f.fill, align, pw)
    end
    p, _ = sign(data, p, x, f.sign)
    if f.altform && base ≠ 10
        data[p] = Z
        data[p+1] = UInt8(f.type)
        p += 2
    end
    if f.type == 'c'
        p = pad(data, p, Char(x), 1)
    else
        u = magnitude(x)
        if f.grouping == GROUPING_UNSPECIFIED
            p = base ==  2 ? binary(data, p, u, m) :
                base ==  8 ? octal(data, p, u, m) :
                base == 10 ? decimal(data, p, u, m) :
                hexadecimal(data, p, u, m, f.type == 'X')
        else
            p = base ==  2 ? binary_grouping(data, p, u, m) :
                base ==  8 ? octal_grouping(data, p, u, m) :
                base == 10 ? decimal_grouping(data, p, u, m, f.grouping == GROUPING_COMMA ? UInt8(',') : UInt8('_')) :
                hexadecimal_grouping(data, p, u, m, f.type == 'X')
        end
    end
    if !f.zero
        p = padright(data, p, f.fill, align, pw)
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
    k = div(m - 1, 4)
    n = m + k
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
    return p + m + k
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
    k = div(m - 1, 4)
    n = m + k
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
    return p + m + k
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
    k = div(m - 1, 3)
    n = m + k
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
    return p + m + k
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
    k = div(m - 1, 4)
    n = m + k
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
    return p + m + k
end
