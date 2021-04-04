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

    @test format(f"x = {1}", 2) == "x = 2"
    @test format(f"x = {1}, y = {2}", 2, 3) == "x = 2, y = 3"
    @test format(f"x = {2}, y = {1}", 2, 3) == "x = 3, y = 2"
    @test format(f"x = {1}, y = {2}, z = {1}", 2, 3) == "x = 2, y = 3, z = 2"

    @test format(f"x = {x}", x = 2) == "x = 2"
    @test format(f"x = {x}, y = {y}", x = 2, y = 3) == "x = 2, y = 3"
    @test format(f"x = {x}, y = {y}", y = 3, x = 2) == "x = 2, y = 3"
    @test format(f"x = {x}, y = {y}, z = {x}", x = 2, y = 3) == "x = 2, y = 3, z = 2"

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
    @test format(f"{:b}", 99999) == "11000011010011111"
    @test format(f"{:o}", 99999) == "303237"
    @test format(f"{:d}", 99999) == "99999"
    @test format(f"{:X}", 99999) == "1869F"
    @test format(f"{:x}", 99999) == "1869f"

    @test format(f"{:#b}", 42) == "0b101010"
    @test format(f"{:#o}", 42) == "0o52"
    @test format(f"{:#d}", 42) == "42"
    @test format(f"{:#X}", 42) == "0X2A"
    @test format(f"{:#x}", 42) == "0x2a"

    @test format(f"{:s}", "abc") == "abc"

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
end
