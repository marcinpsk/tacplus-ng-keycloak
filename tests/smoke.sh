#!/bin/bash
# Checks a built image: the samples parse, and each backend runs as the samples start it.
set -u
image=${1:?usage: smoke.sh IMAGE}
samples=$(cd "$(dirname "$0")/../sample" && pwd)
request='0 TACPLUS\n4 alice\n8 secret\n49 AUTH\n=\n'
failed=0

check() {
    local name=$1 expected=$2 output=$3
    if grep -qE "$expected" <<<"$output"; then
        echo "ok: $name"
    else
        echo "FAILED: $name: expected /$expected/, got:"
        echo "$output"
        failed=1
    fi
}

for cfg in tac_plus-ng-keycloak.cfg tac_plus-ng-keycloak-vault.cfg; do
    if output=$(docker run --rm -v "$samples:/samples:ro" "$image" -P "/samples/$cfg" 2>&1); then
        echo "ok: $cfg parses"
    else
        echo "FAILED: $cfg does not parse:"
        echo "$output"
        failed=1
    fi
done

# Nothing listens on port 9, so a backend that runs reports a backend error.
output=$(printf "$request" | docker run --rm -i -e KEYCLOAK_URL=http://127.0.0.1:9 \
    --entrypoint /usr/local/lib/mavis/mavis_tacplus_keycloak.py "$image" 2>&1)
check "keycloak backend answers" '^6 ERR$' "$output"
check "keycloak backend ends its reply" '^=0$' "$output"

output=$(printf "$request" | docker run --rm -i -e VAULT_ADDR=http://127.0.0.1:9 \
    -e VAULT_ROLE_ID=role -e VAULT_SECRET_ID=secret \
    --entrypoint /usr/local/lib/mavis/mavis_tacplus_vault.py "$image" 2>&1)
check "vault backend answers" '^6 ERR$' "$output"
check "vault backend ends its reply" '^=0$' "$output"

# Without a cache, INFO has no groups to return: README.md documents this.
info='0 TACPLUS\n4 alice\n49 INFO\n=\n'
output=$(printf "$info" | docker run --rm -i -e KEYCLOAK_URL=http://127.0.0.1:9 \
    --entrypoint /usr/local/lib/mavis/mavis_tacplus_keycloak.py "$image" 2>&1)
check "keycloak INFO without a cache is not found" '^6 NFD$' "$output"

output=$(printf "$info" | docker run --rm -i -e VAULT_ADDR=http://127.0.0.1:9 \
    -e VAULT_ROLE_ID=role -e VAULT_SECRET_ID=secret \
    --entrypoint /usr/local/lib/mavis/mavis_tacplus_vault.py "$image" 2>&1)
check "vault INFO without a cache is not found" '^6 NFD$' "$output"

# The licenses require that binary redistributions carry the notices.
for notice in LICENSE LICENSE.upstream; do
    output=$(docker run --rm --entrypoint /bin/cat "$image" "/usr/share/doc/tacplus-ng-keycloak/$notice" 2>&1)
    check "$notice is in the image" 'Copyright \(C\) .*Marc Huber' "$output"
done

exit "$failed"
