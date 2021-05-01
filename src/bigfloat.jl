function formatinfo(s::Spec, x::BigFloat)
    # FIXME
    return 512, nothing
end

function formatfield(data::Vector{UInt8}, p::Int, s::Spec, x::BigFloat, ::Nothing)
    start = p
    p, signed = sign(data, p, x, s.sign)
    uppercase = s.type == 'F' || s.type == 'E' || s.type == 'A' || s.type == 'G'
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
    else
        if s.type == 'G' || s.type == 'g' || s.type === nothing
            type = s.type === nothing ? 'g' : s.type
            if s.precision == PRECISION_UNSPECIFIED
                spec = "%R$(type)"
            else
                spec = "%.$(s.precision)R$(type)"
            end
        else
            precision = s.precision == PRECISION_UNSPECIFIED ? 6 : s.precision
            spec = "%.$(precision)R$(s.type)"
        end
        let x = s.type == '%' ? 100x : x
            n = mpfr_snprintf(@view(data[p:end]), length(data) - (p - 1) - signed, spec, x)
            @assert n ≥ 0
            p += n
            if s.type === nothing && isinteger(x)
                p = @copy data p ".0"
            end
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

mpfr_snprintf(ptr, siz, str, arg) =
    @ccall "libmpfr".mpfr_snprintf(ptr::Ptr{UInt8}, siz::Csize_t, str::Ptr{UInt8}; arg::Ref{BigFloat})::Cint