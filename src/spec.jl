# values of specification fields
@enum Alignment::UInt8 ALIGN_LEFT ALIGN_RIGHT ALIGN_CENTER
@enum Sign::UInt8 SIGN_PLUS SIGN_MINUS SIGN_SPACE SIGN_NONE
@enum Grouping::UInt8 GROUPING_COMMA GROUPING_UNDERSCORE

const FILL_DEFAULT = ' '
const SIGN_DEFAULT = SIGN_MINUS
const ALTFORM_DEFAULT = false
const ZERO_DEFAULT = false

const ALIGN_UNSPECIFIED = nothing
const WIDTH_UNSPECIFIED = nothing
const GROUPING_UNSPECIFIED = nothing
const PRECISION_UNSPECIFIED = nothing
const TYPE_UNSPECIFIED = nothing

isspecified(val) = val !== nothing
default(val, defval) = isspecified(val) ? val : defval

# format specification
struct Spec
    fill::Union{Char, Argument}
    align::Union{Alignment, Nothing}
    sign::Sign
    altform::Bool
    zero::Bool
    width::Union{Int, Nothing, Argument}
    grouping::Union{Grouping, Nothing}
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
    ALTFORM_DEFAULT,
    ZERO_DEFAULT,
    WIDTH_UNSPECIFIED,
    GROUPING_UNSPECIFIED,
    PRECISION_UNSPECIFIED,
    TYPE_UNSPECIFIED,
)
