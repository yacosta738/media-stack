# Migración de descargas de qBittorrent al NAS

## Ruta

Delegated direct operativo — hotfix remoto autorizado en `mediaserver`, con backup, copia verificable y limpieza separada.

## Alcance

- Corregir el override de qBittorrent que usa `/downloads` sin mount.
- Copiar las descargas existentes al NAS bajo `${DATA_ROOT}/torrents`.
- Mantener intacta la configuración activa en `${CONFIG_ROOT}`.
- No borrar ni migrar todavía componentes legacy de `${CONFIG_ROOT}`.

## Tareas

- [x] RPI-001 Capturar snapshot remoto: mounts, tamaños, paths y disponibilidad.
- [x] RPI-002 Crear backup de configuración y detener qBittorrent.
- [x] RPI-003 Copiar `/downloads` a staging del NAS y verificar contenido.
- [x] RPI-004 Integrar staging en `/mnt/media/torrents` sin sobreescribir conflictos.
- [x] RPI-005 Cambiar `Downloads\\SavePath` y `Downloads\\TempPath` a `/data/torrents`.
- [x] RPI-006 Recrear qBittorrent y validar mounts, paths, torrents y logs.
- [x] RPI-007 Confirmar liberación de la capa local y documentar pendientes.

## Criterios de aceptación

- El contenedor no mantiene descargas en `/downloads`.
- `/downloads` no reaparece como ruta de escritura de qBittorrent.
- Las descargas migradas existen en el NAS y conservan tamaño/archivos.
- El contenedor monta `/mnt/media/torrents` en `/data/torrents`.
- qBittorrent levanta sin errores críticos y conserva su configuración/torrents.
- Sonarr/Radarr conservan `/data` y pueden acceder al contenido.
- No se elimina `/root/home/media` ni configuración activa sin una decisión posterior.

## Evidencia

- Backup creado en el host remoto bajo `qbittorrent/backups/migration-20260929T124200Z/`.
- qBittorrent se detuvo antes de la copia y se recreó después del cambio.
- Se copiaron 23 archivos y `29,155,640,784` bytes desde `/downloads` al NAS.
- Verificación post-copia: `missing=0`, `size_mismatch=0`.
- El staging se integró sin conflictos de tamaño y luego se eliminó.
- `Downloads\\SavePath` y `Downloads\\TempPath` ahora apuntan a `/data/torrents`.
- Los `.fastresume` activos quedaron con `old_path_bytes=0` y `nas_path_bytes=36`.
- Mount final: `/mnt/media/torrents -> /data/torrents`.
- Después de recrear el contenedor: `qbit_rw=305135` bytes y `/downloads` ya no existe.
- El disco local pasó de aproximadamente 35G usados a 7.3G usados.
- qBittorrent, Traefik, Tailscale, Sonarr, Radarr, Prowlarr y Bazarr quedaron `running`.
- `docker compose config --quiet` terminó correctamente.
- La URL HTTPS de qBittorrent devolvió HTTP 200.

## Pendiente fuera de alcance

- Revisar y separar la configuración legacy de `${CONFIG_ROOT}` (`calibre`, `jellyfin`, `plex`) en una tarea independiente.
- Considerar una futura migración de configuraciones fuera de la raíz histórica cuando se defina el layout deseado.

## Siguiente paso

Observar una descarga nueva y confirmar en la interfaz de qBittorrent que su ruta aparece bajo `/data/torrents`. No borrar todavía `${CONFIG_ROOT}`.
