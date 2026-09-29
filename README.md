# Media Stack

Stack multimedia autohospedado basado en Docker Compose para automatizar la
búsqueda, descarga, organización y subtitulación de películas y series.

El repositorio está pensado para ser reutilizable: la configuración específica
del servidor se inyecta mediante `.env` y la operación avanzada se documenta en
[`docs/OPERATIONS.md`](docs/OPERATIONS.md).

## Qué incluye

| Servicio | Propósito | URL por defecto |
| --- | --- | --- |
| [Sonarr](https://sonarr.tv/) | Gestión automática de series | `https://sonarr.<MEDIA_DOMAIN>` |
| [Radarr](https://radarr.video/) | Gestión automática de películas | `https://radarr.<MEDIA_DOMAIN>` |
| [Prowlarr](https://prowlarr.com/) | Gestión centralizada de indexers | `https://prowlarr.<MEDIA_DOMAIN>` |
| [Bazarr](https://www.bazarr.media/) | Gestión automática de subtítulos | `https://bazarr.<MEDIA_DOMAIN>` |
| [qBittorrent](https://www.qbittorrent.org/) | Cliente BitTorrent | `https://qbittorrent.<MEDIA_DOMAIN>` |
| [Traefik](https://traefik.io/traefik/) | Entrada HTTP/HTTPS y routing | `https://<MEDIA_DOMAIN>` |
| [Tailscale](https://tailscale.com/) | Red privada y salida mediante exit node | — |

Las imágenes de los contenedores están fijadas en los Compose individuales para
hacer las actualizaciones explícitas y permitir que Renovate las proponga de
forma controlada.

## Arquitectura

La topología separa cada servicio en su propio directorio, mientras que
[`docker-compose.yml`](docker-compose.yml) actúa como orquestador mediante
Compose `include`.

```text
Cliente
  │
  ▼
DNS local / AdGuard
  │  *.media-domain
  ▼
Traefik :80/:443
  │
  ├── Sonarr
  ├── Radarr
  ├── Prowlarr
  ├── Bazarr
  └── qBittorrent
       │
       └── network_mode: service:tailscale
             │
             └── Tailscale exit node
```

Los servicios ARR comparten el namespace de red de `tailscale`. Por tanto, su
tráfico de salida utiliza el exit node configurado en `TS_EXTRA_ARGS`. Traefik
permanece como punto de entrada público y enruta mediante labels de Docker.

Todos los servicios que procesan contenido montan el árbol de datos en `/data`.
Mantener torrents y bibliotecas bajo el mismo filesystem permite hardlinks y
movimientos atómicos durante la importación.

## Estructura del repositorio

```text
.
├── docker-compose.yml              # Orquestador principal
├── .env.example                    # Plantilla de configuración
├── tailscale/
│   ├── tailscale-compose.yml       # Namespace de red y exit node
│   └── config/                      # Estado ignorado de Tailscale
├── traefik/                        # Routing, TLS y certificados ACME
│   └── config/
├── sonarr/                         # Compose de Sonarr
├── radarr/                         # Compose de Radarr
├── prowlarr/                       # Compose de Prowlarr
├── bazarr/                         # Compose de Bazarr
├── qbittorrent/                    # Compose de qBittorrent
├── scripts/
│   ├── init-data-dirs.sh           # Crea el layout de bibliotecas
│   └── backup-config.sh             # Backup de configuración
└── docs/
    └── OPERATIONS.md               # Runbook operativo del servidor
```

## Requisitos

- Linux con Docker Engine y Docker Compose v2.
- Compose `include` disponible en la versión instalada de Docker Compose.
- Soporte para `/dev/net/tun` y capacidades `NET_ADMIN`/`SYS_MODULE` para
  Tailscale en modo kernel.
- Un dominio administrado por Cloudflare si se usa el resolver ACME DNS.
- Una cuenta de Tailscale y un exit node autorizado.
- Directorios persistentes para configuración y datos multimedia.

> Este repositorio no instala Docker, configura AdGuard ni crea el exit node.
> Esas piezas pertenecen a la infraestructura del host.

## Configuración inicial

### 1. Crear el archivo `.env`

```bash
cp .env.example .env
chmod 600 .env
```

Edita `.env` y revisa como mínimo:

- `PUID` y `PGID`: usuario y grupo propietarios de los datos.
- `TZ`: zona horaria del host.
- `CONFIG_ROOT`: raíz de las configuraciones persistentes. Para el layout
  recomendado dentro del checkout usa `.`; cada servicio escribirá en su propia
  carpeta `config/` ignorada.
- `DATA_ROOT`: raíz que contiene `torrents`, `movies`, `tv`, `animes` y `music`.
- `MEDIA_DOMAIN`: dominio base para las URLs de los servicios.
- `TRAEFIK_ACME_EMAIL`: correo usado por Let's Encrypt.
- `CF_DNS_API_TOKEN`: token de Cloudflare con permisos de edición DNS para el
  dominio configurado.
- `TS_STATE_DIR`: directorio persistente del estado de Tailscale. Para el
  layout recomendado usa `./tailscale/config`.
- `TS_AUTHKEY`: auth key de Tailscale. No la guardes en Git ni la compartas.
- `TS_EXTRA_ARGS`: argumentos de Tailscale, incluido el exit node aprobado.

Los nombres de red `TRAEFIK_NETWORK` y `TAILSCALE_NETWORK` deben coincidir con
las redes Docker externas que usará el despliegue.

### 2. Crear las redes externas

Los Compose esperan que las redes existan antes de iniciar el stack:

```bash
docker network create "${TRAEFIK_NETWORK:-frontend}"
docker network create "${TAILSCALE_NETWORK:-backend}"
```

Si las redes ya existen, Docker devolverá un error de nombre duplicado; en ese
caso no las recrees y continúa con el siguiente paso.

### 3. Preparar el layout de datos

Con el `.env` cargado en el shell:

```bash
set -a
. ./.env
set +a
./scripts/init-data-dirs.sh
```

Comprueba que el usuario indicado por `PUID`/`PGID` puede leer y escribir tanto
en `${CONFIG_ROOT}` como en `${DATA_ROOT}`.

### 4. Validar y levantar el stack

Primero renderiza la configuración para detectar variables obligatorias
faltantes:

```bash
docker compose config
```

Después inicia todos los servicios:

```bash
docker compose up -d
```

Comprueba el estado:

```bash
docker compose ps
docker compose logs -f --tail=100
```

La primera emisión de certificados puede tardar. Traefik necesita resolver el
DNS challenge de Cloudflare y guardar el estado ACME en
`traefik/config/certs/acme.json`.

## Configuración posterior al despliegue

La infraestructura levanta los contenedores, pero la configuración interna de
cada aplicación se completa desde sus respectivas interfaces:

1. Configura credenciales administrativas.
2. Configura Prowlarr y sus indexers.
3. Conecta Prowlarr con Sonarr y Radarr.
4. Configura qBittorrent como cliente de descarga.
5. Define categorías y rutas de descarga bajo `/data/torrents`.
6. Configura Sonarr y Radarr para importar desde `/data` hacia las bibliotecas.
7. Conecta Bazarr con Sonarr/Radarr y configura proveedores de subtítulos.
8. Verifica que las URLs públicas funcionan por HTTPS.

No expongas directamente los puertos internos de Sonarr, Radarr, Prowlarr,
Bazarr o qBittorrent. El acceso debe pasar por Traefik y las redes previstas.

## Operación diaria

```bash
# Ver estado
docker compose ps

# Seguir logs de un servicio
docker compose logs -f --tail=100 sonarr

# Reiniciar un servicio
docker compose restart sonarr

# Actualizar después de revisar los cambios
docker compose pull
docker compose up -d

# Detener el stack sin borrar volúmenes ni configuración
docker compose down
```

Para rutas, backups, troubleshooting, DNS local, hardlinks, Tailscale y
recomendaciones específicas del servidor, consulta
[`docs/OPERATIONS.md`](docs/OPERATIONS.md).

## Backups

El script incluido crea un archivo comprimido con la configuración de Sonarr,
Radarr, Prowlarr, Bazarr y qBittorrent:

```bash
set -a
. ./.env
set +a
BACKUP_DIR=./backups ./scripts/backup-config.sh
```

El backup excluye logs, carátulas y datos de Sentry para reducir su tamaño. La
carpeta `backups/` está ignorada por Git; almacénala además fuera del host si
necesitas protección ante pérdida del disco.

El estado de Traefik, incluyendo `acme.json`, se encuentra bajo
`traefik/config/certs/` y también debe incluirse en la estrategia de backup si
quieres conservar los certificados y el estado ACME.

## Actualizaciones

Renovate supervisa los Compose y propone actualizaciones de imágenes:

- Cambios `patch`, `minor` y de digest: agrupados, sin automerge.
- Cambios `major`: requieren aprobación explícita desde el Dependency Dashboard.
- Las imágenes permanecen fijadas para evitar actualizaciones implícitas.

Antes de aplicar una actualización importante:

```bash
docker compose config
docker compose pull
docker compose up -d
docker compose ps
```

Revisa los logs y prueba el acceso HTTPS a cada servicio después del cambio.

## Troubleshooting rápido

### `docker compose config` exige variables

Copia `.env.example` a `.env`, completa todos los valores obligatorios y vuelve
a ejecutar el comando. Compose no debe iniciarse con tokens inventados ni con
`replace-me`.

### Un servicio ARR no tiene conectividad

Comprueba que `tailscale` está levantado y que `TS_EXTRA_ARGS` apunta al exit
node esperado:

```bash
docker compose ps tailscale
docker compose logs --tail=100 tailscale
```

Los servicios ARR usan `network_mode: service:tailscale` deliberadamente. No
elimines esa relación si el requisito de salida por Tailscale sigue vigente.

### Traefik devuelve `404` o no emite certificados

Verifica:

- Que el DNS del hostname resuelve hacia el host correcto.
- Que los puertos 80 y 443 llegan al host.
- Que `CF_DNS_API_TOKEN` tiene permisos DNS suficientes.
- Que `MEDIA_DOMAIN` coincide con las labels de los Compose.
- Que los servicios están conectados a la red `frontend`.
- Los logs de Traefik: `docker compose logs -f --tail=100 traefik`.

### Las importaciones copian en lugar de usar hardlinks

Asegúrate de que las descargas y bibliotecas están bajo `${DATA_ROOT}` y que
los contenedores ven el árbol completo en `/data`. Montajes separados para
`/downloads` y `/movies` pueden estar en filesystems distintos y romper los
hardlinks.

## Seguridad y datos sensibles

- Nunca commits `.env`, auth keys de Tailscale, tokens de Cloudflare o passwords.
- Usa `.env.example` como plantilla y mantén `.env` con permisos restrictivos.
- El socket de Docker se monta en Traefik como solo lectura, pero sigue siendo
  una superficie sensible: limita quién administra el host.
- No publiques el dashboard de Traefik sin autenticación y una política de
  acceso adecuada.
- Revisa los permisos de `${CONFIG_ROOT}` y `${DATA_ROOT}` antes de dar acceso
  a otros usuarios.

## Licencia

Este repositorio contiene configuración de infraestructura. Las aplicaciones y
las imágenes utilizadas pertenecen a sus respectivos proyectos y conservan sus
propias licencias.
