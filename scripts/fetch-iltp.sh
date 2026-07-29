#!/usr/bin/env sh
set -eu

version="1.1.2"
archive="ILTP-v${version}-propositional.tar.gz"
url="https://www.iltp.de/download/${archive}"
cache_dir="${ILTP_CACHE_DIR:-.cache/iltp}"
archive_path="${cache_dir}/${archive}"
expected_sha256="4931b81fcaacb96f3c5a118069658cd345903a3e3c834b08bf67f5d279673ee3"

mkdir -p "$cache_dir"

if [ ! -f "$archive_path" ]; then
    curl -L --fail --show-error "$url" -o "$archive_path"
fi

if command -v sha256sum >/dev/null 2>&1; then
    actual_sha256="$(sha256sum "$archive_path" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    actual_sha256="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
else
    echo "Neither sha256sum nor shasum is available" >&2
    exit 1
fi

if [ "$actual_sha256" != "$expected_sha256" ]; then
    echo "Checksum mismatch for $archive_path" >&2
    echo "expected: $expected_sha256" >&2
    echo "actual:   $actual_sha256" >&2
    exit 1
fi

tar -xzf "$archive_path" -C "$cache_dir"

stack run convert-iltp -- \
    --input "$cache_dir/ILTP-v${version}-propositional" \
    --output test/corpus/iltp
