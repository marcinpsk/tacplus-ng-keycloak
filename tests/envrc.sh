#!/bin/bash
# Runs .envrc under real uv versions: a too old uv must stop it, the minimum version must sync.
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
too_old=0.10.12
minimum=0.11.0
failed=0

fail() {
    echo "FAILED: $1"
    echo "$2"
    failed=1
}

run_envrc() {
    local dir=$work/$1
    mkdir -p "$dir/project"
    python3 -m venv "$dir/tool" && "$dir/tool/bin/pip" install --quiet "uv==$1" || exit 2
    cp "$repo/.envrc" "$repo/pyproject.toml" "$repo/uv.lock" "$dir/project/"
    [ "$2" = stale-venv ] && python3 -m venv "$dir/project/.venv"
    (cd "$dir/project" && PATH="$dir/tool/bin:$PATH" bash -c \
        'unset VIRTUAL_ENV; eval "$(direnv stdlib)"; source ./.envrc; echo "rc=$? venv=${VIRTUAL_ENV:+active}"' 2>&1)
}

output=$(run_envrc "$too_old" stale-venv)
grep -q 'Required uv version' <<<"$output" || fail "uv $too_old: no required-version error" "$output"
grep -q 'venv=active' <<<"$output" && fail "uv $too_old: activated a venv that did not sync" "$output"

output=$(run_envrc "$minimum" no-venv)
grep -q 'rc=0 venv=active' <<<"$output" || fail "uv $minimum: did not sync and activate" "$output"
[ -x "$work/$minimum/project/.venv/bin/ruff" ] || fail "uv $minimum: dependencies are missing" "$output"

[ "$failed" = 0 ] && echo "ok: .envrc requires uv $minimum"
exit "$failed"
