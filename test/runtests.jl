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