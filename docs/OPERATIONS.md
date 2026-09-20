# ARR stack operations

## Topology

Traefik remains the public entry point. Sonarr, Radarr, Prowlarr, Bazarr and
qBittorrent deliberately use `network_mode: service:tailscale`; this shares the
Tailscale network namespace and sends their egress through the configured exit
node. Do not remove this relationship if the exit-node requirement still applies.

The services are intentionally componentized by directory:

```text
.
├── docker-compose.yml              # root orchestrator
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

The modular layout mirrors the legacy deployment without copying its runtime
state into Git. On the server, keep the repository checkout at the parent of
`sonarr/`, `radarr/`, `prowlarr/`, `bazarr/` and `qbittorrent/`; point
`CONFIG_ROOT` at the existing config root so the current databases and API keys
remain in place without being committed.

## First setup

```bash
cp .env.example .env
chmod 600 .env
./scripts/init-data-dirs.sh
docker compose config
docker compose up -d
```

Set `TS_AUTHKEY` only in `.env` or the shell. Never put API keys, auth keys,
passwords, databases or application config exports into Git.

## Safe update

1. Back up the config directories before changing image tags.
2. Review the image tag and release notes.
3. Run `docker compose config` and inspect the rendered mounts/networks.
4. Pull and recreate one service at a time when possible.
5. Verify the application through its Traefik hostname and inspect logs.
6. Keep the previous tag available for rollback.

Example:

```bash
./scripts/backup-config.sh
docker compose pull sonarr
docker compose up -d sonarr
docker compose logs --tail=100 sonarr
```

## Rollback

Restore the previous image tag in `docker-compose.yml`, then run:

```bash
docker compose pull sonarr
docker compose up -d sonarr
```

Do not restore an application database from an arbitrary newer backup over an
older binary. Restore the matching config backup and image version together.

## Security checklist

- Use a short-lived or scoped Tailscale auth key where possible.
- Keep `.env` mode `0600`.
- Keep Docker socket access limited to Traefik and review it periodically.
- Keep admin services behind Traefik authentication.
- Prefer stable/release images; Bazarr is currently on a development tag and
  should be moved to a stable release after checking its compatibility.
