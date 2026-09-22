# ARR stack operations

## Topology

Traefik is the public HTTPS entry point. Sonarr, Radarr, Prowlarr, Bazarr and
qBittorrent deliberately use `network_mode: service:tailscale`; this shares the
Tailscale network namespace and sends their egress through the configured exit
node. Do not remove this relationship if the exit-node requirement still applies.

For the local network, AdGuard rewrites `*.ahome.quest` to the media host. The
intended request path is:

`client -> AdGuard rewrite -> Traefik -> service label -> ARR service`

The services are intentionally componentized by directory:

```text
.
├── docker-compose.yml              # root orchestrator
├── traefik/traefik-compose.yml     # public HTTP/HTTPS entry point
├── traefik/config/                  # static and dynamic Traefik configuration
├── tailscale/tailscale-compose.yml # exit-node network namespace
├── sonarr/sonarr-compose.yml       # service definition
├── radarr/radarr-compose.yml
├── prowlarr/prowlarr-compose.yml
├── bazarr/bazarr-compose.yml
└── qbittorrent/qbittorrent-compose.yml
```

The root file uses Compose `include` to merge those files into one project. Each
service directory can also carry its ignored `config/` directory when this repo
is deployed directly on the media server. The services use these host paths:

- `${CONFIG_ROOT}/sonarr/config`, `${CONFIG_ROOT}/radarr/config`, etc.
- `${DATA_ROOT}/torrents` for qBittorrent staging
- `${DATA_ROOT}/movies`, `${DATA_ROOT}/tv`, `${DATA_ROOT}/animes`, `${DATA_ROOT}/music` for libraries

All *arr containers see the same host data tree at `/data`. This is important:
separate mounts such as `/downloads` and `/movies` can break hardlinks and force
copy/delete imports.

## First setup

1. Copy `.env.example` to `.env`, set mode `0600`, and set the real
   `TS_AUTHKEY`, `CF_DNS_API_TOKEN` and `TRAEFIK_ACME_EMAIL` values.
   `TRAEFIK_CONFIG_ROOT=./config` is relative to the `traefik/` Compose include.
2. Ensure the external Docker networks exist:

   ```sh
   docker network create frontend 2>/dev/null || true
   docker network create backend 2>/dev/null || true
   ```

3. Prepare the ACME state file with restrictive permissions:

   ```sh
   mkdir -p traefik/config/certs
   install -m 600 /dev/null traefik/config/certs/acme.json
   ```

4. Initialize the shared data directories if this is a new host:

   ```sh
   ./scripts/init-data-dirs.sh
   ```

5. Render and inspect the merged configuration before starting:

   ```sh
   docker compose --env-file .env config --quiet
   docker compose --env-file .env config --services
   ```

6. Start or update the project:

   ```sh
   docker compose --env-file .env up -d
   ```

Traefik obtains certificates through the Cloudflare DNS challenge. The token
should be limited to DNS edit access for the required zone. Never commit `.env`
or `traefik/config/certs/acme.json`.

## Verification

Check the merged project and service health:

```sh
docker compose --env-file .env ps
docker compose --env-file .env logs --tail=100 traefik
curl --fail --silent --show-error https://sonarr.ahome.quest/sonarr/ >/dev/null
curl --fail --silent --show-error https://radarr.ahome.quest/radarr/ >/dev/null
```

The service labels currently provide the Sonarr, Radarr, Prowlarr, Bazarr and
qBittorrent hostnames under `${MEDIA_DOMAIN}`. The Traefik dashboard is enabled
internally but is not exposed through an insecure entry point or an unauthenticated
public router.

## Safe update

1. Back up the config directories before changing image tags.
2. Review the image tag and release notes.
3. Run `docker compose --env-file .env config --quiet` and inspect the rendered mounts and networks.
4. Pull and recreate one service at a time when possible.
5. Verify the application through its Traefik hostname and inspect logs.
6. Keep the previous tag available for rollback.

Example:

```sh
./scripts/backup-config.sh
docker compose --env-file .env pull sonarr
docker compose --env-file .env up -d sonarr
docker compose --env-file .env logs --tail=100 sonarr
```

## Rollback

Restore the previous image tag in the relevant compose file, then run:

```sh
docker compose --env-file .env pull sonarr
docker compose --env-file .env up -d sonarr
```

Do not restore an application database from an arbitrary newer backup over an
older binary. Restore the matching config backup and image version together.
Do not delete the old configuration tree until the migrated services and their
data paths have been verified.

## Security checklist

- Use a short-lived or scoped Tailscale auth key where possible.
- Keep `.env` mode `0600`.
- Keep Docker socket access limited to Traefik and mounted read-only.
- Keep the Cloudflare token scoped to DNS edit access for the required zone.
- Keep `exposedByDefault: false` and the `frontend`/`backend` networks explicit.
- Do not enable Traefik's insecure dashboard entry point.
- Verify AdGuard rewrites and certificate issuance before changing the legacy deployment.
