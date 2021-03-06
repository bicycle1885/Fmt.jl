function formatinfo(s::Spec, x::Rational)
    n = numerator(x)
    d = denominator(x)
    width = 0
    if s.sign == SIGN_PLUS || s.sign == SIGN_SPACE || s.sign != SIGN_NONE && signbit(x)
        width += 1
    end
    if s.type == 'F' || s.type == 'f' || s.type == '%'
        # integral part (upper bound) + decimal point + fractional part
        width += ndigits_decimal(n) + 1 + default(s.precision, 6)
        if s.type == '%'
            width += 3
        end
    else
        # numerator + slash + denominator
        s′ = Spec(s, sign = SIGN_NONE, width = nothing)
        width += formatinfo(s′, numerator(x))[1] + 1 + formatinfo(s′, denominator(x))[1]
    end
    return paddingsize(s, width) + width, nothing
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::Rational, ::Nothing)
    start = p
    p, _ = sign(data, p, x, s.sign)
    if s.type == 'F' || s.type == 'f' || s.type == '%'
        precision = default(s.precision, 6)
        if s.type == '%'
            # FIXME: 100x may overflow
            p = fixedpoint(data, p, 100x, precision)
            data[p] = UInt8('%')
            p += 1
        else
            p = fixedpoint(data, p, x, precision)
        end
    else
        n = numerator(x)
        s′ = Spec(s, sign = SIGN_NONE, width = nothing)
        p = formatfield(data, p, s′, n, formatinfo(s′, n)[2])
        data[p] = UInt8('/')
        p += 1
        d = denominator(x)
        p = formatfield(data, p, s′, d, formatinfo(s′, d)[2])
    end
    if isspecified(s.width)
        p = aligncontent(data, p, start, p - start, s.fill, default(s.align, ALIGN_RIGHT), s.width)
    end
    return p
end

function fixedpoint(data::Vector{UInt8}, p::Int, x::Rational, precision::Int)
    # write integral part
    n = magnitude(numerator(x))
    d = magnitude(denominator(x))
    q, r = divrem(n, d)
    int = p
    p = decimal(data, p, q, ndigits_decimal(q))

    # write fractional part
    if precision > 0
        frac = p
        data[p] = UInt8('.')
        p += 1
        prec = precision
        while prec > 0
            q, r = divrem10(r, d)
            data[p] = UInt8(q + Z)
            p += 1
            prec -= 1
        end
    end

    q′, r = divrem10(r, d)
    if q′ ≥ 5 && (r > 0 || r == 0 && isodd(q))  # half-to-even tie breaking
        carry = true
        if precision > 0
            # fix fractional part
            carry = moveupdigits(data, frac + 1, p - 1)
        end
        if carry
            # fix integral part
            carry = moveupdigits(data, int, precision > 0 ? frac - 1 : p - 1)
            if carry
                # insert '1'
                copyto!(data, int + 1, data, int, p - int)
                data[int] = UInt8('1')
                p += 1
            end
        end
    end
    return p
end

function moveupdigits(data, first, last)
    @assert first ≤ last
    i = last
    data[i] += 0x1
    while i > first && data[i] == Z + 0xa
        data[i] = Z
        i -= 1
        data[i] += 0x1
    end
    if i == first && data[i] == Z + 0xa
        data[i] = Z
        return true
    end
    return false
end

# compute divrem(10x, y) (0 ≤ x < y) without overflows.
function divrem10(x::T, y::T) where T <: Integer
    @assert 0 ≤ x < y
    var"10x", overflow = Base.mul_with_overflow(oftype(x, 10), x)
    overflow || divrem(var"10x", y)
    q, r = zero(x), x
    for _ in 1:9
        if r + x ≥ y || r + x < r
            q += 0x1
            r += x - y
        else
            r += x
        end
    end
    return q, r
end
