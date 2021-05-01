struct Positional
    position::Int
end

struct Keyword
    name::Symbol
end

const Argument = Union{Positional, Keyword, Expr}

const FILL_DEFAULT = ' '
@enum Alignment::UInt8 ALIGN_UNSPECIFIED ALIGN_LEFT ALIGN_RIGHT ALIGN_CENTER
@enum Conversion::UInt8 CONV_UNSPECIFIED CONV_REPR CONV_STRING
# SIGN_NONE has a special use case for complex numbers
@enum Sign::UInt8 SIGN_PLUS SIGN_MINUS SIGN_SPACE SIGN_NONE
const SIGN_DEFAULT = SIGN_MINUS
const WIDTH_UNSPECIFIED = nothing
@enum Grouping::UInt8 GROUPING_UNSPECIFIED GROUPING_COMMA GROUPING_UNDERSCORE
const PRECISION_UNSPECIFIED = nothing
const TYPE_UNSPECIFIED = nothing

struct Field
    argument::Argument
    conv::Conversion
    fill::Union{Char, Argument}
    align::Alignment
    sign::Sign
    altform::Bool
    zero::Bool  # zero padding
    width::Union{Int, Nothing, Argument}
    grouping::Grouping
    precision::Union{Int, Nothing, Argument}
    type::Union{Char, Nothing}
end

function Field(
        argument;
        conv = CONV_UNSPECIFIED,
        fill = FILL_DEFAULT,
        align = ALIGN_UNSPECIFIED,
        sign = SIGN_DEFAULT,
        altform = false,
        zero = false,
        width = WIDTH_UNSPECIFIED,
        grouping = GROUPING_UNSPECIFIED,
        precision = PRECISION_UNSPECIFIED,
        type = TYPE_UNSPECIFIED)
    return Field(argument, conv, fill, align, sign, altform, zero, width, grouping, precision, type)
end

function Field(
        f::Field;
        conv = f.conv,
        fill = f.fill,
        align = f.align,
        sign = f.sign,
        altform = f.altform,
        zero = f.zero,
        width = f.width,
        grouping = f.grouping,
        precision = f.precision,
        type = f.type)
    return Field(f.argument, conv, fill, align, sign, altform, zero, width, grouping, precision, type)
end
