#!/bin/sh
# Builds the Swift version of Fortran/two_impls_single.f90 from separately
# compiled modules, checks that a client importing only the protocol module is
# rejected, and runs the combined program with two link orders.
#
# Usage: ./run.sh BUILD_DIR
#
# All generated files (modules, objects, executables, logs and swiftc
# temporaries) are written to BUILD_DIR. Use a scratch directory outside the
# repository and delete it afterwards.
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 BUILD_DIR" >&2
    exit 2
fi
src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p -- "$1"
out=$(CDPATH= cd -- "$1" && pwd)
mkdir -p "$out/tmp"
TMPDIR="$out/tmp"
export TMPDIR

# Compile module $1 from $1.swift into $1.o and $1.swiftmodule. It can import
# only the modules built before it (found with -I "$out").
module() {
    swiftc -parse-as-library -module-name "$1" -I "$out" \
        -emit-module -emit-module-path "$out/$1.swiftmodule" \
        -c "$src/$1.swift" -o "$out/$1.o"
}

module Printable
module Plain
module Fancy
module PlainClient
module FancyClient
swiftc -module-name TwoImpls -I "$out" -c "$src/main.swift" -o "$out/main.o"

cd "$out"

echo "== ProtocolOnlyClient.swift (must be rejected)"
expected="error: value of type 'Double' has no member 'output'"
if swiftc -module-name ProtocolOnlyClient -I "$out" \
    "$src/ProtocolOnlyClient.swift" Printable.o Plain.o \
    -o protocol_only 2> protocol_only.log; then
    echo "FAILED: ProtocolOnlyClient.swift was accepted" >&2
    exit 1
fi
if ! grep -F -- "$expected" protocol_only.log > /dev/null; then
    cat protocol_only.log >&2
    echo "FAILED: expected diagnostic not found: $expected" >&2
    exit 1
fi
echo "rejected as expected: $expected"

swiftc main.o Printable.o Plain.o Fancy.o PlainClient.o FancyClient.o \
    -o two_impls_plain_first
swiftc main.o Printable.o Fancy.o Plain.o PlainClient.o FancyClient.o \
    -o two_impls_fancy_first

echo
echo "The programs below link two conformances of Double to IPrintable."
echo "Swift does not support that; their output is an observation only."
for order in plain_first fancy_first; do
    echo
    echo "== two_impls_$order"
    "./two_impls_$order"
done
