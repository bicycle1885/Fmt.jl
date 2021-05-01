function formatinfo(s::Spec, x::BigFloat)
    str = Base.MPFR.string_mpfr(abs(s.type == '%' ? 100x : x), makefmt(s))
    n = ncodeunits(str)
    m = 0  # the number of integral digits
    while m + 1 ≤ n && codeunit(str, m + 1) != UInt8('.')
        m += 1
    end
    width = n
    if s.sign == SIGN_PLUS || s.sign == SIGN_SPACE || s.sign != SIGN_NONE && signbit(x)
        width += 1
    end
    if isspecified(s.grouping)
        width += div(m - 1, 3)  # separators
    end
    if !isspecified(s.type) && isinteger(x)
        width += 2
    end
    return width + paddingsize(s, width), str
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::BigFloat, str::String)
    start = p
    p, signed = sign(data, p, x, s.sign)
    n = ncodeunits(str)
    copyto!(data, p, codeunits(str), 1, n)
    p += n
    if !isspecified(s.type) && isinteger(x)
        p = @copy data p ".0"
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

function makefmt(s::Spec)
    if s.type == 'G' || s.type == 'g' || !isspecified(s.type)
        type = default(s.type, 'g')
        return isspecified(s.precision) ? "%.$(s.precision)R$(type)" : "%R$(type)"
    elseif s.type == '%'
        precision = default(s.precision, 6)
        return "%.$(precision)Rf"
    else
        precision = default(s.precision, 6)
        return "%.$(precision)R$(s.type)"
    end
end

function mpfr_snprintf(buf, fmt::String, arg::BigFloat)
    size = length(buf)
    return @ccall "libmpfr".mpfr_snprintf(buf::Ref{UInt8}, size::Csize_t, fmt::Cstring; arg::Ref{BigFloat})::Cint
end