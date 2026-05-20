#!/bin/sh
# ref: occ/files/build.d/occ.sh
set -e

mkdir /tmp/occ
download $(get-github-download-url shimarin occ '@tarball') | tar zxvf - -C /tmp/occ --strip-components=1
gcc -o /usr/bin/occ /tmp/occ/occ.c
