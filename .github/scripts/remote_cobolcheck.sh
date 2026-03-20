#!/usr/bin/env zsh
set -euo pipefail

export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH="${JAVA_HOME}/bin:${PATH}"

cd /z/$1/cobolcheck

chmod +x cobolcheck
chmod +x scripts/linux_gnucobol_run_tests

./cobolcheck -p NUMBERS

cp "CC##99.CBL" "//'$2.CBL(NUMBERS)'"
cp "NUMBERS.JCL" "//'$2.JCL(NUMBERS)'"
