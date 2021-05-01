module Fmt

export @f_str

# types and utils
include("argument.jl")
include("spec.jl")
include("field.jl")
include("parser.jl")
include("compiler.jl")
include("interface.jl")
include("misc.jl")

# formatting functions
include("any.jl")
include("nothing.jl")
include("missing.jl")
include("char.jl")
include("string.jl")
include("int.jl")
include("bool.jl")
include("ptr.jl")
include("rational.jl")
include("float.jl")
include("bigfloat.jl")
include("irrational.jl")
include("complex.jl")

end
