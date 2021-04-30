using Base: Ryu, IEEEFloat

function formatinfo(f::Field, x::IEEEFloat)
    # The cost of computing the exact size is high, so we estimate an upper bound.
    if f.type == 'f' || f.type == 'F' || f.type == '%'
        width = Ryu.neededdigits(typeof(x))
        if f.type == '%'
            width += 1
        end
    else
        # Otherwise, the scientific notation of Float64 will be an upper bound.
        # sign (1) + fraction (17) + point (1) + e/E (1) + sign (1) + exponent (3)
        width = 24
    end
    if f.precision != PRECISION_UNSPECIFIED
        width += f.precision
    end
    size = width
    if f.width != PRECISION_UNSPECIFIED
        size += paddingsize(f, width)
    end
    return size, nothing
end

@inline function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::IEEEFloat, ::Nothing)
    start = p
    p, signed = sign(data, p, x, f.sign)
    x = abs(x)

    uppercase = f.type == 'F' || f.type == 'E' || f.type == 'A' || f.type == 'G'
    plus = false
    space = false
    hash = f.altform
    expchar = uppercase ? UInt8('E') : UInt8('e')
    if isinf(x)
        if uppercase
            p = @copy data p "INF"
        else
            p = @copy data p "inf"
        end
    elseif isnan(x)
        if uppercase
            p = @copy data p "NAN"
        else
            p = @copy data p "nan"
        end
    elseif f.type == 'F' || f.type == 'f'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = writefixed(data, p, x, precision, plus, space, hash)
    elseif f.type == 'E' || f.type == 'e'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = writeexp(data, p, x, precision, plus, space, hash, expchar)
    elseif f.type == 'A' || f.type == 'a'
        if uppercase
            p = @copy data p "0X"
        else
            p = @copy data p "0x"
        end
        precision = f.precision == PRECISION_UNSPECIFIED ? -1 : f.precision
        p = hexadecimal(data, p, x, precision, uppercase)
    elseif f.type == '%'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = writefixed(data, p, 100x, precision, plus, space, hash)
        data[p] = UInt8('%')
        p += 1
    else
        @assert f.type == 'G' || f.type == 'g' || f.type === nothing
        hash = f.type === nothing
        precision = -1
        if f.precision != PRECISION_UNSPECIFIED
            precision = max(f.precision, 1)
            x = round(x, sigdigits = precision)
        end
        p = writeshortest(data, p, x, plus, space, hash, precision, expchar)
    end

    if f.grouping != GROUPING_UNSPECIFIED
        minwidth = f.width == WIDTH_UNSPECIFIED ? 0 : f.width - signed
        sep = f.grouping == GROUPING_COMMA ? UInt8(',') : UInt8('_')
        p = groupfloat(data, start + signed, p, f.zero, minwidth, sep)
    elseif f.zero && f.width != WIDTH_UNSPECIFIED
        p = insert_zeros(data, start + signed, p, f.width - (p - start))
    end

    if f.width != WIDTH_UNSPECIFIED
        align = f.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : f.align
        p = aligncontent(data, p, start, p - start, f.fill, align, f.width)
    end
    return p
end

# This is to avoid excessive inlining.
@noinline writefixed(data, p, x, precision, plus, space, hash) =
    Ryu.writefixed(data, p, x, precision, plus, space, hash)
@noinline writeexp(data, p, x, precision, plus, space, hash, expchar) =
    Ryu.writeexp(data, p, x, precision, plus, space, hash, expchar)
@noinline writeshortest(data, p, x, plus, space, hash, precision, expchar) =
    Ryu.writeshortest(data, p, x, plus, space, hash, precision, expchar)

# NOTE: the sign of `x` is ignored
function hexadecimal(data::Vector{UInt8}, p::Int, x::IEEEFloat, precision::Int, uppercase::Bool)
    if iszero(x)
        data[p] = Z
        p += 1
        if precision > 0
            data[p] = UInt8('.')
            p += 1
            p = pad(data, p, '0', precision)
        end
        exp = 0
    else
        # make fr ∈ [1, 2) so that the digit before point is always '1'
        fr, exp = frexp(abs(x))
        fr *= 2
        exp -= 1
        data[p] = UInt8('1')
        p += 1
        if isone(fr)
            if precision > 0
                data[p] = UInt8('.')
                p += 1
                p = pad(data, p, '0', precision)
            end
        else
            # fr ∈ (1, 2)
            if precision != 0
                data[p] = UInt8('.')
                p += 1
            end
            p, carry = hexadecimal_fraction(data, p, Float64(fr), precision, uppercase)
            exp += carry
        end
    end
    data[p] = uppercase ? UInt8('P') : UInt8('p')
    p += 1
    data[p] = exp < 0 ? UInt8('-') : UInt8('+')
    p += 1
    uexp = unsigned(abs(exp))
    return decimal(data, p, uexp, ndigits_decimal(uexp))
end

# fr must be in (1, 2)
function hexadecimal_fraction(data::Vector{UInt8}, p::Int, fr::Float64, precision::Int, uppercase::Bool)
    @assert 1 < fr < 2
    m = 13  # the number of nibbles in significand (excluding implicit bit)
    u = reinterpret(UInt64, fr) & Base.significand_mask(Float64)
    if precision < 0
        # trim trailing zero nibbles
        tz = trailing_zeros(u) ÷ 4
        return hexadecimal(data, p, u >> 4tz, m - tz, uppercase), 0
    elseif precision ≥ m
        # emit all digits and padding zeros
        p = hexadecimal(data, p, u, m, uppercase)
        return pad(data, p, '0', precision - m), 0
    else
        # half-to-even rounding
        k = m - precision
        u1 = u >> 4k
        u2 = u & ((one(u) << 4k) - 0x1)
        half = oftype(u, 0x8) << 4(k - 1)
        carry = 0
        if u2 > half || u2 == half && (u1 & 0x1) > 0
            u1 += 1
            carry = Int(u1 ≥ (one(u) << 4precision))
        end
        return hexadecimal(data, p, u1, precision, uppercase), carry
    end
end

# group digits in integral part by inserting separators (and leading zeros)
function groupfloat(data::Vector{UInt8}, start::Int, p::Int, zero::Bool, minwidth::Int, sep::UInt8)
    # determine integral part
    @assert Z ≤ data[start] ≤ Z + 0x9
    i = start + 1
    while i < p && Z ≤ data[i] ≤ Z + 0x9
        i += 1
    end

    # insert leading zeros
    k = 3           # number of digits between separators
    m = i - start   # number of digits in integral part
    width = p - start  # current content width
    if zero
        z = number_of_leading_zeros(m, k, m + minwidth - width)
        if z > 0
            insert_zeros(data, start, p, z)
            p += z; m += z; i += z
        end
    end

    # insert separators
    n = div(m - 1, k)
    if n > 0
        s = i - k
        copyto!(data, s + n, data, s, p - s)
        data[s+n-1] = sep
        p += n
        s -= k
        n -= 1
        while n > 0
            copyto!(data, s + n, data, s, k)
            data[s+n-1] = sep
            s -= k
            n -= 1
        end
    end

    # return the next position after the last byte
    return p
end