using MbedTLS
using Base.Test

# Hashing
let
    @test hash(MbedTLS.SHA1, "test") ==
      [169, 74, 143, 229, 204, 177, 155, 166, 28, 76, 8, 115, 211, 145, 233, 135, 152, 47, 187, 211]

    ctx = MbedTLS.MD5()
    write(ctx, UInt8[1, 2])
    write(ctx, UInt8[3, 4])
    @test MbedTLS.digest(ctx) ==
      [8, 214, 192, 90, 33, 81, 42, 121, 161, 223, 235, 157, 42, 143, 38, 47]
end

# Basic TLS client functionality
let
    sock = connect("httpbin.org", 443)
    entropy = MbedTLS.Entropy()
    rng = MbedTLS.CtrDrbg()
    MbedTLS.seed!(rng, entropy)

    ctx = MbedTLS.SSLContext()
    conf = MbedTLS.SSLConfig()

    MbedTLS.config_defaults!(conf)
    MbedTLS.authmode!(conf, MbedTLS.MBEDTLS_SSL_VERIFY_REQUIRED)
    MbedTLS.rng!(conf, rng)

    function show_debug(level, filename, number, msg)
        @show level, filename, number, msg
    end

    MbedTLS.dbg!(conf, show_debug)

    MbedTLS.ca_chain!(conf)

    MbedTLS.setup!(ctx, conf)
    MbedTLS.set_bio!(ctx, sock)

    MbedTLS.handshake(ctx)

    write(ctx, "GET / HTTP/1.1\r\nHost: httpbin.org\r\n\r\n")
    buf = bytestring(readbytes(ctx, 100))
    @test ismatch(r"^HTTP/1.1 200 OK", buf)
end
