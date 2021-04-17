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