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
    if s.grouping == GROUPING_COMMA || s.grouping == GROUPING_UNDERSCORE
        width += div(m - 1, 3)  # separators
    end
    if s.type === nothing && isinteger(x)
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
    if s.type === nothing && isinteger(x)
        p = @copy data p ".0"
    end

    if s.grouping != GROUPING_UNSPECIFIED
        minwidth = s.width == WIDTH_UNSPECIFIED ? 0 : s.width - signed
        sep = s.grouping == GROUPING_COMMA ? UInt8(',') : UInt8('_')
        p = groupfloat(data, start + signed, p, s.zero, minwidth, sep)
    elseif s.zero && s.width != WIDTH_UNSPECIFIED
        p = insert_zeros(data, start + signed, p, s.width - (p - start))
    end

    if s.width != WIDTH_UNSPECIFIED
        align = s.align == ALIGN_UNSPECIFIED ? ALIGN_RIGHT : s.align
        p = aligncontent(data, p, start, p - start, s.fill, align, s.width)
    end
    return p
end

function makefmt(s::Spec)
    if s.type == 'G' || s.type == 'g' || s.type === nothing
        type = s.type === nothing ? 'g' : s.type
        if s.precision == PRECISION_UNSPECIFIED
            return "%R$(type)"
        else
            return "%.$(s.precision)R$(type)"
        end
    elseif s.type == '%'
        precision = s.precision == PRECISION_UNSPECIFIED ? 6 : s.precision
        return "%.$(precision)Rf"
    else
        precision = s.precision == PRECISION_UNSPECIFIED ? 6 : s.precision
        return "%.$(precision)R$(s.type)"
    end
end

function mpfr_snprintf(buf, fmt::String, arg::BigFloat)
    size = length(buf)
    return @ccall "libmpfr".mpfr_snprintf(buf::Ref{UInt8}, size::Csize_t, fmt::Cstring; arg::Ref{BigFloat})::Cint
end