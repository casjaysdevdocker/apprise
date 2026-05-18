# AI context — apprise

## Build flow

1. `FROM casjaysdev/alpine:latest` (build stage) with gosu sidecar.
2. `COPY ./rootfs/. /` — ships all configs, scripts, and pre-bundled source tarball early.
3. `pkmgr install bash` → switch to `/bin/bash` shell.
4. Run `00-init.sh` (sanity setup, usually a no-op stub).
5. Run `01-system.sh` (timezone, system-level tweaks).
6. `pkmgr install $PACK_LIST` — installs nginx, python3, gunicorn, gevent, Django and all Alpine-packaged Python deps.
7. Run `02-packages.sh` (stub).
8. Run `03-files.sh` — auto-installs `rootfs/tmp/etc/nginx/` → `/etc/nginx/`, stages copies under `template-files/config/`.
9. Run `04-users.sh` — creates `apprise` system user/group via `addgroup -S / adduser -S`.
10. Run `05-custom.sh` — the critical build step:
    - Wipes `/etc/nginx/*` and replaces with our optimized config (preserving `mime.types`).
    - Unpacks the pre-bundled `apprise-api` source tarball from `/tmp/apprise-src/` into `/usr/local/share/apprise-api/`.
    - Patches `gunicorn.conf.py` to use `/run/apprise/gunicorn.sock` instead of upstream's `/tmp/` path.
    - `pip install apprise PGPy slixmpp smpplib gntp` (deps Alpine does not package).
    - Creates runtime directories and drops `apprise.yml.sample` into the template-files config seed.
11. Run `06-post.sh` (stub — late permission/symlink tweaks).
12. Run `07-cleanup.sh` (stub — per-service cache cleanup).
13. Generic cleanup (`pkmgr clean`, `rm -Rf /usr/share/doc/* /var/tmp/* ...`).
14. `FROM scratch` final stage: `COPY --from=build /. /`; sets ENVs, LABELs, VOLUME, EXPOSE, ENTRYPOINT/HEALTHCHECK.

## Services wired

| Component   | Binary/path                                              | Role                          |
|-------------|----------------------------------------------------------|-------------------------------|
| tini        | `/usr/bin/tini`                                          | PID 1 / reaper                |
| entrypoint  | `/usr/local/bin/entrypoint.sh`                           | Framework orchestrator        |
| init.d      | `/usr/local/etc/docker/init.d/99-apprise.sh`             | Service configuration + launch|
| start-apprise | `/usr/local/etc/docker/bin/start-apprise`              | Wrapper: gunicorn bg + nginx fg|
| gunicorn    | `/usr/bin/gunicorn` (via `py3-gunicorn`)                 | WSGI server (gevent workers)  |
| nginx       | `/usr/sbin/nginx`                                        | HTTP reverse proxy (port 8000)|

## init.d behavior (`99-apprise.sh`)

The script is sourced by `entrypoint.sh` via `__start_init_scripts`. It:

1. Checks `APPRISE_ENABLED` — exits silently if set to `no`.
2. Checks for the `/run/.start_init_scripts.pid` sentinel (prevents double-run on healthcheck invocations).
3. Cleans up stale PID files from prior crashes.
4. Calls framework hooks in order:
   - `__run_precopy` → `__execute_prerun` (creates runtime dirs `/run/apprise`, `/tmp/apprise`, `/data/logs/apprise`, `/config/apprise/{store,attach,plugin,conf.d}`)
   - `__initialize_system_etc` (seeds `/config/nginx/` from template-files on first run)
   - `__run_pre_execute_checks` (runs `nginx -t` to validate the config before starting)
   - `__update_conf_files` (token replacement: `REPLACE_TZ` → `${TZ:-UTC}` in nginx.conf)
   - `__pre_execute` (final last-mile actions)
   - `__run_start_script` (checks that nginx is not already running, then calls `start-apprise`)
   - `__post_execute` (background: copies `apprise.yml.sample` into `/config/apprise/` on first run)

## Config paths

| Path                             | Purpose                                               |
|----------------------------------|-------------------------------------------------------|
| `/etc/nginx/nginx.conf`          | Active nginx config (wipe-and-replace from our copy)  |
| `/config/nginx/`                 | User-editable nginx config (seeded on first run)      |
| `/config/apprise/store/`         | Apprise persistent config profiles (`<key>.yml`)      |
| `/config/apprise/attach/`        | Attachment staging area                               |
| `/config/apprise/plugin/`        | Custom Apprise plugins                                |
| `/config/apprise/conf.d/`        | Optional nginx location overrides (included optionally)|
| `/data/logs/apprise/`            | nginx access/error logs + gunicorn log                |
| `/run/apprise/gunicorn.sock`     | Unix socket between nginx and gunicorn                |
| `/usr/local/share/apprise-api/webapp/` | Django app root (manage.py, core/, api/, gunicorn.conf.py) |

## Environment variables (runtime)

| Variable               | Default                       | Used by                  |
|------------------------|-------------------------------|--------------------------|
| `APPRISE_ENABLED`      | `yes`                         | 99-apprise.sh            |
| `APPRISE_CONFIG_DIR`   | `/config/apprise/store`       | gunicorn / Django        |
| `APPRISE_ATTACH_DIR`   | `/config/apprise/attach`      | gunicorn / Django        |
| `APPRISE_PLUGIN_PATHS` | `/config/apprise/plugin`      | gunicorn / Django        |
| `TZ`                   | `America/New_York`            | nginx, Python logging    |

## start-apprise wrapper

`/usr/local/etc/docker/bin/start-apprise`:
1. Creates `/run/apprise`, `/tmp/apprise`, log dirs.
2. Exports `APPRISE_*` env defaults if not already set.
3. Starts gunicorn in background: `cd /usr/local/share/apprise-api/webapp && gunicorn -c gunicorn.conf.py --worker-tmp-dir /dev/shm core.wsgi >> /data/logs/apprise/gunicorn.log 2>&1 &`
4. Polls (up to 15s) for `/run/apprise/gunicorn.sock` to appear.
5. `exec /usr/sbin/nginx -c /etc/nginx/nginx.conf` — nginx runs in the foreground with `daemon off;`.

## File layout key

```
rootfs/
  usr/local/bin/entrypoint.sh          # SHARED: framework orchestrator (CONTAINER_NAME="apprise")
  usr/local/bin/pkmgr                  # SHARED: apk/apt/dnf wrapper
  usr/local/etc/docker/
    functions/entrypoint.sh            # SHARED: framework function library
    init.d/99-apprise.sh               # PER-REPO: service init + launch
    bin/start-apprise                  # PER-REPO: gunicorn+nginx launch wrapper
  tmp/etc/nginx/nginx.conf             # PER-REPO: optimized nginx config
  tmp/etc/nginx/mime.types             # PER-REPO: mime types (preserved from Alpine pkg)
  root/docker/setup/
    04-users.sh                        # PER-REPO: creates apprise system user
    05-custom.sh                       # PER-REPO: wipe-replace configs + pip install
```
