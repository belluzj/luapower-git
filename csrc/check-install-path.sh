# check install_path on osx dylibs
check() {
    (cd ../bin/$1
    otool -L *.dylib | grep -v System | grep -v "++" | grep -v "dylib:" | grep -v "libgcc" # | grep -v "@loader_path/lib"
    )
}

check osx32
check osx64
