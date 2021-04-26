using Fmt
using Test

const format = Fmt.format

struct Foo end

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

    @test format(f"flag = {}", false) == "flag = false"
    @test format(f"flag = {}", true) == "flag = true"

    @test format(f"char = {}", 'a') == "char = a"
    @test format(f"char = {}", 'α') == "char = α"
    @test format(f"char = {}", 'あ') == "char = あ"

    @test format(f"x = {1}", 2) == "x = 2"
    @test format(f"x = {1}, y = {2}", 2, 3) == "x = 2, y = 3"
    @test format(f"x = {2}, y = {1}", 2, 3) == "x = 3, y = 2"
    @test format(f"x = {1}, y = {2}, z = {1}", 2, 3) == "x = 2, y = 3, z = 2"

    @test format(f"{3}", 1, 2, 3) == "3"
    @test format(f"{3} {1}", 1, 2, 3) == "3 1"
    @test format(f"{3} {2}", 1, 2, 3) == "3 2"
    @test format(f"{3} {3}", 1, 2, 3) == "3 3"
    @test format(f"{3} {3} {3}", 1, 2, 3) == "3 3 3"

    @test format(f"x = {x}", x = 2) == "x = 2"
    @test format(f"x = {x}, y = {y}", x = 2, y = 3) == "x = 2, y = 3"
    @test format(f"x = {x}, y = {y}", y = 3, x = 2) == "x = 2, y = 3"
    @test format(f"x = {x}, y = {y}, z = {x}", x = 2, y = 3) == "x = 2, y = 3, z = 2"

    @test format(f"{1}{2}{3}{4}{5}{6}{7}{8}{9}{10}{11}{12}", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12) == "123456789101112"

    @test format(f"{}",     Foo()) == "Foo()"
    @test format(f"{:9}",   Foo()) == "Foo()    "
    @test format(f"{:<9}",  Foo()) == "Foo()    "
    @test format(f"{:>9}",  Foo()) == "    Foo()"
    @test format(f"{:*>9}", Foo()) == "****Foo()"
    @test format(f"{:*^9}", Foo()) == "**Foo()**"
    @test format(f"{:*<9}", Foo()) == "Foo()****"
    @test format(f"{}", (x = 1, y = 2)) == "(x = 1, y = 2)"

    @test format(f"{:5}",  'a') == "a    "
    @test format(f"{:>5}", 'a') == "    a"
    @test format(f"{:<5}", 'a') == "a    "
    @test format(f"{:^5}", 'a') == "  a  "

    @test format(f"{}", 0x12) == "18"
    @test format(f"{}", 0xff) == "255"

    @test format(f"{}", typemin(Int)) == "-9223372036854775808"
    @test format(f"{}", typemax(Int)) == "9223372036854775807"

    @test format(f"{:}", 123) == "123"
    @test format(f"{:}", "abc") == "abc"

    @test format(f"{/s}", 'a') == "a"
    @test format(f"{/r}", 'a') == "'a'"
    @test format(f"{/s}", 123) == "123"
    @test format(f"{/r}", 123) == "123"

    @test format(f"{:}",    nothing) == "nothing"
    @test format(f"{:10}",  nothing) == "nothing   "
    @test format(f"{:<10}", nothing) == "nothing   "
    @test format(f"{:^10}", nothing) == " nothing  "
    @test format(f"{:>10}", nothing) == "   nothing"

    @test format(f"{:0}", 123) == "123"
    @test format(f"{:1}", 123) == "123"
    @test format(f"{:2}", 123) == "123"
    @test format(f"{:3}", 123) == "123"
    @test format(f"{:4}", 123) == " 123"
    @test format(f"{:5}", 123) == "  123"

    @test format(f"{:<5}", 123) == "123  "
    @test format(f"{:^5}", 123) == " 123 "
    @test format(f"{:>5}", 123) == "  123"
    @test format(f"{:_<5}", 123) == "123__"
    @test format(f"{:_^5}", 123) == "_123_"
    @test format(f"{:_>5}", 123) == "__123"
    @test format(f"{:<<5}", 123) == "123<<"
    @test format(f"{:^^5}", 123) == "^123^"
    @test format(f"{:>>5}", 123) == ">>123"

    @test format(f"{:0}", "abc") == "abc"
    @test format(f"{:1}", "abc") == "abc"
    @test format(f"{:2}", "abc") == "abc"
    @test format(f"{:3}", "abc") == "abc"
    @test format(f"{:4}", "abc") == "abc "
    @test format(f"{:5}", "abc") == "abc  "

    @test format(f"{:<5}", "abc") == "abc  "
    @test format(f"{:^5}", "abc") == " abc "
    @test format(f"{:>5}", "abc") == "  abc"
    @test format(f"{:_<5}", "abc") == "abc__"
    @test format(f"{:_^5}", "abc") == "_abc_"
    @test format(f"{:_>5}", "abc") == "__abc"
    @test format(f"{:<<5}", "abc") == "abc<<"
    @test format(f"{:^^5}", "abc") == "^abc^"
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

    @test format(f"{:b}", false) == "0"
    @test format(f"{:b}", true)  == "1"
    @test format(f"{:o}", false) == "0"
    @test format(f"{:o}", true)  == "1"
    @test format(f"{:d}", false) == "0"
    @test format(f"{:d}", true)  == "1"
    @test format(f"{:x}", false) == "0"
    @test format(f"{:x}", true)  == "1"
    @test format(f"{:X}", false) == "0"
    @test format(f"{:X}", true)  == "1"

    @test format(f"{:4b}",  true) == "   1"
    @test format(f"{:<4b}", true) == "1   "
    @test format(f"{:^4b}", true) == " 1  "
    @test format(f"{:>4b}", true) == "   1"

    @test format(f"{:#b}", false) == "0b0"
    @test format(f"{:#b}", true)  == "0b1"
    @test format(f"{:#B}", false) == "0B0"
    @test format(f"{:#B}", true)  == "0B1"
    @test format(f"{:#o}", false) == "0o0"
    @test format(f"{:#o}", true)  == "0o1"
    @test format(f"{:#x}", false) == "0x0"
    @test format(f"{:#x}", true)  == "0x1"
    @test format(f"{:#X}", false) == "0X0"
    @test format(f"{:#X}", true)  == "0X1"

    @test format(f"{:05b}", true)  == "00001"
    @test format(f"{:#05b}", true) == "0b001"

    # 'α': Unicode U+03B1 (category Ll: Letter, lowercase)
    @test format(f"{:c}",  0x03b1) == "α"
    @test format(f"{:0c}", 0x03b1) == "α"
    @test format(f"{:1c}", 0x03b1) == "α"
    @test format(f"{:2c}", 0x03b1) == " α"
    @test format(f"{:3c}", 0x03b1) == "  α"

    @test format(f"{:>3c}", 0x03b1) == "  α"
    @test format(f"{:^3c}", 0x03b1) == " α "
    @test format(f"{:<3c}", 0x03b1) == "α  "

    @test format(f"{:#B}", 42) == "0B101010"
    @test format(f"{:#b}", 42) == "0b101010"
    @test format(f"{:#o}", 42) == "0o52"
    @test format(f"{:#d}", 42) == "42"
    @test format(f"{:#X}", 42) == "0X2A"
    @test format(f"{:#x}", 42) == "0x2a"

    @test format(f"{:#06X}", 42) == "0X002A"
    @test format(f"{:#06x}", 42) == "0x002a"

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

    #@test format(f"{:<06}",  123) == "123000"
    #@test format(f"{:>06}",  123) == "000123"
    #@test format(f"{:<+06}", 123) == "+12300"
    #@test format(f"{:>+06}", 123) == "00+123"

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

    #@test format(f"{:.3}", 1e-1) == "0.1"
    #@test format(f"{:.3}", 1e-2) == "0.01"
    #@test format(f"{:.3}", 1e-3) == "0.001"
    #@test format(f"{:.3}", 1e-4) == "0.0001"
    #@test format(f"{:.3}", 1e-5) == "1e-05"
    #@test format(f"{:.3}", 1e-6) == "1e-06"

    @test format(f"{:-}",  0.5) == "0.5"
    @test format(f"{:+}",  0.5) == "+0.5"
    @test format(f"{: }",  0.5) == " 0.5"
    @test format(f"{:-}", -0.5) == "-0.5"
    @test format(f"{:+}", -0.5) == "-0.5"
    @test format(f"{: }", -0.5) == "-0.5"

    @test format(f"{:}",  1.0) == "1.0"
    @test format(f"{:#}", 1.0) == "1.0"
    @test format(f"{:g}", 1.0) == "1"
    @test format(f"{:G}", 1.0) == "1"

    @test format(f"{:%}",   1.0) == "100.000000%"
    @test format(f"{:.0%}", 1.0) == "100%"
    @test format(f"{:.1%}", 1.0) == "100.0%"
    @test format(f"{:.2%}", 1.0) == "100.00%"
    @test format(f"{:.1%}", 0.5) == "50.0%"

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

    @test format(f"{:5}",   1.2) == "  1.2"
    @test format(f"{:>5}",  1.2) == "  1.2"
    @test format(f"{:^5}",  1.2) == " 1.2 "
    @test format(f"{:<5}",  1.2) == "1.2  "
    @test format(f"{:*>5}", 1.2) == "**1.2"
    @test format(f"{:*^5}", 1.2) == "*1.2*"
    @test format(f"{:*<5}", 1.2) == "1.2**"
    @test format(f"{:ζ>5}", 1.2) == "ζζ1.2"
    @test format(f"{:ζ^5}", 1.2) == "ζ1.2ζ"
    @test format(f"{:ζ<5}", 1.2) == "1.2ζζ"

    @test format(f"{:10f}",  3.14) == "  3.140000"
    @test format(f"{:>10f}", 3.14) == "  3.140000"
    @test format(f"{:<10f}", 3.14) == "3.140000  "

    @test format(f"{:06}",  1.2) == "0001.2"
    @test format(f"{:06}", -1.2) == "-001.2"
    @test format(f"{:+06}", 1.2) == "+001.2"
    @test format(f"{:-06}", 1.2) == "0001.2"
    @test format(f"{: 06}", 1.2) == " 001.2"

    @test format(f"{:06}", -0.0) == "-000.0"

    @test format(f"({:10.3f})", 3.14) == "(     3.140)"

    @test format(f"{:.0g}", 1.0) == "1"
    @test format(f"{:.1g}", 1.0) == "1"
    @test format(f"{:.2g}", 1.0) == "1"

    @test format(f"{:a}",  0.0) == "0x0p+0"
    @test format(f"{:a}", -0.0) == "-0x0p+0"
    @test format(f"{:a}",  1.0) == "0x1p+0"
    @test format(f"{:a}", -1.0) == "-0x1p+0"
    @test format(f"{:a}", 3.14) == "0x1.91eb851eb851fp+1"
    @test format(f"{:a}", 10.0) == "0x1.4p+3"
    @test format(f"{:a}", 1234.56789) == "0x1.34a4584f4c6e7p+10"
    @test format(f"{:A}", 1234.56789) == "0X1.34A4584F4C6E7P+10"
    @test format(f"{:a}",  Inf) == "inf"
    @test format(f"{:a}", -Inf) == "-inf"
    @test format(f"{:A}",  Inf) == "INF"
    @test format(f"{:a}",  NaN) == "nan"
    @test format(f"{:A}",  NaN) == "NAN"

    @test format(f"{:.0a}", 0.0) == "0x0p+0"
    @test format(f"{:.1a}", 0.0) == "0x0.0p+0"
    @test format(f"{:.2a}", 0.0) == "0x0.00p+0"
    @test format(f"{:.3a}", 0.0) == "0x0.000p+0"
    @test format(f"{:.0a}", 1.0) == "0x1p+0"
    @test format(f"{:.1a}", 1.0) == "0x1.0p+0"
    @test format(f"{:.2a}", 1.0) == "0x1.00p+0"
    @test format(f"{:.3a}", 1.0) == "0x1.000p+0"

    x = 0x1.123456789abp+0
    @test format(f"{:.0a}", x) == "0x1p+0"
    @test format(f"{:.1a}", x) == "0x1.1p+0"
    @test format(f"{:.2a}", x) == "0x1.12p+0"
    @test format(f"{:.3a}", x) == "0x1.123p+0"
    @test format(f"{:.4a}", x) == "0x1.1234p+0"
    @test format(f"{:.5a}", x) == "0x1.12345p+0"
    @test format(f"{:.6a}", x) == "0x1.123456p+0"
    @test format(f"{:.7a}", x) == "0x1.1234568p+0"
    @test format(f"{:.8a}", x) == "0x1.12345679p+0"
    @test format(f"{:.9a}", x) == "0x1.12345678ap+0"

    @test format(f"{:.0a}", 0x1.fffp+1) == "0x1p+2"
    @test format(f"{:.1a}", 0x1.fffp+1) == "0x1.0p+2"
    @test format(f"{:.2a}", 0x1.fffp+1) == "0x1.00p+2"
    @test format(f"{:.3a}", 0x1.fffp+1) == "0x1.fffp+1"
    @test format(f"{:.4a}", 0x1.fffp+1) == "0x1.fff0p+1"
    @test format(f"{:.5a}", 0x1.fffp+1) == "0x1.fff00p+1"

    @test format(f"{:a}", 0x1.01p+0) == "0x1.01p+0"
    @test format(f"{:a}", 0x1.001p+0) == "0x1.001p+0"
    @test format(f"{:a}", 0x1.0001p+0) == "0x1.0001p+0"
    @test format(f"{:a}", 0x1.03f7305d6e95cp-2) == "0x1.03f7305d6e95cp-2"

    @test format(f"{:.1a}", 0x1.08p+0) == "0x1.0p+0"
    @test format(f"{:.1a}", 0x1.18p+0) == "0x1.2p+0"
    @test format(f"{:.1a}", 0x1.28p+0) == "0x1.2p+0"
    @test format(f"{:.1a}", 0x1.38p+0) == "0x1.4p+0"

    @test format(f"{1:{2}}", "foo", 5) == "foo  "
    @test format(f"{2:{1}}", 5, "foo") == "foo  "

    @test format(f"{x:{y}}", x = "foo", y = 5) == "foo  "
    @test format(f"{y:{x}}", x = 5, y = "foo") == "foo  "

    pi = Float64(pi)
    @test format(f"{x:.{n}}", x = pi, n = 2) == format(f"{:.2}", pi)
    @test format(f"{x:.{n}}", x = pi, n = 3) == format(f"{:.3}", pi)
    @test format(f"{x:.{n}}", x = pi, n = 4) == format(f"{:.4}", pi)
    @test format(f"{x:.{n}}", x = pi, n = 5) == format(f"{:.5}", pi)

    @test format(f"{:,}", 1) == "1"
    @test format(f"{:,}", 12) == "12"
    @test format(f"{:,}", 123) == "123"
    @test format(f"{:,}", 1234) == "1,234"
    @test format(f"{:,}", 12345) == "12,345"
    @test format(f"{:,}", 123456) == "123,456"
    @test format(f"{:,}", 1234567) == "1,234,567"
    @test format(f"{:,}", 12345678) == "12,345,678"
    @test format(f"{:,}", 123456789) == "123,456,789"
    @test format(f"{:,}", 1234567890) == "1,234,567,890"

    @test format(f"{:_}", 1) == "1"
    @test format(f"{:_}", 12) == "12"
    @test format(f"{:_}", 123) == "123"
    @test format(f"{:_}", 1234) == "1_234"
    @test format(f"{:_}", 12345) == "12_345"
    @test format(f"{:_}", 123456) == "123_456"
    @test format(f"{:_}", 1234567) == "1_234_567"
    @test format(f"{:_}", 12345678) == "12_345_678"
    @test format(f"{:_}", 123456789) == "123_456_789"
    @test format(f"{:_}", 1234567890) == "1_234_567_890"

    @test format(f"{:_x}", 0x1) == "1"
    @test format(f"{:_x}", 0x12) == "12"
    @test format(f"{:_x}", 0x123) == "123"
    @test format(f"{:_x}", 0x1234) == "1234"
    @test format(f"{:_x}", 0x12345) == "1_2345"
    @test format(f"{:_x}", 0x123456) == "12_3456"
    @test format(f"{:_x}", 0x1234567) == "123_4567"
    @test format(f"{:_x}", 0x12345678) == "1234_5678"
    @test format(f"{:_x}", 0x123456789) == "1_2345_6789"
    @test format(f"{:_x}", 0x123456789a) == "12_3456_789a"

    @test format(f"{:_b}", 0b1) == "1"
    @test format(f"{:_b}", 0b10) == "10"
    @test format(f"{:_b}", 0b101) == "101"
    @test format(f"{:_b}", 0b1010) == "1010"
    @test format(f"{:_b}", 0b10101) == "1_0101"
    @test format(f"{:_b}", 0b101010) == "10_1010"

    @test format(f"{:_o}", 0o1) == "1"
    @test format(f"{:_o}", 0o12) == "12"
    @test format(f"{:_o}", 0o123) == "123"
    @test format(f"{:_o}", 0o1234) == "1234"
    @test format(f"{:_o}", 0o12345) == "1_2345"
    @test format(f"{:_o}", 0o123456) == "12_3456"

    @test format(f"{:15,}",  123456789) == "    123,456,789"
    @test format(f"{:15,}", -123456789) == "   -123,456,789"

    @test format(f"{:{}>6}", "foo", '*') == "***foo"
    @test format(f"{:{}<6}", "foo", '*') == "foo***"
    @test format(f"{:{}>{}}", "foo", '*', 6) == "***foo"
    @test format(f"{:{}<{}}", "foo", '*', 6) == "foo***"

    @test format(f"{:.0}", "abc") == ""
    @test format(f"{:.1}", "abc") == "a"
    @test format(f"{:.2}", "abc") == "ab"
    @test format(f"{:.3}", "abc") == "abc"
    @test format(f"{:.4}", "abc") == "abc"
    @test format(f"{:.5}", "abc") == "abc"
    @test format(f"{:.0}", "αβγ") == ""
    @test format(f"{:.1}", "αβγ") == "α"
    @test format(f"{:.2}", "αβγ") == "αβ"
    @test format(f"{:.3}", "αβγ") == "αβγ"
    @test format(f"{:.4}", "αβγ") == "αβγ"
    @test format(f"{:.5}", "αβγ") == "αβγ"

    @test format(f"{:1000f}", 1.0) == lpad("1.000000", 1000)
    @test format(f"{:.1000f}", 1.0) == rpad("1.", 1002, '0')

    @test format(f"{:00,d}",  1234) == "1,234"
    @test format(f"{:01,d}",  1234) == "1,234"
    @test format(f"{:02,d}",  1234) == "1,234"
    @test format(f"{:03,d}",  1234) == "1,234"
    @test format(f"{:04,d}",  1234) == "1,234"
    @test format(f"{:05,d}",  1234) == "1,234"
    @test format(f"{:06,d}",  1234) == "01,234"
    @test format(f"{:07,d}",  1234) == "001,234"
    @test format(f"{:08,d}",  1234) == "0,001,234"
    @test format(f"{:09,d}",  1234) == "0,001,234"
    @test format(f"{:010,d}", 1234) == "00,001,234"

    @test format(f"{:+#012_b}", 42) == "+0b0010_1010"
    @test format(f"{:+#013_b}", 42) == "+0b0_0010_1010"
    @test format(f"{:+#014_b}", 42) == "+0b0_0010_1010"

    @test format(f"{:,f}", 123.4) == "123.400000"
    @test format(f"{:,f}", 1234.5) == "1,234.500000"
    @test format(f"{:,f}", 1234567.89) == "1,234,567.890000"
    @test format(f"{:,f}",  6.0221409e+23) == "602,214,090,000,000,006,225,920.000000"
    @test format(f"{:+,f}", 6.0221409e+23) == "+602,214,090,000,000,006,225,920.000000"

    @test format(f"{:12,f}", 1234.0) == "1,234.000000"
    @test format(f"{:13,f}", 1234.0) == " 1,234.000000"
    @test format(f"{:14,f}", 1234.0) == "  1,234.000000"
    @test format(f"{:15,f}", 1234.0) == "   1,234.000000"
    @test format(f"{:16,f}", 1234.0) == "    1,234.000000"
    @test format(f"{:17,f}", 1234.0) == "     1,234.000000"

    @test format(f"{:012,f}", 1234.0) == "1,234.000000"
    @test format(f"{:013,f}", 1234.0) == "01,234.000000"
    @test format(f"{:014,f}", 1234.0) == "001,234.000000"
    @test format(f"{:015,f}", 1234.0) == "0,001,234.000000"
    @test format(f"{:016,f}", 1234.0) == "0,001,234.000000"
    @test format(f"{:017,f}", 1234.0) == "00,001,234.000000"

    @test format(f"{}",   big"42") == "42"
    @test format(f"{:b}", big"42") == "101010"
    @test format(f"{:o}", big"42") == "52"
    @test format(f"{:d}", big"42") == "42"
    @test format(f"{:x}", big"42") == "2a"
    @test format(f"{:X}", big"42") == "2A"

    @test format(f"{}", 0//1) == "0/1"
    @test format(f"{}", 1//100) == "1/100"
    @test format(f"{}", 2//100) == "1/50"
    @test format(f"{}", 355//113) == "355/113"
    @test format(f"{:f}", 1//2) == "0.500000"
    @test format(f"{:f}", 355//113) == "3.141593"
    @test format(f"{:.1f}", 355//113) == "3.1"
    @test format(f"{:.2f}", 355//113) == "3.14"
    @test format(f"{:.3f}", 355//113) == "3.142"
    @test format(f"{:.100f}", 355//113) == "3.1415929203539823008849557522123893805309734513274336283185840707964601769911504424778761061946902655"
    @test format(f"{:.1f}", 8999//10000) == "0.9"
    @test format(f"{:.2f}", 8999//10000) == "0.90"
    @test format(f"{:.3f}", 8999//10000) == "0.900"
    @test format(f"{:.4f}", 8999//10000) == "0.8999"
    @test format(f"{:.5f}", 8999//10000) == "0.89990"

    if Sys.WORD_SIZE == 64
        ptr = reinterpret(Ptr{Cvoid}, 0x000012340000abcd)
        @test format(f"{}",      ptr) == "0x000012340000abcd"
        @test format(f"{:p}",    ptr) == "0x000012340000abcd"
        @test format(f"{:20p}",  ptr) == "  0x000012340000abcd"
        @test format(f"{:<20p}", ptr) == "0x000012340000abcd  "
        @test format(f"{:^20p}", ptr) == " 0x000012340000abcd "
        @test format(f"{:>20p}", ptr) == "  0x000012340000abcd"
    end
end

@testset "printf" begin
    buf = IOBuffer()
    @test Fmt.printf(buf, f"foobar") === nothing
    @test String(take!(buf)) == "foobar"

    buf = IOBuffer()
    s = "(x = 123, y = -999)\n"
    @test Fmt.printf(buf, f"(x = {}, y = {})\n", 123, -999) === nothing
    @test String(take!(buf)) == s
end

@testset "interpolation" begin
    @test f"$" == "\$"
    @test f"$x" == "\$x"

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

    FOO = foo = 100
    @test f"{$FOO:d}" == "100"
    @test f"{$foo:d}" == "100"

    μ = 3.1
    σ = 0.1
    @test f"{$μ}±{$σ}" == "3.1±0.1"

    x = 42
    n = 4
    @test f"{$x:{$n}}" == "  42"

    x = 42
    @test f"{{" == "{"
    @test f"}}" == "}"
    @test f"{{{{" == "{{"
    @test f"}}}}" == "}}"
    @test f"{{}}" == "{}"
    @test f"}}{{" == "}{"
    @test f"{{$x}}" == "{\$x}"
    @test f"{{{$x}}}" == "{42}"
    @test f"{{{{$x}}}}" == "{{\$x}}"
    @test f"{{{{{$x}}}}}" == "{{42}}"

    @test f"{{αβ" == "{αβ"
    @test f"}}αβ" == "}αβ"
end

@testset "syntax error" begin
    parse = Fmt.parse
    FormatError = Fmt.FormatError
    @test_throws FormatError("single '{' is not allowed; use '{{' instead") parse("{")
    @test_throws FormatError("single '{' is not allowed; use '{{' instead") parse("{{{")
    @test_throws FormatError("single '}' is not allowed; use '}}' instead") parse("}")
    @test_throws FormatError("single '}' is not allowed; use '}}' instead") parse("}}}")
    @test_throws FormatError("invalid character '>'") parse("{>:}")
    @test_throws FormatError("invalid character 'Z'") parse("{:Z}")
    @test_throws FormatError("argument 0 is not allowed; use 1 or above") parse("{0}")
    @test_throws FormatError("identifier is expected after '\$'") parse("{\$:}")
    @test_throws FormatError("invalid conversion character 'K'") parse("{/K}")
    @test_throws FormatError("number overflows") parse("{9999999999999999999}")
    @test_throws FormatError("incomplete field") parse("{/s")
    @test_throws FormatError("incomplete field") parse("{:")
    @test_throws FormatError("incomplete field") parse("{:>")
    @test_throws FormatError("incomplete field") parse("{:*>")
    @test_throws FormatError("incomplete field") parse("{:+")
    @test_throws FormatError("incomplete field") parse("{:#")
    @test_throws FormatError("incomplete field") parse("{:3")
    @test_throws FormatError("incomplete field") parse("{:,")
    @test_throws FormatError("incomplete field") parse("{:d")
    @test_throws FormatError("mixing interpolated and non-interpolated fields is not allowed") parse("{\$x} {}")
end