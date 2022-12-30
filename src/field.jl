@enum Conversion::UInt8 CONV_UNSPECIFIED CONV_REPR CONV_STRING

# replacement field
struct Field
    argument::Argument
    conv::Conversion
    spec::Vector{Union{String, Argument}}
end
