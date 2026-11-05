# CLAUDE.md: tacplus-ng-keycloak

A container image of tac_plus-ng with Keycloak and Vault MAVIS backends. The C code is upstream's, in the `upstream/` submodule ([MarcJHuber/event-driven-servers](https://github.com/MarcJHuber/event-driven-servers)).

Do not change anything in `upstream/`. C fixes go to upstream, through the fork `marcinpsk/tacplus-ng`, which only follows upstream.

## Layout

```text
├── mavis/mavis_tacplus_keycloak.py   # ROPC auth, Keycloak groups to TACACS+ groups
├── mavis/mavis_tacplus_vault.py      # Break-glass users from Vault
├── sample/                           # Example configurations
├── tests/smoke.sh                    # Checks a built image
├── Dockerfile                        # Builds upstream/, adds the scripts
└── upstream/                         # Submodule, pinned commit
```

## Build and test

```bash
git submodule update --init
docker build -t tacplus-ng-keycloak .
tests/smoke.sh tacplus-ng-keycloak
```

A script runs alone against the upstream helper:

```bash
printf "0 TACPLUS\n4 user\n8 pass\n49 AUTH\n=\n" | \
  PYTHONPATH=upstream/mavis/python KEYCLOAK_URL=https://keycloak.example.com \
  python3 mavis/mavis_tacplus_keycloak.py
```

## MAVIS

MAVIS is upstream's plugin chain for authentication. `upstream/mavis/mavis.h` defines the attribute-value (AV) pairs. A module returns `MAVIS_FINAL` (done), `MAVIS_DOWN` (pass to next), or `MAVIS_DEFERRED` (async).

| Attribute | Description |
| --- | --- |
| `AV_A_TYPE` | Request type (`TACPLUS`) |
| `AV_A_USER` | Username |
| `AV_A_PASSWORD` | Password |
| `AV_A_TACTYPE` | Operation: `AUTH`, `INFO`, `CHPW`, `CHAL`, `HOST`, `DACL`, `MSCH` |
| `AV_A_RESULT` | `ACK` (ok), `NAK` (fail), `ERR` (error), `NFD` (not found) |
| `AV_A_TACMEMBER` | Group membership (quoted, comma-separated) |
| `AV_A_TACPROFILE` | Dynamic user profile |

External scripts are long-running processes that use stdin and stdout:

```text
# Input: one AV pair per line, ends with "="
0 TACPLUS
4 username
8 password
49 AUTH
=

# Output: AV pairs, then "=<verdict>"
47 "group1","group2"
6 ACK
=0
```

## Conventions

- Scripts use `upstream/mavis/python/mavis.py`, and follow `upstream/mavis/python/mavis_tacplus_ldap.py`. The image installs `mavis.py` to `/usr/local/lib/mavis`.
- Scripts must be executable, because the configurations name them directly in `exec =`.
- Group format: `'"group1","group2"'`.
- Python: tabs, checked by ruff (`ruff.toml`).
