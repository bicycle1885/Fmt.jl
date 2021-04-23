using Fmt
using Random
using BenchmarkTools

function printfmt(out, fmt, x)
    for i in 1:length(x)
        print(out, Fmt.format(fmt, x[i]))
    end
end

function benchmark(fmt, x)
    print(f"  {$fmt:<10}:")
    @btime printfmt($devnull, $fmt, $x)
end

N = 1_000_000
SEED = 1234
TARGETS = ["character", "string", "integer", "float"]
if !isempty(ARGS)
    TARGETS = ARGS
end

if "character" in TARGETS
    println(f"character (N = {$N:,})")
    Random.seed!(SEED)
    x = rand('a':'z', N)
    for fmt in [f"{}", f"{:<9}", f"{:^9}", f"{:>9}"]
        benchmark(fmt, x)
    end
end

if "string" in TARGETS
    println(f"string (N = {$N:,})")
    Random.seed!(SEED)
    x = [randstring(rand(1:20)) for _ in 1:N]
    for fmt in [f"{}", f"{:s}", f"{:>20}", f"{:^20}", f"{:<20}"]
        benchmark(fmt, x)
    end
end

if "integer" in TARGETS
    println(f"integer (N = {$N:,})")
    Random.seed!(SEED)
    x = rand(-1000:1000, N)
    for fmt in [f"{}", f"{:b}", f"{:o}", f"{:d}", f"{:x}"]
        benchmark(fmt, x)
    end
end

if "float" in TARGETS
    println(f"float (N = {$N:,})")
    Random.seed!(SEED)
    x = randn(N)
    for fmt in [f"{}", f"{:f}", f"{:e}", f"{:g}", f"{:a}"]
        benchmark(fmt, x)
    end
end