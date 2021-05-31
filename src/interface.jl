"""
A data type to represent a string format. Instances of this type are
generated by the [`@f_str`](@ref) macro.
"""
struct Format{F}
    str::String
    fun::F
end

Base.show(out::IO, fmt::Format) = print(out, "f\"", fmt.str, '"')

# READ ONLY
const DUMMY_BUFFER = UInt8[]

"""
    format(fmt::Fmt.Format, positionals...; keywords...)

Create a formatted string.
"""
format(fmt::Format, positionals...; keywords...) = stringify(fmt.fun(DUMMY_BUFFER, 1, positionals...; keywords...))

"""
    format!(buf::AbstractVector{UInt8}, [pos::Integer = 1,] fmt::Fmt.Format, positionals...; keywords...)

Write a formatted string to `buf` from `pos` and return the number of written bytes.

It is the caller's responsibility to allocate enough room on the buffer to write all data.
"""
format!(buf::AbstractVector{UInt8}, pos::Integer, fmt::Format, positionals...; keywords...) = fmt.fun(buf, pos, positionals...; keywords...)[2]
format!(buf::AbstractVector{UInt8}, fmt::Format, positionals...; keywords...) = fmt.fun(buf, 1, positionals...; keywords...)[2]

"""
    printf([out::IO,] fmt::Fmt.Format, positional...; keywords...)

Output a formatted string to `out` (default: `stdout`).
"""
printf(out::IO, fmt::Format, positionals...; keywords...) = print(out, format(fmt, positionals...; keywords...))
printf(fmt::Format, positionals...; keywords...) = printf(stdout, fmt, positionals...; keywords...)

"""
    @f_str fmt

Create a formatted string or a formatter object from string `fmt`.

If there is a field whose arguments are interpolated by `\$`, it creates a new
string.  Otherwise, it creates a formatting object of the [`Fmt.Format`](@ref)
type, which can be passed to the [`Fmt.format`](@ref) function or the
[`Fmt.printf`](@ref) function to create or output formatted strings.

# Examples
```jldoctest
julia> using Fmt

julia> x, y = 42, -8;

julia> f"({\$x}, {\$y})"  # all variables are interpolated
"(42, -8)"

julia> fmt = f"({x}, {y})"  # x and y are now a placeholder
f"({x}, {y})"

julia> Fmt.format(fmt; x, y)  # substitute variables
"(42, -8)"
```
"""
macro f_str(fstr) compile(unescape_string(fstr)) end
