struct FormatError <: Exception
    msg::String
end

function Base.showerror(out::IO, e::FormatError)
    print(out, "FormatError: ", e.msg)
end

function parse(fmt::String)
    list = Union{String, Field}[]
    auto = 0  # automatic numbering
    str = IOBuffer()
    last = lastindex(fmt)
    i = firstindex(fmt)
    while i ≤ last
        c = fmt[i]
        if c == '{'
            while i + 1 ≤ last && fmt[i] == '{' && fmt[i+1] == '{'
                write(str, '{')
                i += 2
            end
            if i ≤ last && fmt[i] == '{'
                i == last && throw(FormatError("single '{' is not allowed; use '{{' instead"))
                str.size > 0 && push!(list, String(take!(str)))
                field, i, auto = parse_field(fmt, i + 1, auto)
                push!(list, field)
            end
        elseif c == '}'
            while i + 1 ≤ last && fmt[i] == '}' && fmt[i+1] == '}'
                write(str, '}')
                i += 2
            end
            if i ≤ last && fmt[i] == '}' && !(i + 1 ≤ last && fmt[i+1] == '}')
                throw(FormatError("single '}' is not allowed; use '}}' instead"))
            end
        else
            write(str, c)
            i = nextind(fmt, i)
        end
    end
    str.size > 0 && push!(list, String(take!(str)))

    # check fields
    interpolated = missing
    for f in list
        f isa Field || continue
        if ismissing(interpolated)
            interpolated = f.argument isa Expr
        elseif interpolated != (f.argument isa Expr)
            throw(FormatError("mixing interpolated and non-interpolated fields is not allowed"))
        end
    end

    if isempty(list)
        push!(list, "")
    end
    return list
end

function parse_field(fmt::String, i::Int, auto::Int)
    incomplete_field() = throw(FormatError("incomplete field"))
    last = lastindex(fmt)
    arg, i, auto = parse_argument(fmt, i, auto)
    i ≤ last || incomplete_field()
    conv = CONV_UNSPECIFIED
    if fmt[i] == '/'
        i + 1 ≤ last || incomplete_field()
        conv, i = parse_conv(fmt, i + 1)
        i ≤ last || incomplete_field()
    end
    spec = SPEC_DEFAULT
    if fmt[i] == ':'
        i + 1 ≤ last || incomplete_field()
        spec, i, auto = parse_spec(fmt, i + 1, auto)
        i ≤ last || incomplete_field()
    end
    fmt[i] == '}' || throw(FormatError("invalid character $(repr(fmt[i]))"))
    # check consistency of arguments
    if arg isa Expr
        spec.fill      isa Union{Char,         Expr} &&
        spec.width     isa Union{Int, Nothing, Expr} &&
        spec.precision isa Union{Int, Nothing, Expr} ||
        throw(FormatError("inconsistent interpolation of arguments"))
    else
        spec.fill      isa Union{Char,         Positional, Keyword} &&
        spec.width     isa Union{Int, Nothing, Positional, Keyword} &&
        spec.precision isa Union{Int, Nothing, Positional, Keyword} ||
        throw(FormatError("inconsistent interpolation of arguments"))
    end
    return Field(arg, conv, spec), i + 1, auto
end

function parse_argument(s::String, i::Int, auto::Int)
    c = s[i]  # the first character after '{'
    if c == '$'
        i < lastindex(s) && (Base.is_id_start_char(s[i+1]) || s[i+1] == '(') ||
            throw(FormatError("identifier or '(' is expected after '\$'"))
        ast, i = Meta.parse(s, i + 1, greedy = false)
        arg = ast isa Expr ? ast : Expr(:block, ast)
    elseif isdigit(c)
        num, i = parse_digits(s, i)
        num == 0 && throw(FormatError("argument 0 is not allowed; use 1 or above"))
        arg = Positional(num)
    elseif Base.is_id_start_char(c)
        name, i = Meta.parse(s, i, greedy = false)
        arg = Keyword(name)
    else
        auto += 1
        arg = Positional(auto)
    end
    return arg, i, auto
end

