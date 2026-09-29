# README del media-stack

## Ruta
Direct inline — README híbrido: onboarding público y referencia a la operación específica del servidor en `docs/OPERATIONS.md`.

## Tareas

- [x] RPI-001 Explorar Compose, variables, scripts, Traefik, Tailscale y documentación existente.
- [x] RPI-002 Definir README híbrido sin secrets ni valores operativos sensibles.
- [x] RPI-003 Escribir `README.md`.
- [x] RPI-004 Validar enlaces, snippets y cambios Git.

## Criterios de aceptación

- El README explica propósito, arquitectura, servicios, prerrequisitos y quick start.
- Los valores privados usan `.env.example`; no se documentan tokens reales.
- La operación avanzada se mantiene en `docs/OPERATIONS.md`.
- Las instrucciones usan los comandos y rutas que existen en el repositorio.
- El README incluye troubleshooting básico y mantenimiento.

## Evidencia

- `python3` comprobó 10 enlaces Markdown; no hay enlaces relativos faltantes.
- `docker compose --env-file .env.example config --quiet` terminó correctamente.
- `git diff --check` terminó correctamente.
- Las comprobaciones de contenido confirmaron referencias a Compose, operaciones, variables y scripts.
- Estado Git: `README.md` y `plan/tasks/media-stack-readme.md` son archivos nuevos sin cambios no relacionados.

## Siguiente paso

Revisar el README y decidir si se quiere versionar también el plan RPI.
