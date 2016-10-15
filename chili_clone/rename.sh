#!/bin/sh
#Renames all the lua scripts - appends clone to its filename.
/usr/bin/find . -name '*.lua' | sed -e "p;s/.lua$/_clone.lua/" | xargs -n2 mv