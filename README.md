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
This macro interpolates variables into a string with format specification.
The syntax of the format specification is borrowed from [Python's Format String Syntax](https://docs.python.org/3/library/string.html#format-string-syntax), which is also ported to C++ as [C++20 std::format](https://en.cppreference.com/w/cpp/utility/format).

```julia
# load @f_str
using Fmt

# default format
x = 42
f"{$x}" == "42"

# binary, octal, decimal, and hexadecimal format
f"{$x:b}" == "101010"
f"{$x:o}" == "52"
f"{$x:d}" == "42"
f"{$x:x}" == "2a"

# format with a minimum width
f"{$x:4}" == "  42"
f"{$x:6}" == "    42"

# left and right alignment
f"{$x:<6}"  == "42    "
f"{$x:>6}"  == "    42"
f"{$x:*<6}" == "42****"
f"{$x:*>6}" == "****42"

# dynamic width
n = 6
f"{$x:<{$n}}" == "42    "
f"{$x:>{$n}}" == "    42"
```

It also provides a formatting function. The `Fmt.format` function takes a format template as its first argument and other arguments are interpolated into the placeholders in the template.

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
```

## Performance

Fmt.jl is carefully optimized and will be faster than naive printing.
Let's see the next benchmarking script, which prints a pair of integers to devnull.

```julia
using Fmt

function benchmark(printer, out, x, y)
    @assert length(x) == length(y)
    for i in 1:length(x)
        printer(out, x[i], y[i])
    end
end

naive_print(out, x, y)  = print(out, '(', x, ", ", y, ")\n")
string_print(out, x, y) = print(out, "($x, $y)\n")
fmt_print(out, x, y)    = print(out, f"({$x}, {$y})\n")

using Random
Random.seed!(1234)
x = rand(-999:999, 1_000_000)
y = rand(-999:999, 1_000_000)

using BenchmarkTools
println("naive_print:")
@btime benchmark($naive_print, $devnull, $x, $y)
println("string_print:")
@btime benchmark($string_print, $devnull, $x, $y)
println("fmt_print:")
@btime benchmark($fmt_print, $devnull, $x, $y)
```

The result on my machine (AMD Ryzen 9 3950X, Generic Linux on x86, v1.6.0) is:
```
$ julia quickbenchmark.jl
naive_print:
  208.051 ms (4975844 allocations: 198.00 MiB)
string_print:
  318.142 ms (7975844 allocations: 365.84 MiB)
fmt_print:
  36.850 ms (2000000 allocations: 91.55 MiB)
```

## Related projects

- [Printf.jl](https://docs.julialang.org/en/v1/stdlib/Printf/) provides C-style formatting macros. In my opinion, it doesn't match dynamic nature of Julia because it needs type specifier.
- [Formatting.jl](https://github.com/JuliaIO/Formatting.jl) provides similar functionality with different APIs. Fmt.jl is much simpler and more performant.