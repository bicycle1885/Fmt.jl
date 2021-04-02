module Fmt

export @f_str, format

struct Format
    spec::String
end

function format(fmt::Format, args...)
    buf = IOBuffer()
    spec = fmt.spec
    last = lastindex(spec)
    i = k = 1
    while i ≤ last
        c = spec[i]
        if c == '{'
            if i == last || spec[i+1] ≠ '}'
                error("unpaired placeholder '{'")
            end
            print(buf, args[k])
            i += 1
            k += 1
        else
            write(buf, c)
        end
        i = nextind(spec, i)
    end
    if k ≠ length(args) + 1
        error("placeholders mismatch arguments")
    end
    return String(take!(buf))
end

macro f_str(s)
    Format(s)
end

end
