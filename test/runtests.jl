using Fmt
using Test

@testset "format" begin
    @test format(f"") == ""
    @test format(f"foobar") == "foobar"

    @test format(f"Hello, {}!", "world") == "Hello, world!"
    @test format(f"Hello, {}!", "世界") == "Hello, 世界!"

    @test format(f"x = {}", -3) == "x = -3"
    @test format(f"x = {}", 42) == "x = 42"
end
