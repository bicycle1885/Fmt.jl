function compile(fstr::String)
    format = parse(fstr)

    if isempty(format) || length(format) == 1 && format[1] isa String
        # no replacement fields
        str = isempty(format) ? "" : format[1]
        return Expr(:function, Expr(:tuple), Expr(:block, str)), Symbol[]
    end

    n_positionals = 0
    keywords = Keyword[]
    getname(pos::Int) = Symbol(:_, pos)
    getname(arg::Keyword) = arg.name
    function check_argument(arg)
        if arg isa Positional
            n_positionals = max(arg.position, n_positionals)
            return getname(arg.position)
        elseif arg isa Keyword
            arg ∈ keywords || push!(keywords, arg)
            return getname(arg)
        else
            # some static value
            return arg
        end
    end

    code_info = Expr(:block)
    code_data = Expr(:block)
    for (i, f) in enumerate(format)
        if f isa String
            n = ncodeunits(f)
            info = :(size += $n)
            data = if n < 8
                quote
                    @inbounds $(genstrcopy(f))
                    p += $n
                end
            else
                quote
                    copyto!(data, p, $(codeunits(f)), 1, $n)
                    p += $n
                end
            end
        else
            value = check_argument(f.argument)
            fill = check_argument(f.fill)
            width = check_argument(f.width)
            precision = check_argument(f.precision)
            fld = Symbol(:fld, i)
            arg = Symbol(:arg, i)
            meta = Symbol(:meta, i)
            conv = f.conv == CONV_REPR ? repr : f.conv == CONV_STRING ? string : identity
            info = quote
                $fld = Field($f, fill = $(esc(fill)), width = $(esc(width)), precision = $(esc(precision)))
                $arg = $(conv)($(esc(value)))
                s, $meta = formatinfo($fld, $arg)
                size += s
            end
            data = :(p = formatfield(data, p, $fld, $arg, $meta))
        end
        push!(code_info.args, info)
        push!(code_data.args, data)
    end

    args = Expr(:tuple, Expr(:parameters, esc.(getname.(keywords))...), esc.(getname.(1:n_positionals))...)
    body = quote
        size = 0
        $(code_info)
        data = Base.StringVector(size)
        p = 1
        $(code_data)
        p - 1 < size && resize!(data, p - 1)
        return String(data)
    end
    return Expr(:function, args, body), any(isinterpolated, keywords) ? getname.(keywords) : nothing
end

function genstrcopy(s::String)
    n = ncodeunits(s)
    code = Expr(:block)
    for i in 1:n
        push!(code.args, :(data[p+$i-1] = $(codeunit(s, i))))
    end
    return code
end
