**This package is still under active development. The API may change anytime. Almost no error checks. Only handful basic types are supported.**

# Fmt.jl ― Python-style format strings for Julia

Fmt.jl provides a Python-style format language.
It is an alternative of Printf.jl and string utility functions in Base.
Formats are constructed by a [non-standard string literal](https://docs.julialang.org/en/v1/manual/strings/#non-standard-string-literals) prefixed by `f`, called f-strings.
In the following example, a part of an f-string surrounded by curly braces `{` `}` is replaced with a formatted floating-point number:
```
julia> using Fmt

julia> pi = float(π)
3.141592653589793

julia> f"π ≈ {$pi:.4f}"
"π ≈ 3.1416"
```

The goals of Fmt.jl are:
- **Full-fledged**: It supports almost complete features of Python's format strings.
- **Performant**: The formatter is much faster than `string` and other functions.
- **Lightweight**: It has no dependencies except the Base library.

## Overview

The `@f_str` macro (or f-string) is the only exported binding from the `Fmt` module.
This macro can interpolate variables into a string with format specification.
Interpolation happens inside replacement fields surrounded by a pair of curly braces `{}`; other parts of an f-string are treated as ordinal strings.
A replacement field usually has an argument `ARG` and a specification `SPEC` separated by a colon: `{ARG:SPEC}`, although both of them can be omitted.

Let's see some examples.
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

# grouping digits with thousand separator
x = 1234567
f"{$x:,}" == "1,234,567"
```

In addition to f-strings, Fmt.jl provides two formatting functions:
- `Fmt.format(fstr, args...; kwargs...)` creates a formatted string by applying `args` and `kwargs` to `fstr`.
- `Fmt.printf([out,] fstr, args...; kwargs...)` prints a formatted string to `out` (default: `stdout`) by applying `args` and `kwargs` to `fstr`.

When using these functions, you cannot interpolate replacement fields with `$`. All replacement values are given as function arguments:
```julia
using Fmt

# positional arguments with implicit numbering
Fmt.format(f"{} and {}", "Alice", "Bob") == "Alice and Bob"

# positional arguments with explicit numbering
Fmt.format(f"{1} and {2}", "Alice", "Bob") == "Alice and Bob"
Fmt.format(f"{2} and {1}", "Alice", "Bob") == "Bob and Alice"

# keyword arguments
Fmt.format(f"{A} and {B}", A = "Alice", B = "Bob") == "Alice and Bob"
Fmt.format(f"{B} and {A}", A = "Alice", B = "Bob") == "Bob and Alice"

# box drawing example
Fmt.printf(f"""
┌{1:─^{2}}┐             ┌{1:─^{2}}┐
│{A: ^{2}}│ ──────────> │{B: ^{2}}│
└{1:─^{2}}┘             └{1:─^{2}}┘
""", "", 15, A = "Alice", B = "Bob")
# ┌───────────────┐             ┌───────────────┐
# │     Alice     │ ──────────> │      Bob      │
# └───────────────┘             └───────────────┘
```

The syntax of f-strings is borrowed from [Python's Format String Syntax](https://docs.python.org/3/library/string.html#format-string-syntax), which is ported to C++ as [C++20 std::format](https://en.cppreference.com/w/cpp/utility/format) and Rust as [std::fmt](https://doc.rust-lang.org/std/fmt/).
See the next sections for details of the syntax and semantic supported by Fmt.jl.

## Syntax

Each replacement field is surrounded by a pair of curly braces.
To escape curly braces, double curly braces (`{{` and `}}`) are interpreted as single curly braces (`{` and `}`).
Backslash-escaped characters are treated in the same way as in usual strings.
However, dollar signs `$` are no longer a special character for interpolation; that is, no interpolation happens outside replacement fields.

The syntax of a replacement field is formally defined as follows:
```
# replacement field
field      = '{'[argument]['/'conv][':'spec]'}'
argument   = number | ['$']identifier | '$('expression')'
number     = digit+
identifier = any valid identifier
expression = any valid expression
digit      = '0' | '1' | '2' | … | '9'
conv       = 's' | 'r'

# format specification
spec       = [[fill]align][sign][altform][zero][width][grouping]['.'precision][type]
fill       = any valid character (except '{' and '}') | '{'[argument]'}'
align      = '<' | '^' | '>'
sign       = '+' | '-' | ' '
altform    = '#'
zero       = '0'
width      = digit+ | '{'[argument]'}'
grouping   = ',' | '_'
precision  = digit+ | '{'[argument]'}'
type       = 'd' | 'X' | 'x' | 'o' | 'B' | 'b' | 'c' | 'p' | 's'
             'F' | 'f' | 'E' | 'e' | 'G' | 'g' | 'A' | 'a' | '%'
```

Note that *syntactic* validity does not imply *semantic* validity.
For example, `{:,s}` is syntactically valid but semantically invalid, because the string type `s` does not support the thousands separator `,`.

A sequence of `zero` and `width` may be ambiguous because `width` may start with `0`.
To resolve the ambiguity, if `0` is followed by a digit, the leading zero is interpreted as `zero` and the following digits are interpreted as `width`.
Otherwise, the zero is interpreted as `width`.

## Semantic

The semantic of the format specification is basically the same as that of Python.

Fields that have an argument prefixed by `$` are interpolated like ordinal strings.
Currently, mixing interpolated and non-interpolated replacement fields in an f-string is not allowed.
The f-string returns a string if there is a field with interpolation.
Otherwise, it returns an `Fmt.Format` object, which can be passed to `Fmt.format` and `Fmt.printf` as the formatting template.

```julia
f"x is {$x}." isa String      #> true
f"x is {x}."  isa Fmt.Format  #> true
f"x is {}."   isa Fmt.Format  #> true
f"x is x."    isa Fmt.Format  #> true
```

### Argument

The `argument` is either positional or keyword.
Positional arguments are numbered from one, and their values are supplied from arguments passed to the `Fmt.format` function.
If numbers are omitted, they are automatically numbered incrementally from left to right, which is independent from other kinds of arguments.
Keyword arguments are named by a variable and may be interpolated.
If a keyword argument is interpolated (indicated by `$`), its value is supplied from the context where the replacement field is placed; otherwise, its value is supplied from a keyword argument with the same name passed to the `Fmt.format` function.
Currently, you cannot mix interpolated keyword arguments with other kinds of arguments in a single format.

Interpolated formats immediately return a string of the `String` type, while other formats are evaluated to an `Fmt.Format` object.
The `Fmt.format` object can be passed to the `Fmt.format` function as its first argument to create a formatted string.

```julia
# Positional arguments
Fmt.format(f"{1} {2}", "foo", "bar") == "foo bar"

# Positional arguments (implicit numbers)
Fmt.format(f"{} {}", "foo", "bar") == "foo bar"

# Keyword arguments
Fmt.format(f"{x} {y}", x = "foo", y = "bar") == "foo bar"

# Positional and keyword arguments
Fmt.format(f"{1} {x} {2}", "foo", "bar", x = "and") == "foo and bar"

# Keyword arguments with interpolation
x, y = "foo", "bar"
f"{$x} {$y}" == "foo bar"
```

### Conversion

Conversion is indicated by `/` followed by `s` or `r`.
If conversion is specified, the argument is first converted to a string representation using the `string` or `repr` function.
As the conversion characters suggest, `/s` converts the argument using the `string` function and `/r` with the `repr` function.

```julia
# Conversion
Fmt.format(f"{/s}", 'a') == "a"
Fmt.format(f"{/r}", 'a') == "'a'"
```

Python uses `!` to mark the conversion syntax.
Fmt.jl uses `/` instead to avoid syntactic ambiguity, because Julia allows `!` as a valid character for identifiers.

### Fill and alignment

The content of a formatted value can be aligned within the specified `width`.
Note that text alignment does not make sense unless `width` is specified.

The `align` character indicates an alignment type as follows:
- `<` : left alignment
- `^` : center alignment
- `>` : right alignment

The left and right margins are filled with `fill`.
It can be any character except `{` and `}`.
If omitted, a space character (i.e., U+0020) is used.

```julia
# Alignment with the default fill
Fmt.format(f"{:<7}", "foo") == "foo    "
Fmt.format(f"{:^7}", "foo") == "  foo  "
Fmt.format(f"{:>7}", "foo") == "    foo"

# Alignment with a specified fill
Fmt.format(f"{:*<7}", "foo") == "foo****"
Fmt.format(f"{:*^7}", "foo") == "**foo**"
Fmt.format(f"{:*>7}", "foo") == "****foo"
```

### Sign

`sign` controls the character indicating the sign of a number:
- `-` : a sign should be used only for negative values (default)
- `+` : a sign should be used for both non-negative and negative values
- space : a sign should be used only for negative values and a space should be used for non-negative values

Note that `sign` is only meaningful for numbers.

```julia
Fmt.format(f"{:-}",  3) == "3"
Fmt.format(f"{:-}", -3) == "-3"
Fmt.format(f"{:+}",  3) == "+3"
Fmt.format(f"{:+}", -3) == "-3"
Fmt.format(f"{: }",  3) == " 3"
Fmt.format(f"{: }", -3) == "-3"
```

### Alternate form (altform)

`altform` (`#`) indicates that the value should be formatted in a different way, depending on the type of the value and the `type` character.
For integers, it indicates that the prefix (`0b`, `0o`, `0x`, or `0X`) should be added before digits:
```julia
# Standard form of integers
Fmt.format("{:o}", 42) == "52"
Fmt.format("{:x}", 42) == "2a"

# Alternate form of integers
Fmt.format("{:#o}", 42) == "0o52"
Fmt.format("{:#x}", 42) == "0x2a"
```

For floating-point numbers, it indicates ... (TBD).

### Zero

`zero` (`0`) indicates that sign-aware zero padding should be added to fill the width specified by `width`.
That is, zeros for padding are added after the sign, not before the sign like `fill`.
The following example illustrates the difference between sign-aware padding and sign-ignorant padding:
```julia
# Sign-aware zero padding
Fmt.format(f"{:+08}",  42) == "+0000042"

# Sign-ignorant zero padding
Fmt.format(f"{:0>+8}", 42) == "00000+42"
```

### Width

`width` indicates the minimum width of a formatted string.
```julia
# Format an integer with minimum width 4
Fmt.format(f"{:4}", 123)   == " 123"
Fmt.format(f"{:4}", 1234)  == "1234"
Fmt.format(f"{:4}", 12345) == "12345"
```

The default alignment depends on the type of a value.
For example, numbers are left-aligned while strings are right-aligned unless `align` is specified.
```julia
Fmt.format(f"{:4}", 1)   == "   1"
Fmt.format(f"{:4}", "a") == "a   "
```

### Grouping

`grouping` spcifies the way of grouping digits.
For integers with the decimal format, `,` and `_` indicates thousand separator (e.g., `1,234,567`).
For integers with the binary, octal or hexadecimal format, `_` indicates four-digit separator (e.g., `0x1234_5678`).
For floating-point numbers, integral parts are grouped.
```julia
# integers
Fmt.format(f"{:,}",   123456789)  == "123,456,789"
Fmt.format(f"{:_}",   123456789)  == "123_456_789"
Fmt.format(f"{:#_x}", 0xdeadbeef) == "0xdead_beef"

# floats
Fmt.format(f"{:,f}", 2.99792458e8) == "299,792,458.000000"
Fmt.format(f"{:_f}", 2.99792458e8) == "299_792_458.000000"
```

### Precision

For floating-point numbers, `precision` specifies the precision of a formatted representation string of a number.

TBD

```julia
Fmt.format(f"{:.2f}", Float64(pi)) == "3.14"
Fmt.format(f"{:.3f}", Float64(pi)) == "3.142"
Fmt.format(f"{:.4f}", Float64(pi)) == "3.1416"
```

### Type

#### Integers

| Type | Description |
| :--: | ----------- |
| `d`  | decimal     |
| `X`  | hexadecimal (uppercase) |
| `x`  | hexadecimal (lowercase) |
| `o`  | octal |
| `B`  | binary (uppercase) |
| `b`  | binary (lowecase)  |
| `c`  | character |
| none | decimal |

#### Floating-point numbers

| Type | Description |
| :--: | ----------- |
| `F`  | fixed-point notation (uppercase) |
| `f`  | fixed-point notation (lowercase) |
| `E`  | scientific notation (uppercase) |
| `e`  | scientific notation (lowercase) |
| `A`  | hexadecimal notation (uppercase) |
| `a`  | hexadecimal notation (lowercase) |
| `G`  | general notation (uppercase) |
| `g`  | general notation (lowercase) |
| `%`  | percentage (multiplied by 100) |
| none | general notation |

There are three kinds of notations for floating-point numbers.
Fixed-point notation refers to a notation without exponent part, such as `3.14` and `0.001`.
Scientific notation refers to a notation with exponent part, such as `6.02e+23` and `1e-8`.
Hexadecimal notation is similar to scientific notation, but it is prefixed by `0x` and its fractional part is denoted in hexadecimal digits.

General notation may be in fixed-point notation or scientific notation, depending on the exponent part of a number.
It chooses fixed-point notation if the exponent part of the value is within a "reasonable" range.
Otherwise, it chooses scientific notation because denoting the value in fixed-point notation will be too long.

`F` and `f` force fixed-point notation.
The only difference between `F` and `f` is that `F` uses uppercase letters for (positive and negative) infinities and NaNs (i.e., `INF` and `NAN`, respectively) whiel `f` uses lowercase letters (i.e., `inf` and `nan`, respectively).

`E` and `e` force scientific notation.
The difference between `E` and `e` is analogous to that of `F` and `f`, but the prefix of exponent part is denoted in an uppercase letter (i.e., `E`) for `E` and in an lowercase letter (i.e., `e`) for `e`.

`A` and `a` force hexadecimal notation.
`A` uses uppercase letters and `a` uses lowercase letters.

`G` uses `F` or `E`, and `g` uses `f` or `e`, depending on the value as already mentioned above.

`%` multiplies a value by 100, denotes the value in fixed-point notation, and appends the `%` mark.

If no type specifier is given, the notation is the same as that of `g` but at least one digit is shown past the decimal point.

#### Rationals

If `type` is `F` or `f`, it formats the number in fixed-point notation.
If `type` is `%`, it formats the number in the same way as `f` but the number is multiplied by 100, followed by `%`.
If no `type` is specified, it formats the number with its (reduced) numerator and denominator separated by a slash (e.g., '3/10').

#### Other values

`p` is for pointers and `s` for strings.
These are the default for each type and do not specify any special format.


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
    for i in eachindex(x, y)
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
$ julia benchmark/compare.jl
           fmt_print:  37.928 ms (2000000 allocations: 91.55 MiB)
       sprintf_print:  77.613 ms (2000000 allocations: 106.81 MiB)
         naive_print:  202.531 ms (4975844 allocations: 198.00 MiB)
        string_print:  316.838 ms (7975844 allocations: 365.84 MiB)
    formatting_print:  716.088 ms (23878703 allocations: 959.44 MiB)
```

Benchmark environment:
- CPU: AMD Ryzen 9 3950X
- OS: GNU/Linux 5.9.12
- Julia: v1.6.0
- Formatting.jl: v0.4.2

## Related projects

- [Printf.jl](https://docs.julialang.org/en/v1/stdlib/Printf/) provides C-style formatting macros. In my opinion, it doesn't match dynamic nature of Julia because it needs type specifier.
- [Formatting.jl](https://github.com/JuliaIO/Formatting.jl) provides similar functionality with different APIs. Fmt.jl is much simpler and more performant.