function parse_conv(fmt::String, i::Int)
    c = fmt[i]
    if c == 'r'
        return CONV_REPR, i + 1
    elseif c == 's'
        return CONV_STRING, i + 1
    else
        throw(FormatError("invalid conversion character $(repr(c))"))
    end
end

function parse_spec(fmt::String, i::Int, auto::Int)
    # default
    fill = FILL_DEFAULT
    align = ALIGN_UNSPECIFIED
    sign = SIGN_DEFAULT
    altform = ALTFORM_DEFAULT
    zero = ZERO_DEFAULT
    width = WIDTH_UNSPECIFIED
    grouping = GROUPING_UNSPECIFIED
    precision = PRECISION_UNSPECIFIED
    type = TYPE_UNSPECIFIED

    incomplete_argument() = throw(FormatError("incomplete argument"))
    char2align(c) = c == '<' ? ALIGN_LEFT :
                    c == '^' ? ALIGN_CENTER :
                    c == '>' ? ALIGN_RIGHT : @assert false

    # align
    last = lastindex(fmt)
    if fmt[i] == '{'
        # dynamic fill or dynamic width?
        _arg, _i, _auto = parse_argument(fmt, i + 1, auto)
        _i ≤ last && fmt[_i] == '}' || incomplete_argument()
        if _i + 1 ≤ last && fmt[_i+1] ∈ "<^>"
            # it was a dynamic fill
            fill = _arg
            align = char2align(fmt[_i+1])
            auto = _auto
            i = _i + 2
            i ≤ last || @goto END
        end
    elseif fmt[i] != '}' && nextind(fmt, i) ≤ last && fmt[nextind(fmt, i)] ∈ "<^>"
        # fill + align
        fill = fmt[i]
        i = nextind(fmt, i)
        align = char2align(fmt[i])
        i += 1
        i ≤ last || @goto END
    elseif fmt[i] ∈ "<^>"
        # align only
        align = char2align(fmt[i])
        i += 1
        i ≤ last || @goto END
    end

    # sign
    if fmt[i] ∈ "-+ "
        sign = fmt[i] == '-' ? SIGN_MINUS : fmt[i] == '+' ? SIGN_PLUS : SIGN_SPACE
        i += 1
        i ≤ last || @goto END
    end

    # alternative form
    if fmt[i] == '#'
        altform = true
        i += 1
        i ≤ last || @goto END
    end

    # width
    if fmt[i] == '{'
        width, i, auto = parse_argument(fmt, i + 1, auto)
        i ≤ last && fmt[i] == '}' || incomplete_argument()
        i += 1
        i ≤ last || @goto END
    elseif isdigit(fmt[i])
        if fmt[i] == '0' && i + 1 ≤ last && isdigit(fmt[i+1])
            # preceded by zero
            zero = true
            i += 1
        end
        width, i = parse_digits(fmt, i)
        i ≤ last || @goto END
    end

    # grouping
    if fmt[i] == ','
        grouping = GROUPING_COMMA
        i += 1
        i ≤ last || @goto END
    elseif fmt[i] == '_'
        grouping = GROUPING_UNDERSCORE
        i += 1
        i ≤ last || @goto END
    end

    # precision
    if fmt[i] == '.'
        i += 1
        i ≤ last || @goto END
        if fmt[i] == '{'
            precision, i, auto = parse_argument(fmt, i + 1, auto)
            i ≤ last && fmt[i] == '}' || incomplete_argument()
            i += 1
            i ≤ last || @goto END
        elseif isdigit(fmt[i])
            precision, i = parse_digits(fmt, i)
            i ≤ last || @goto END
        else
            throw(FormatError("unexpected $(repr(fmt[i])) after '.'"))
        end
    end

    # type
    if fmt[i] ∈ "dXxoBbcpsFfEeGgAa%"
        type = fmt[i]
        i += 1
        i ≤ last || @goto END
    end

    @label END
    return Spec(fill, align, sign, altform, zero, width, grouping, precision, type), i, auto
end

function parse_digits(s::String, i::Int)
    n = 0
    last = lastindex(s)
    while i ≤ last && isdigit(s[i])
        n′ = 10n + Int(s[i] - '0')
        n′ ≥ n || throw(FormatError("number overflows"))
        n = n′
        i += 1
    end
    return n, i
end
