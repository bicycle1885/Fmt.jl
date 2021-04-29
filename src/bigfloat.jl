function formatinfo(f::Field, x::BigFloat)
    # FIXME
    return 512, nothing
end

function formatfield(data::Vector{UInt8}, p::Int, f::Field, x::BigFloat, ::Nothing)
    start = p
    p, signed = sign(data, p, x, f.sign)
    uppercase = f.type == 'F' || f.type == 'E' || f.type == 'A' || f.type == 'G'
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
        if f.type == 'G' || f.type == 'g' || f.type === nothing
            type = f.type === nothing ? 'g' : f.type
            if f.precision == PRECISION_UNSPECIFIED
                spec = "%R$(type)"
            else
                spec = "%.$(f.precision)R$(type)"
            end
        else
            precision = f.precision == PRECISION_UNSPECIFIED ? 6 : f.precision
            spec = "%.$(precision)R$(f.type)"
        end
        let x = f.type == '%' ? 100x : x
            n = mpfr_snprintf(@view(data[p:end]), length(data) - (p - 1) - signed, spec, x)
            @assert n ≥ 0
            p += n
            if f.type === nothing && isinteger(x)
                p = @copy data p ".0"
            end
        end
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

mpfr_snprintf(ptr, siz, str, arg) =
    @ccall "libmpfr".mpfr_snprintf(ptr::Ptr{UInt8}, siz::Csize_t, str::Ptr{UInt8}; arg::Ref{BigFloat})::Cint