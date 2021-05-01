struct Positional
    position::Int
end

struct Keyword
    name::Symbol
end

const Argument = Union{Positional, Keyword, Expr}
