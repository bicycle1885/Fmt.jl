function formatinfo(s::Spec, x::BigFloat)
    # FIXME
    return 512, nothing
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::BigFloat, ::Nothing)
    start = p
    p, signed = sign(data, p, x, s.sign)
    let x = abs(s.type == '%' ? 100x : x)
        fmt = makefmt(s)
        n = mpfr_snprintf(@view(data[p:end]), fmt, x)
        @assert n ≥ 0
        p += n
        if s.type === nothing && isinteger(x)
            p = @copy data p ".0"
        end
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
    else
        precision = s.precision == PRECISION_UNSPECIFIED ? 6 : s.precision
        return "%.$(precision)R$(s.type)"
    end
end

function mpfr_snprintf(buf, fmt::String, arg::BigFloat)
    size = length(buf)
    return @ccall "libmpfr".mpfr_snprintf(buf::Ref{UInt8}, size::Csize_t, fmt::Cstring; arg::Ref{BigFloat})::Cint
end