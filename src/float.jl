using Base: Ryu, IEEEFloat

function formatinfo(s::Spec, x::IEEEFloat)
    # The cost of computing the exact size is high, so we estimate an upper bound.
    if s.type == 'f' || s.type == 'F' || s.type == '%'
        width = Ryu.neededdigits(typeof(x))
        if s.type == '%'
            width += 1
        end
    else
        # Otherwise, the scientific notation of Float64 will be an upper bound.
        # sign (1) + fraction (17) + point (1) + e/E (1) + sign (1) + exponent (3)
        width = 24
    end
    if isspecified(s.precision)
        width += s.precision
    end
    size = width
    if isspecified(s.width)
        size += paddingsize(s, width)
    end
    return size, nothing
end

@inline function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::IEEEFloat, ::Nothing)
    start = p
    p, signed = sign(data, p, x, s.sign)
    x = abs(x)

    uppercase = s.type == 'F' || s.type == 'E' || s.type == 'A' || s.type == 'G'
    plus = false
    space = false
    hash = s.altform
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
    elseif s.type == 'F' || s.type == 'f'
        precision = default(s.precision, 6)
        p = writefixed(data, p, x, precision, plus, space, hash)
    elseif s.type == 'E' || s.type == 'e'
        precision = default(s.precision, 6)
        p = writeexp(data, p, x, precision, plus, space, hash, expchar)
    elseif s.type == 'G' || s.type == 'g'
        prec = max(default(s.precision, 6), 1)
        p′ = writeexp(data, p, x, prec, plus, space, hash, expchar)
        exp = parseexp(data, p, p′, expchar)
        if -4 ≤ exp < prec
            p = writefixed(data, p, x, prec - (exp + 1), plus, space, hash; trimtrailingzeros = !hash)
        else
            p = writeexp(data, p, x, prec - 1, plus, space, hash, expchar; trimtrailingzeros = !hash)
        end
    elseif s.type == 'A' || s.type == 'a'
        if uppercase
            p = @copy data p "0X"
        else
            p = @copy data p "0x"
        end
        precision = default(s.precision, -1)
        p = hexadecimal(data, p, x, precision, uppercase)
    elseif s.type == '%'
        precision = default(s.precision, 6)
        p = writefixed(data, p, 100x, precision, plus, space, hash)
        data[p] = UInt8('%')
        p += 1
    else
        @assert !isspecified(s.type)
        hash = true
        if isspecified(s.precision)
            prec = max(s.precision, 1)
            p′ = writeexp(data, p, x, prec, plus, space, hash, expchar)
            exp = parseexp(data, p, p′, expchar)
            if -4 ≤ exp < prec
                p = writefixed(data, p, x, prec - (exp + 1), plus, space, hash; trimtrailingzeros = true)
                if data[p-1] == UInt8('.')
                    # append '0' after the decimal point (e.g., "1." -> "1.0")
                    data[p] = Z
                    p += 1
                end
            else
                p′ = writeexp(data, p, x, prec - 1, plus, space, hash, expchar; trimtrailingzeros = true)
                if data[p+2] == expchar
                    # insert '0' after the decimal point (e.g., "1.e+08" -> "1.0e+08")
                    copyto!(data, p + 3, data, p + 2, p′ - (p + 2))
                    data[p+2] = Z
                    p = p′ + 1
                else
                    p = p′
                end
            end
        else
            p = writeshortest(data, p, x, plus, space, hash, -1, expchar)
        end
    end

    if isspecified(s.grouping)
        minwidth = isspecified(s.width) ? s.width - signed : 0
        sep = s.grouping == GROUPING_COMMA ? UInt8(',') : UInt8('_')
        p = groupfloat(data, start + signed, p, s.zero, minwidth, sep)
    elseif s.zero && isspecified(s.width)
        p = insert_zeros(data, start + signed, p, s.width - (p - start))
    end

    if isspecified(s.width)
        p = aligncontent(data, p, start, p - start, s.fill, default(s.align, ALIGN_RIGHT), s.width)
    end
    return p
end

# This is to avoid excessive inlining.
@noinline writefixed(data, p, x, precision, plus, space, hash; trimtrailingzeros = false) =
    Ryu.writefixed(data, p, x, precision, plus, space, hash, UInt8('.'), trimtrailingzeros)
@noinline writeexp(data, p, x, precision, plus, space, hash, expchar; trimtrailingzeros = false) =
    Ryu.writeexp(data, p, x, precision, plus, space, hash, expchar, UInt8('.'), trimtrailingzeros)
@noinline writeshortest(data, p, x, plus, space, hash, precision, expchar) =
    Ryu.writeshortest(data, p, x, plus, space, hash, precision, expchar)

# parse the exponent part
function parseexp(data, p, p_end, expchar)
    while p < p_end
        if data[p] == expchar
            p += 1
            sign = 1
            if data[p] == UInt8('+')
                p += 1
            elseif data[p] == UInt8('-')
                sign = -1
                p += 1
            end
            exp = Int(data[p] - Z)
            p += 1
            if p < p_end
                exp = 10exp + (data[p] - Z)
                p += 1
                if p < p_end
                    exp = 10exp + (data[p] - Z)
                end
            end
            return flipsign(exp, sign)
        end
        p += 1
    end
    @assert false
end

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
