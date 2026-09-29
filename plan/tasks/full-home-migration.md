# Migración completa fuera de `/root/home`

## Ruta

Delegated direct operativo — mover configuración runtime al checkout `/root/media-stack`, validar el stack y retirar `/root/home` con backup externo.

## Layout destino

```text
/root/media-stack/
├── sonarr/config/
├── radarr/config/
├── prowlarr/config/
├── bazarr/config/
├── qbittorrent/config/
└── tailscale/config/
```

El contenido multimedia permanece en `/mnt/media` y Traefik continúa usando la configuración versionada del repositorio.

## Tareas

- [x] RPI-001 Confirmar dependencias y que los destinos runtime están vacíos.
- [x] RPI-002 Detener el stack y crear backup externo de `/root/home`.
- [x] RPI-003 Copiar configuraciones activas y estado de Tailscale al checkout.
- [x] RPI-004 Verificar inventarios/hash y cambiar `.env` a rutas locales.
- [x] RPI-005 Recrear todos los servicios y validar mounts, salud y conectividad.
- [x] RPI-006 Confirmar que no hay procesos/mounts activos bajo `/root/home`.
- [x] RPI-007 Eliminar `/root/home` y actualizar documentación local.

## Criterios de aceptación

- `CONFIG_ROOT` apunta a `/root/media-stack` en el host desplegado.
- `TS_STATE_DIR` apunta a `/root/media-stack/tailscale/config`.
- Ningún contenedor activo monta `/root/home`.
- Sonarr, Radarr, Prowlarr, Bazarr, qBittorrent, Tailscale y Traefik permanecen operativos.
- Las configuraciones y bases SQLite mantienen su contenido.
- `/root/home` se elimina solo después de backup y validación.
- `.env.example`, README y runbook describen el layout repository-local.

## Evidencia

- Backup externo creado en `/var/backups/media-stack/home-migration-20260929T135410Z/root-home.tar.gz`.
- El backup pasó `sha256sum -c` correctamente.
- Se detuvo el stack antes de copiar configuración y estado.
- Se copiaron las configuraciones activas a las carpetas `config/` ignoradas del checkout.
- `.env` remoto quedó con `CONFIG_ROOT=/root/media-stack` y `TS_STATE_DIR=/root/media-stack/tailscale/config`.
- `docker compose config --quiet` terminó correctamente.
- Todos los servicios principales volvieron a `running`.
- Mounts activos ya no contienen `/root/home`.
- HTTPS respondió `302` para Sonarr, Radarr, Prowlarr y Bazarr, y `200` para qBittorrent.
- Tailscale mantuvo el estado y mostró `fenix-icloud` como exit node activo.
- qBittorrent no tiene `/downloads` y continúa montando el NAS en `/data/torrents`.
- `/root/home` se movió temporalmente y luego se eliminó después de pasar las comprobaciones previas.
- La configuración local del repo fue actualizada para documentar el layout repository-local.

## Pendientes no bloqueantes

- El log de Bazarr mostró errores preexistentes de `ffprobe` para algunos archivos multimedia; no están relacionados con la migración de configuración.
- El archivo histórico `.env.codex-pre-tun-20260922` aún contiene las rutas antiguas como snapshot; no se usa por Compose, pero debe revisarse antes de limpiar snapshots.

## Siguiente paso

Usar `/root/media-stack` como única raíz operativa y proteger sus carpetas ignoradas contra `git clean -fdx`.
