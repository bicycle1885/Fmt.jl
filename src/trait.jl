abstract type FormatSize end

struct SizeExact <: FormatSize end
struct SizeUpperbound <: FormatSize end
struct SizeUnknown <: FormatSize end

FormatSize(::Type{<:Integer}) = SizeExact()