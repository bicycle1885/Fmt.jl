# values of specification fields
const FILL_DEFAULT = ' '
@enum Alignment::UInt8 ALIGN_UNSPECIFIED ALIGN_LEFT ALIGN_RIGHT ALIGN_CENTER
# SIGN_NONE has a special use case for complex numbers
@enum Sign::UInt8 SIGN_PLUS SIGN_MINUS SIGN_SPACE SIGN_NONE
const SIGN_DEFAULT = SIGN_MINUS
const WIDTH_UNSPECIFIED = nothing
@enum Grouping::UInt8 GROUPING_UNSPECIFIED GROUPING_COMMA GROUPING_UNDERSCORE
const PRECISION_UNSPECIFIED = nothing
const TYPE_UNSPECIFIED = nothing

# format specification
struct Spec
    fill::Union{Char, Argument}
    align::Alignment
    sign::Sign
    altform::Bool
    zero::Bool
    width::Union{Int, Nothing, Argument}
    grouping::Grouping
    precision::Union{Int, Nothing, Argument}
    type::Union{Char, Nothing}
end

function Spec(
        spec::Spec;
        fill = spec.fill,
        align = spec.align,
        sign = spec.sign,
        altform = spec.altform,
        zero = spec.zero,
        width = spec.width,
        grouping = spec.grouping,
        precision = spec.precision,
        type = spec.type)
    return Spec(fill, align, sign, altform, zero, width, grouping, precision, type)
end

const SPEC_DEFAULT = Spec(
    FILL_DEFAULT,
    ALIGN_UNSPECIFIED,
    SIGN_DEFAULT,
    false,
    false,
    WIDTH_UNSPECIFIED,
    GROUPING_UNSPECIFIED,
    PRECISION_UNSPECIFIED,
    TYPE_UNSPECIFIED,
)
