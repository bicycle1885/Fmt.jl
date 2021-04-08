using Fmt
using Test

@testset "format" begin
    @test format(f"") == ""
    @test format(f"foobar") == "foobar"
    @test format(f"\r\n") == "\r\n"

    @test format(f"Hello, {}!", "world") == "Hello, world!"
    @test format(f"Hello, {}!", "世界") == "Hello, 世界!"

    @test format(f"x = {}", -3) == "x = -3"
    @test format(f"x = {}", 42) == "x = 42"
    @test format(f"x = {}, y = {}", 2, 3) == "x = 2, y = 3"

    @test format(f"pi = {}", 3.1) == "pi = 3.1"
    @test format(f"pi = {}", 3.14) == "pi = 3.14"
    @test format(f"pi = {}", 3.141) == "pi = 3.141"

    @test format(f"x = {1}", 2) == "x = 2"
    @test format(f"x = {1}, y = {2}", 2, 3) == "x = 2, y = 3"
    @test format(f"x = {2}, y = {1}", 2, 3) == "x = 3, y = 2"
    @test format(f"x = {1}, y = {2}, z = {1}", 2, 3) == "x = 2, y = 3, z = 2"

    @test format(f"x = {x}", x = 2) == "x = 2"
    @test format(f"x = {x}, y = {y}", x = 2, y = 3) == "x = 2, y = 3"
    @test format(f"x = {x}, y = {y}", y = 3, x = 2) == "x = 2, y = 3"
    @test format(f"x = {x}, y = {y}, z = {x}", x = 2, y = 3) == "x = 2, y = 3, z = 2"

    @test format(f"{}", 0x12) == "18"
    @test format(f"{}", 0xff) == "255"

    @test format(f"{}", typemin(Int)) == "-9223372036854775808"
    @test format(f"{}", typemax(Int)) == "9223372036854775807"

    @test format(f"{:}", 123) == "123"
    @test format(f"{:}", "abc") == "abc"

    @test format(f"{:0}", 123) == "123"
    @test format(f"{:1}", 123) == "123"
    @test format(f"{:2}", 123) == "123"
    @test format(f"{:3}", 123) == "123"
    @test format(f"{:4}", 123) == " 123"
    @test format(f"{:5}", 123) == "  123"

    @test format(f"{:<5}", 123) == "123  "
    @test format(f"{:>5}", 123) == "  123"
    @test format(f"{:_<5}", 123) == "123__"
    @test format(f"{:_>5}", 123) == "__123"
    @test format(f"{:<<5}", 123) == "123<<"
    @test format(f"{:>>5}", 123) == ">>123"

    @test format(f"{:0}", "abc") == "abc"
    @test format(f"{:1}", "abc") == "abc"
    @test format(f"{:2}", "abc") == "abc"
    @test format(f"{:3}", "abc") == "abc"
    @test format(f"{:4}", "abc") == "abc "
    @test format(f"{:5}", "abc") == "abc  "

    @test format(f"{:<5}", "abc") == "abc  "
    @test format(f"{:>5}", "abc") == "  abc"
    @test format(f"{:_<5}", "abc") == "abc__"
    @test format(f"{:_>5}", "abc") == "__abc"
    @test format(f"{:<<5}", "abc") == "abc<<"
    @test format(f"{:>>5}", "abc") == ">>abc"

    @test format(f"{:0}", "αβ") == "αβ"
    @test format(f"{:1}", "αβ") == "αβ"
    @test format(f"{:2}", "αβ") == "αβ"
    @test format(f"{:3}", "αβ") == "αβ "
    @test format(f"{:4}", "αβ") == "αβ  "

    @test format(f"{:┉<0}", 123) == "123"
    @test format(f"{:┉<1}", 123) == "123"
    @test format(f"{:┉<2}", 123) == "123"
    @test format(f"{:┉<3}", 123) == "123"
    @test format(f"{:┉<4}", 123) == "123┉"
    @test format(f"{:┉<5}", 123) == "123┉┉"

    @test format(f"{:┉<0}", "abc") == "abc"
    @test format(f"{:┉<1}", "abc") == "abc"
    @test format(f"{:┉<2}", "abc") == "abc"
    @test format(f"{:┉<3}", "abc") == "abc"
    @test format(f"{:┉<4}", "abc") == "abc┉"
    @test format(f"{:┉<5}", "abc") == "abc┉┉"

    @test format(f"{:-}",  0) ==  "0"
    @test format(f"{:+}",  0) == "+0"
    @test format(f"{: }",  0) == " 0"
    @test format(f"{:-}",  3) ==  "3"
    @test format(f"{:-}", -3) == "-3"
    @test format(f"{:+}",  3) == "+3"
    @test format(f"{:+}", -3) == "-3"
    @test format(f"{: }",  3) == " 3"
    @test format(f"{: }", -3) == "-3"

    @test format(f"{:b}", 42) == "101010"
    @test format(f"{:o}", 42) == "52"
    @test format(f"{:d}", 42) == "42"
    @test format(f"{:X}", 42) == "2A"
    @test format(f"{:x}", 42) == "2a"
    @test format(f"{:c}", 42) == "*"
    @test format(f"{:b}", 99999) == "11000011010011111"
    @test format(f"{:o}", 99999) == "303237"
    @test format(f"{:d}", 99999) == "99999"
    @test format(f"{:X}", 99999) == "1869F"
    @test format(f"{:x}", 99999) == "1869f"

    # 'α': Unicode U+03B1 (category Ll: Letter, lowercase)
    @test format(f"{:c}",  0x03b1) == "α"
    @test format(f"{:0c}", 0x03b1) == "α"
    @test format(f"{:1c}", 0x03b1) == "α"
    @test format(f"{:2c}", 0x03b1) == " α"
    @test format(f"{:3c}", 0x03b1) == "  α"

    @test format(f"{:#b}", 42) == "0b101010"
    @test format(f"{:#o}", 42) == "0o52"
    @test format(f"{:#d}", 42) == "42"
    @test format(f"{:#X}", 42) == "0X2A"
    @test format(f"{:#x}", 42) == "0x2a"

    @test format(f"{:d}",   42) == "42"
    @test format(f"{:5d}",  42) == "   42"
    @test format(f"{:-5d}", 42) == "   42"
    @test format(f"{:+5d}", 42) == "  +42"
    @test format(f"{: 5d}", 42) == "   42"
    @test format(f"{:<5d}", 42) == "42   "
    @test format(f"{:>5d}", 42) == "   42"

    @test format(f"{:s}",   "abc") == "abc"
    @test format(f"{:5s}",  "abc") == "abc  "
    @test format(f"{:<5s}", "abc") == "abc  "
    @test format(f"{:>5s}", "abc") == "  abc"

    @test format(f"{:02}",  42) == "42"
    @test format(f"{:02}", -42) == "-42"
    @test format(f"{:03}",  42) == "042"
    @test format(f"{:03}", -42) == "-42"
    @test format(f"{:04}",  42) == "0042"
    @test format(f"{:04}", -42) == "-042"

    @test format(f"{:+02}",  42) == "+42"
    @test format(f"{:+02}", -42) == "-42"
    @test format(f"{:+03}",  42) == "+42"
    @test format(f"{:+03}", -42) == "-42"
    @test format(f"{:+04}",  42) == "+042"
    @test format(f"{:+04}", -42) == "-042"

    pi = Float64(π)
    @test format(f"{:.2}", pi) == "3.1"
    @test format(f"{:.3}", pi) == "3.14"
    @test format(f"{:.4}", pi) == "3.142"
    @test format(f"{:.5}", pi) == "3.1416"
    @test format(f"{:.6}", pi) == "3.14159"
    @test format(f"{:.7}", pi) == "3.141593"
    @test format(f"{:.8}", pi) == "3.1415927"

    @test format(f"{:.3}", 1e-1) == "0.1"
    @test format(f"{:.3}", 1e-2) == "0.01"
    @test format(f"{:.3}", 1e-3) == "0.001"
    @test format(f"{:.3}", 1e-4) == "0.0001"
    @test format(f"{:.3}", 1e-5) == "1e-05"
    @test format(f"{:.3}", 1e-6) == "1e-06"

    @test format(f"{:-}",  0.5) == "0.5"
    @test format(f"{:+}",  0.5) == "+0.5"
    @test format(f"{: }",  0.5) == " 0.5"
    @test format(f"{:-}", -0.5) == "-0.5"
    @test format(f"{:+}", -0.5) == "-0.5"
    @test format(f"{: }", -0.5) == "-0.5"

    @test format(f"{:}", 1.0) == "1.0"
    @test format(f"{:#}", 1.0) == "1.0"

    h = 6.62607015e-34  # Planck constant
    N = 6.02214076e+23  # Avogadro constant
    @test format(f"{:f}", 1.) == "1.000000"
    @test format(f"{:f}", pi) == "3.141593"
    @test format(f"{:f}", h)  == "0.000000"
    @test format(f"{:f}", N)  == "602214075999999987023872.000000"

    @test format(f"{:-f}",  0.5) == "0.500000"
    @test format(f"{:+f}",  0.5) == "+0.500000"
    @test format(f"{: f}",  0.5) == " 0.500000"
    @test format(f"{:-f}", -0.5) == "-0.500000"
    @test format(f"{:+f}", -0.5) == "-0.500000"
    @test format(f"{: f}", -0.5) == "-0.500000"

    @test format(f"{:f}",  Inf) == "inf"
    @test format(f"{:f}", -Inf) == "-inf"
    @test format(f"{:f}",  NaN) == "nan"

    @test format(f"{:-f}",  Inf) == "inf"
    @test format(f"{:+f}",  Inf) == "+inf"
    @test format(f"{: f}",  Inf) == " inf"
    @test format(f"{:-f}", -Inf) == "-inf"
    @test format(f"{:+f}", -Inf) == "-inf"
    @test format(f"{: f}", -Inf) == "-inf"

    @test format(f"{:F}",  Inf) == "INF"
    @test format(f"{:F}", -Inf) == "-INF"
    @test format(f"{:F}",  NaN) == "NAN"

    @test format(f"{:.2f}", 1.) == "1.00"
    @test format(f"{:.2f}", pi) == "3.14"
    @test format(f"{:.2f}", h)  == "0.00"
    @test format(f"{:.2f}", N)  == "602214075999999987023872.00"

    @test format(f"{:.2F}", 1.) == "1.00"
    @test format(f"{:.2F}", pi) == "3.14"
    @test format(f"{:.2F}", h)  == "0.00"
    @test format(f"{:.2F}", N)  == "602214075999999987023872.00"

    @test format(f"{:.12f}", 1.) == "1.000000000000"
    @test format(f"{:.12f}", pi) == "3.141592653590"
    @test format(f"{:.12f}", h)  == "0.000000000000"
    @test format(f"{:.12f}", N)  == "602214075999999987023872.000000000000"

    @test format(f"{:.0f}", 1.0) == "1"
    @test format(f"{:#.0f}", 1.0) == "1."

    @test format(f"{:e}", 1.) == "1.000000e+00"
    @test format(f"{:e}", pi) == "3.141593e+00"
    @test format(f"{:e}", h)  == "6.626070e-34"
    @test format(f"{:e}", N)  == "6.022141e+23"

    @test format(f"{:-e}",  0.5) == "5.000000e-01"
    @test format(f"{:+e}",  0.5) == "+5.000000e-01"
    @test format(f"{: e}",  0.5) == " 5.000000e-01"
    @test format(f"{:-e}", -0.5) == "-5.000000e-01"
    @test format(f"{:+e}", -0.5) == "-5.000000e-01"
    @test format(f"{: e}", -0.5) == "-5.000000e-01"

    @test format(f"{:e}",  Inf) == "inf"
    @test format(f"{:e}", -Inf) == "-inf"
    @test format(f"{:e}",  NaN) == "nan"

    @test format(f"{:.2e}", 1.) == "1.00e+00"
    @test format(f"{:.2e}", pi) == "3.14e+00"
    @test format(f"{:.2e}", h)  == "6.63e-34"
    @test format(f"{:.2e}", N)  == "6.02e+23"

    @test format(f"{:.12e}", 1.) == "1.000000000000e+00"
    @test format(f"{:.12e}", pi) == "3.141592653590e+00"
    @test format(f"{:.12e}", h)  == "6.626070150000e-34"
    @test format(f"{:.12e}", N)  == "6.022140760000e+23"

    @test format(f"{:.2E}", 1.) == "1.00E+00"
    @test format(f"{:.2E}", pi) == "3.14E+00"
    @test format(f"{:.2E}", h)  == "6.63E-34"
    @test format(f"{:.2E}", N)  == "6.02E+23"

    @test format(f"{:.0e}", 1.0) == "1e+00"
    @test format(f"{:#.0e}", 1.0) == "1.e+00"
end

@testset "format (writer)" begin
    buf = IOBuffer()
    n = format(buf, f"(x = {}, y = {})\n", 123, -999)
    s = "(x = 123, y = -999)\n"
    @test n == sizeof(s)
    @test String(take!(buf)) == s
end

@testset "format (string)" begin
    x = 42
    y = "hi!"
    @test f"" == ""
    @test f"foobar" == "foobar"
    @test f"{$x}" == "42"
    @test f"{$y}" == "hi!"
    @test f"{$y} {$x}" == "hi! 42"

    x = 42
    @test f"{$x:+4d}" == " +42"
    @test f"{$x}: bin = {$x:b}, oct = {$x:o}, dec = {$x:d}, hex = {$x:x}" ==
        "42: bin = 101010, oct = 52, dec = 42, hex = 2a"
end