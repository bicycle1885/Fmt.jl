# Fmt.jl ― Python-style string format meets Julia

**This package is still under active development. The API may change anytime. Almost no error checks. Only handful basic types are supported.**

Fmt.jl provides Python-style format language with interpolation. It is an
alternative of Printf.jl and other utility functions in Base.

```
julia> using Fmt

julia> pi = float(π)
3.141592653589793

julia> f"π ≈ {$pi:.4f}"  # format a float with precision
"π ≈ 3.1416"
```

## Overview

The `@f_str` macro is the only exported binding from the `Fmt` module.
This macro can interpolate variables into a string with format specification.
Interpolation happens inside replacement fields surrounded by a pair of curly braces `{}`; other parts of a format string are treated as usual strings.
A replacement field usually has an argument `ARG` and a specification `SPEC` separated by a colon: `{ARG:SPEC}`, although both of them can be omitted.

This formatting syntax is borrowed from [Python's Format String Syntax](https://docs.python.org/3/library/string.html#format-string-syntax), which is ported to C++ as [C++20 std::format](https://en.cppreference.com/w/cpp/utility/format) and Rust as [std:fmt](https://doc.rust-lang.org/std/fmt/).
See [Syntax](#Syntax) Section for details.

```julia
# load @f_str
using Fmt

# default format
x = 42
f"x is {$x}." == "x is 42."

# binary, octal, decimal, and hexadecimal format
f"{$x:b}" == "101010"
f"{$x:o}" == "52"
f"{$x:d}" == "42"
f"{$x:x}" == "2a"
f"{$x:X}" == "2A"

# format with a minimum width
f"{$x:4}" == "  42"
f"{$x:6}" == "    42"

# left, center, and right alignment
f"{$x:<6}"  == "42    "
f"{$x:^6}"  == "  42  "
f"{$x:>6}"  == "    42"
f"{$x:*<6}" == "42****"
f"{$x:*^6}" == "**42**"
f"{$x:*>6}" == "****42"

# dynamic width
n = 6
f"{$x:<{$n}}" == "42    "
f"{$x:^{$n}}" == "  42  "
f"{$x:>{$n}}" == "    42"
```

Fmt.jl also provides a formatting function. The `Fmt.format` function takes a format template as its first argument and other arguments are interpolated into the placeholders in the template.

```julia
using Fmt

# positional arguments with implicit numbering
Fmt.format(f"{}", 1) == "1"
Fmt.format(f"{}, {}", 1, 2) == "1, 2"

# positional arguments with explicit numbering
Fmt.format(f"{1}, {2}", 1, 2) == "1, 2"
Fmt.format(f"{2}, {1}", 1, 2) == "2, 1"

# keyword arguments
Fmt.format(f"{x}, {y}", x = 1, y = 2) == "1, 2"
Fmt.format(f"{y}, {x}", x = 1, y = 2) == "2, 1"

# box drawing
Fmt.format(stdout, f"""
┌{1:─^{3}}┐
│{2: ^{3}}│
└{1:─^{3}}┘
""", "", "Hello, world!", 21)
# ┌─────────────────────┐
# │    Hello, world!    │
# └─────────────────────┘
```

## Syntax

Each replacement field is surrounded by a pair of curly braces.
To escape curly braces, double curly braces (`{{` and `}}`) are interpreted as single curly braces (`{` and `}`).
Backslash-escaped characters are treated in the same way as in usual strings.
However, dollar signs `$` are no longer a special character for interpolation; that is, no interpolation happens outside replacement fields.

The syntax of a replacement field is formally defined as follows:
```
# replacement field
field      = '{'[argument][':'spec]'}'
argument   = number | ['$']identifier
number     = digit+
identifier = any valid variable name
digit      = '0' | '1' | '2' | … | '9'

# format specification
spec       = [[fill]align][sign][altform][zero][width][grouping]['.'precision][type]
fill       = any valid character | '{'[argument]'}'
align      = '<' | '^' | '>'
sign       = '+' | '-' | ' '
altform    = '#'
zero       = '0'
width      = digit+ | '{'[argument]'}'
grouping   = ',' | '_'
precision  = digit+ | '{'[argument]'}'
type       = 'd' | 'X' | 'x' | 'o' | 'B' | 'b' | 'c' | 's' |
             'F' | 'f' | 'E' | 'e' | 'G' | 'g' | '%'
```

Note that *syntactic* validity does not imply *semantic* validity.
For example, `{:,s}` is syntactically valid but semantically invalid, because the string type `s` does not support the thousands separator `,`.

## Semantic

The semantic of the format specification is basically the same as that of Python.

TBD

## Performance

Fmt.jl is carefully optimized and will be faster than naive printing.
Let's see the next benchmarking script, which prints a pair of integers to devnull.

```julia
using Fmt
using Printf
using Formatting

fmt_print(out, x, y)        = print(out, f"({$x}, {$y})\n")
sprintf_print(out, x, y)    = print(out, @sprintf("(%d, %d)\n", x, y))
naive_print(out, x, y)      = print(out, '(', x, ", ", y, ")\n")
string_print(out, x, y)     = print(out, "($x, $y)\n")
const expr = FormatExpr("({1}, {2})\n")
formatting_print(out, x, y) = print(out, format(expr, x, y))

function benchmark(printer, out, x, y)
    @assert length(x) == length(y)
    for i in 1:length(x)
        printer(out, x[i], y[i])
    end
end

using Random
Random.seed!(1234)
x = rand(-999:999, 1_000_000)
y = rand(-999:999, 1_000_000)

using BenchmarkTools
for printer in [fmt_print, sprintf_print, naive_print,
                string_print, formatting_print]
    print(f"{$printer:>20}:")
    @btime benchmark($printer, $devnull, $x, $y)
end
```

The result on my machine is:
```
$ julia quickbenchmark.jl
           fmt_print:  37.928 ms (2000000 allocations: 91.55 MiB)
       sprintf_print:  77.613 ms (2000000 allocations: 106.81 MiB)
         naive_print:  202.531 ms (4975844 allocations: 198.00 MiB)
        string_print:  316.838 ms (7975844 allocations: 365.84 MiB)
    formatting_print:  716.088 ms (23878703 allocations: 959.44 MiB)
```

Benchmark environment:
- CPU: AMD Ryzen 9 3950X
- Julia: v1.6.0 (official binary distribution for generic Linux)
- Formatting.jl: v0.4.2

## Related projects

- [Printf.jl](https://docs.julialang.org/en/v1/stdlib/Printf/) provides C-style formatting macros. In my opinion, it doesn't match dynamic nature of Julia because it needs type specifier.
- [Formatting.jl](https://github.com/JuliaIO/Formatting.jl) provides similar functionality with different APIs. Fmt.jl is much simpler and more performant.