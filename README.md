# tacplus-ng-keycloak

A container image of [tac_plus-ng](https://github.com/MarcJHuber/event-driven-servers) with two extra MAVIS backends:

- `mavis/mavis_tacplus_keycloak.py`: authenticates users against Keycloak with the ROPC grant, and maps Keycloak groups to TACACS+ groups.
- `mavis/mavis_tacplus_vault.py`: reads break-glass users from HashiCorp Vault.

The header of each script lists its environment variables. `sample/` has example configurations.

## Image

```bash
docker pull ghcr.io/marcinpsk/tacplus-ng-keycloak:latest
docker run --cap-add=NET_BIND_SERVICE -p 49:49 \
  -e KEYCLOAK_URL=https://keycloak.example.com \
  -e REDIS_URL=redis://redis.example.com:6379/0 \
  -v /path/to/config:/etc/tac_plus-ng:ro \
  ghcr.io/marcinpsk/tacplus-ng-keycloak:latest
```

The image reads `/etc/tac_plus-ng/tac_plus-ng.cfg`.

Both backends need a Redis or Valkey server for authorization, and the image does not include one. A successful login stores the user's groups there. INFO and HOST requests have no password, so they read the groups from that server. Without it, these requests return `NFD` (not found), also after a successful login. `REDIS_URL` names the server. Its default is `redis://localhost:6379/0`.

Give all variables with `-e` or an env file. One `setenv` in a `mavis module` block replaces the complete environment of the script, so the script does not get these variables. `sample/tac_plus-ng-keycloak-vault.cfg` explains this.

## Build

The upstream source is a git submodule in `upstream/`. Dependabot proposes updates to it, and CI builds and tests each one.

```bash
git clone --recurse-submodules https://github.com/marcinpsk/tacplus-ng-keycloak.git
cd tacplus-ng-keycloak
docker build -t tacplus-ng-keycloak .
tests/smoke.sh tacplus-ng-keycloak
```

Fixes to the C code go to upstream, not here. This repository has no patches to the upstream source.

## License

See [LICENSE](LICENSE). The files in `upstream/` have their own license in `upstream/LICENSE`. The image has both in `/usr/share/doc/tacplus-ng-keycloak/`.

This product includes software developed by Marc Huber (Marc.Huber@web.de).
