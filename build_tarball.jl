# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "libhello"
version = v"0.2.0"

projectname = "helloworld"

cp("LICENSE", joinpath(projectname, "LICENSE"), force=true)

# Collection of sources required to complete build
sources = [
    DirectorySource(projectname, target="projectname"),
]

# Bash recipe for building across all platforms
script = raw"""
# Override compiler ID to silence the horrible "No features found" cmake error
if [[ $target == *"apple-darwin"* ]]; then
  macos_extra_flags="-DCMAKE_CXX_COMPILER_ID=AppleClang -DCMAKE_CXX_COMPILER_VERSION=10.0.0 -DCMAKE_CXX_STANDARD_COMPUTED_DEFAULT=11"
fi

Julia_PREFIX=$prefix

mkdir build
cd build
cmake -DJulia_PREFIX=$Julia_PREFIX -DCMAKE_FIND_ROOT_PATH=$prefix -DJlCxx_DIR=$prefix/lib/cmake/JlCxx \
      -DCMAKE_INSTALL_PREFIX=$prefix -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
      $macos_extra_flags -DCMAKE_BUILD_TYPE=Release \
      ../projectname/
VERBOSE=ON cmake --build . --config Release --target install -- -j${nproc}

install_license ${WORKSPACE}/srcdir/projectname/LICENSE
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()
filter!(p -> !(Sys.islinux(p) && libc(p) == :musl && arch(p) == :i686), platforms)
platforms = expand_cxxstring_abis(platforms)
                        
# The products that we will ensure are always built
products = [
    LibraryProduct("libhello", :libhello),
]

# Dependencies that must be installed before this package can be built
# To provide binary for armv7l users, we need checkout libcxxwrap_julia_jll of version v0.8.2
# its `rev` is "b5edd5de8ab5b80e8f945bf1829048ef7a4feee0".
dependencies = [
    Dependency(PackageSpec(name="libcxxwrap_julia_jll", rev="libcxxwrap_julia-v0.8.4+0")),
    BuildDependency(PackageSpec(name="libjulia_jll", version=v"1.5.1")),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; preferred_gcc_version = v"7")
