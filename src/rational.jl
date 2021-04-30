function formatinfo(f::Field, x::Rational)
    n = numerator(x)
    d = denominator(x)
    if f.type == 'f'
        width = 1 + ndigits_decimal(n) + 1 + (f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision)
    else
        width = 1 + ndigits_decimal(n) + 1 + ndigits_decimal(d)
    end
    return paddingsize(f, width) + width, nothing
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::Rational, ::Nothing)
    start = p
    p, _ = sign(data, p, x, f.sign)
    if f.type == 'f'
        precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
        p = fixedpoint(data, p, x, precision)
    else
        n = magnitude(numerator(x))
        p = decimal(data, p, n, ndigits_decimal(n))
        data[p] = UInt8('/')
        p += 1
        d = magnitude(denominator(x))
        p = decimal(data, p, d, ndigits_decimal(d))
    end
    if f.width != WIDTH_UNSPECIFIED
        align = f.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : f.align
        p = aligncontent(data, p, start, p - start, f.fill, align, f.width)
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