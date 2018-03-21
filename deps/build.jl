using BinaryProvider, Compat, Compat.Libdl

# Parse some basic command-line arguments
const verbose = "--verbose" in ARGS
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = Product[
    LibraryProduct(prefix, String["libmbedcrypto"], :libmbedcrypto),
    LibraryProduct(prefix, String["libmbedtls"], :libmbedtls),
    LibraryProduct(prefix, String["libmbedx509"], :libmbedx509),
]

const juliaprefix = joinpath(Compat.Sys.BINDIR, "..")

juliaproducts = Product[
    LibraryProduct(juliaprefix, "libmbedtls", :libmbedtls)
    LibraryProduct(juliaprefix, "libmbedcrypto", :libmbedcrypto)
    LibraryProduct(juliaprefix, "libmbedx509", :libmbedx509)
]

# Download binaries from hosted location
bin_prefix = "https://github.com/quinnj/MbedTLSBuilder/releases/download/v0.6"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
      BinaryProvider.Linux(:aarch64, :glibc) => ("$bin_prefix/MbedTLS.aarch64-linux-gnu.tar.gz", "10791a0738faed8f2bdeec854ae114c33f29ed95ae827343ec4f195acda32249"),
    BinaryProvider.Linux(:armv7l, :glibc) => ("$bin_prefix/MbedTLS.arm-linux-gnueabihf.tar.gz", "f0cfe6bc29aca0f5baa17f10d408a395c4516c83b98a15eaca553ec3dcd7f70e"),
    BinaryProvider.Linux(:i686, :glibc) => ("$bin_prefix/MbedTLS.i686-linux-gnu.tar.gz", "ea5eccd728bdc8fb1ec5d771cd73bf49b2da2ec82df8583d973d0cf108db4658"),
    BinaryProvider.Windows(:i686) => ("$bin_prefix/MbedTLS.i686-w64-mingw32.tar.gz", "c429015e85aae1358b1097c8c0754bb6d9b601ece42679c47e43b1188d119391"),
    BinaryProvider.Linux(:powerpc64le, :glibc) => ("$bin_prefix/MbedTLS.powerpc64le-linux-gnu.tar.gz", "0f46f37d4976fd68a3897db1066f5e86cf33513193c859be1ffe3ef1c4ffe134"),
    BinaryProvider.MacOS() => ("$bin_prefix/MbedTLS.x86_64-apple-darwin14.tar.gz", "afefa088f6a10234e4491530e9d197296073167b532a33196118000e1f1dcf37"),
    BinaryProvider.Linux(:x86_64, :glibc) => ("$bin_prefix/MbedTLS.x86_64-linux-gnu.tar.gz", "47cbca328280f9131b95e413740b45417de2852684fbf67fa458c0dddf052fdc"),
    BinaryProvider.Windows(:x86_64) => ("$bin_prefix/MbedTLS.x86_64-w64-mingw32.tar.gz", "c4bc591d1a704ea09fcb3739a23b2cbaa1585489279f51604ebb7aaaae5b6aa4"),
)

# First, check to see if we're all satisfied
if any(!satisfied(p; verbose=verbose) for p in products) || get(ENV, "FORCE_BUILD", false)
    if haskey(download_info, platform_key()) && get(ENV, "FORCE_BUILD", "false") != "true" && !haskey(ENV, "USE_GPL_MBEDTLS")
        # Download and install binaries
        url, tarball_hash = download_info[platform_key()]
        install(url, tarball_hash; prefix=prefix, force=true, verbose=verbose)
        Compat.@info "using prebuilt binaries"
    elseif all(satisfied(p; verbose=verbose) for p in juliaproducts) && get(ENV, "FORCE_BUILD", "false") != "true"
        Compat.@info "using julia-shippied binaries"
        products = juliaproducts
    else
        Compat.@info "attempting source build"
        VERSION = "2.7.0"
        url, hash = haskey(ENV, "USE_GPL_MBEDTLS") ?
            ("https://tls.mbed.org/download/mbedtls-$VERSION-gpl.tgz", "2c6fe289b4b50bf67b4839e81b07fcf52a19f5129d0241d2aa4d49cb1ef11e4f") :
            ("https://tls.mbed.org/download/mbedtls-$VERSION-apache.tgz", "aeb66d6cd43aa1c79c145d15845c655627a7fc30d624148aaafbb6c36d7f55ef")
        download_verify(url, hash, joinpath(@__DIR__, "mbedtls.tgz"), force=true, verbose=true)
        unpack(joinpath(@__DIR__, "mbedtls.tgz"), @__DIR__; verbose=true)
        withenv("VERSION"=>VERSION) do
            run(Cmd(`./build.sh`, dir=@__DIR__))
        end
        if any(!satisfied(p; verbose=verbose) for p in products)
            error("attempted to build mbedtls shared libraries, but they couldn't be located (deps/usr/lib)")
        end
    end
end

write_deps_file(joinpath(@__DIR__, "deps.jl"), products)
