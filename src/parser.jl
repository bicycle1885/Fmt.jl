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

    if isempty(list)
        push!(list, "")
    end
    return list
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
    spec = Union{String, Argument, Expr}[]
    if fmt[i] == ':'
        i + 1 ≤ last || incomplete_field()
        spec, i, auto = parse_spec(fmt, i + 1, auto)
        i ≤ last || incomplete_field()
    end
    fmt[i] == '}' || throw(FormatError("invalid character $(repr(fmt[i]))"))
    return Field(arg, conv, spec), i + 1, auto
end

function parse_spec(fmt::String, i::Int, auto::Int)
    last = lastindex(fmt)
    str = IOBuffer()
    spec = Union{String, Argument, Expr}[]
    while i ≤ last
        c = fmt[i]
        if c == '{'
            i == last && throw(FormatError("incomplete field"))
            str.size > 0 && push!(spec, String(take!(str)))
            arg, i, auto = parse_argument(fmt, i + 1, auto)
            push!(spec, arg)
            i ≤ last && fmt[i] == '}' || throw(FormatError("incomplete field"))
            i += 1
        elseif c == '}'
            break
        else
            write(str, c)
            i = nextind(fmt, i)
        end
    end
    str.size > 0 && push!(spec, String(take!(str)))
    return spec, i, auto
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

Base.@assume_effects :foldable function parsespec(::Type{<:Any}, spec::String)
    # default values
    fill = FILL_DEFAULT
    align = ALIGN_UNSPECIFIED
    sign = SIGN_DEFAULT
    altform = ALTFORM_DEFAULT
    zero = ZERO_DEFAULT
    width = WIDTH_UNSPECIFIED
    grouping = GROUPING_UNSPECIFIED
    precision = PRECISION_UNSPECIFIED
    type = TYPE_UNSPECIFIED

    char2align(c) = c == '<' ? ALIGN_LEFT :
                    c == '^' ? ALIGN_CENTER :
                    c == '>' ? ALIGN_RIGHT : @assert false

    last = lastindex(spec)
    i = firstindex(spec)
    i ≤ last || @goto END

    # align
    if nextind(spec, i) ≤ last && spec[nextind(spec, i)] ∈ "<^>"
        # fill + align
        fill = spec[i]
        i = nextind(spec, i)
        align = char2align(spec[i])
        i += 1
        i ≤ last || @goto END
    elseif spec[i] ∈ "<^>"
        # align only
        align = char2align(spec[i])
        i += 1
        i ≤ last || @goto END
    end

    # sign
    if spec[i] ∈ "-+ "
        sign = spec[i] == '-' ? SIGN_MINUS : spec[i] == '+' ? SIGN_PLUS : SIGN_SPACE
        i += 1
        i ≤ last || @goto END
    end

    # alternative form
    if spec[i] == '#'
        altform = true
        i += 1
        i ≤ last || @goto END
    end

    # width
    if isdigit(spec[i])
        if spec[i] == '0' && i + 1 ≤ last && isdigit(spec[i+1])
            # preceded by zero
            zero = true
            i += 1
        end
        width, i = parse_digits(spec, i)
        i ≤ last || @goto END
    end

    # grouping
    if spec[i] == ','
        grouping = GROUPING_COMMA
        i += 1
        i ≤ last || @goto END
    elseif spec[i] == '_'
        grouping = GROUPING_UNDERSCORE
        i += 1
        i ≤ last || @goto END
    end

    # precision
    if spec[i] == '.'
        i += 1
        i ≤ last || @goto END
        if isdigit(spec[i])
            precision, i = parse_digits(spec, i)
            i ≤ last || @goto END
        else
            throw(FormatError("unexpected $(repr(spec[i])) after '.'"))
        end
    end

    # type
    if spec[i] ∈ "dXxoBbcpsFfEeGgAa%"
        type = spec[i]
        i += 1
        i ≤ last || @goto END
    end

    throw(FormatError("invalid character $(repr(spec[i]))"))

    @label END
    return Spec(fill, align, sign, altform, zero, width, grouping, precision, type)
end
