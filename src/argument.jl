abstract type Argument end

struct Positional <: Argument
    position::Int
end

struct Keyword <: Argument
    name::Symbol
end
