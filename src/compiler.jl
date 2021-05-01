function compile(fstr::String)
    format = parse(fstr)
    if isempty(format) || length(format) == 1 && format[1] isa String
        # no replacement fields
        return isempty(format) ? "" : format[1]
    end

    nposargs = 0
    argparams = Dict{Argument, Symbol}()
    function arg2param(arg)
        arg isa Argument || return arg  # static argument
        haskey(argparams, arg) && return esc(argparams[arg])
        arg isa Positional && (nposargs = max(arg.position, nposargs))
        param = arg isa Keyword ? arg.name : gensym()
        argparams[arg] = param
        return esc(param)
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
            value = arg2param(f.argument)
            fill = arg2param(f.spec.fill)
            width = arg2param(f.spec.width)
            precision = arg2param(f.spec.precision)
            spec = Symbol(:spec, i)
            arg = Symbol(:arg, i)
            meta = Symbol(:meta, i)
            conv = f.conv == CONV_REPR   ? repr   :
                   f.conv == CONV_STRING ? string : identity
            info = quote
                $spec = Spec($(f.spec), fill = $fill, width = $width, precision = $precision)
                $arg = $(conv)($value)
                s, $meta = formatinfo($spec, $arg)
                size += s
            end
            data = :(p = formatfield(data, p, $spec, $arg, $meta))
        end
        push!(code_info.args, info)
        push!(code_data.args, data)
    end

    # function parameters and body
    poparams = [get(argparams, Positional(n), :_) for n in 1:nposargs]
    kwparams = [param for (arg, param) in argparams if arg isa Union{Keyword, Expr}]
    params = Expr(:tuple, Expr(:parameters, esc.(kwparams)...), esc.(poparams)...)
    body = quote
        size = 0
        $(code_info)
        data = Base.StringVector(size)
        p = 1
        $(code_data)
        p - 1 < size && resize!(data, p - 1)
        return String(data)
    end
    func = Expr(:function, params, body)

    makekw((arg, param)) = Expr(:kw, param, esc(arg isa Keyword ? arg.name : arg))
    if any(x -> x isa Expr, keys(argparams))
        @assert nposargs == 0
        return Expr(:call, func, makekw.(collect(argparams))...)
    else
        return Expr(:call, :Format, fstr, func)
    end
end

function genstrcopy(s::String)
    n = ncodeunits(s)
    code = Expr(:block)
    for i in 1:n
        push!(code.args, :(data[p+$i-1] = $(codeunit(s, i))))
    end
    return code
end
