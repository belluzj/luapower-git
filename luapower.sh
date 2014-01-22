#!/bin/sh
cd "${0%luapower.sh}" && exec ./luajit luapower.lua "$@"
