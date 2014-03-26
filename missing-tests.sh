#!/bin/bash
comm -23 <(./proj.sh) <(ls -1 *_test.lua | sed 's/_test.lua//g')

