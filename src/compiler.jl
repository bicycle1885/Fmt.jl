function compile(fstr::String)
    nposargs = 0
    argparams = Dict{Argument, Symbol}()
    function arg2param(arg)
        arg isa Argument || return arg  # static argument
        haskey(argparams, arg) && return argparams[arg]
        arg isa Positional && (nposargs = max(arg.position, nposargs))
        param = arg isa Keyword ? arg.name : gensym()
        argparams[arg] = param
        return param
    end

    code_info = Expr(:block)
    code_data = Expr(:block)
    for (i, f) in enumerate(parse(fstr))
        if f isa String
            n = ncodeunits(f)
            info = :(size += $n)
            data = n < 8 ?
                :(@inbounds $(genstrcopy(f)); p += $n) :
                :(copyto!(buf, p, $(codeunits(f)), 1, $n); p += $n)
        else
            @assert f isa Field
            value = esc(arg2param(f.argument))
            spec = Symbol(:spec, i)
            arg = Symbol(:arg, i)
            meta = Symbol(:meta, i)
            convfun = conv2func(f.conv)
            info = quote
                #$spec = Spec($(f.spec), fill = $fill, width = $width, precision = $precision)
                $arg = $(convfun)($value)
                $spec = parsespec(typeof($arg), $(f.spec[1]))
                s, $meta = formatinfo($spec, $arg)
                size += s
            end
            data = :(p = formatfield(buf, p, $spec, $arg, $meta))
        end
        push!(code_info.args, info)
        push!(code_data.args, data)
    end

    # function parameters and body
    poparams = [get(argparams, Positional(n), :_) for n in 1:nposargs]
    kwparams = [param for (arg, param) in argparams if arg isa Union{Keyword, Expr}]
    # the parameters are like: function (buf, pos, a, b, c, ...; x, y, z, ...).
    params = Expr(:tuple, Expr(:parameters, esc.(kwparams)...), :buf, :pos, esc.(poparams)...)
    body = quote
        size = 0
        $(code_info)
        if buf === DUMMY_BUFFER
            buf = Base.StringVector(size)
        end
        p::Int = pos
        $(code_data)
        return buf, p - Int(pos)
    end
    func = Expr(:function, params, body)

    makekw((arg, param)) = Expr(:kw, param, esc(arg isa Keyword ? arg.name : arg))
    if any(x -> x isa Expr, keys(argparams))
        @assert nposargs == 0
        return Expr(:call, :stringify, Expr(:call, func, :DUMMY_BUFFER, 1, makekw.(collect(argparams))...))
    else
        return Expr(:call, :Format, fstr, func)
    end
end

function stringify((buf, n))
    n < length(buf) && resize!(buf, n)
    return String(buf)
end

function genstrcopy(s::String)
    code = Expr(:block)
    for i in 1:ncodeunits(s)
        push!(code.args, :(buf[p+$i-1] = $(codeunit(s, i))))
    end
    return code
end

conv2func(conv::Conversion) =
    conv == CONV_REPR   ? repr   :
    conv == CONV_STRING ? string : identity
