@rem execute luapower from this directory so that luapower can be run from any directory.
@pushd "%~dp0"
@call luajit luapower.lua %*
@popd
