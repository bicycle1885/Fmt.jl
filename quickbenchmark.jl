using Fmt
using BenchmarkTools

function benchmark(printer, out, x, y)
    @assert length(x) == length(y)
    for i in 1:length(x)
        printer(out, x[i], y[i])
    end
end

naive_print(out, x, y) =
    print(out, '(', x, ", ", y, ")\n")

fmt_print(out, x, y) =
    print(out, f"({$x}, {$y})\n")

using Random
Random.seed!(1234)
x = rand(-999:999, 1_000_000)
y = rand(-999:999, 1_000_000)

println("naive_print:")
@btime benchmark($naive_print, $devnull, $x, $y)
println("fmt_print:")
@btime benchmark($fmt_print, $devnull, $x, $y)
