# Changelog

Breaking changes are listed first in each entry. Back up from Settings > Backup before you apply an update.

## 6.158.2 (2026-11-24)

First release of the template.

- Poznote 6.158.2, `ghcr.io/timothepoznanski/poznote:6.158.2@sha256:a3dbe7576f2ac29318a6bfca5adff380aec3a501e201059e1f95c15bdef1e494`.
- Data on a Railway volume at `/var/www/html/data`.
- First boot replaces upstream's default `admin_change_me` / `admin` account with `POZNOTE_ADMIN_USERNAME` and a generated `POZNOTE_ADMIN_PASSWORD`.
- PHP-FPM workers, the PHP memory limit and nginx workers are sized from the service's memory and CPU limits, and the container exits non-zero when nginx or PHP-FPM stops.
