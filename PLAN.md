# apprise migration plan

## Service intent

A self-hosted REST notification gateway built on the upstream `caronc/apprise-api` Django web app. Runs as a single Alpine-based Docker image bundling **nginx + gunicorn + Django + apprise** so users can POST a notification (with one or more notification URLs) and have it delivered to dozens of services (Discord, Slack, Telegram, Pushover, email, MQTT, etc.). Persistent stateful configs (`/cfg/<key>` style YAML/text profiles) live under `/config/store`. Container exposes **`:8000`**. Volumes: `/config` (apprise YAML/text config files + the canonical store), `/data` (logs, attachments, temp). Optional volumes the upstream supports (mapped under `/config` in our layout instead of separate mounts): `attachments` and `plugin paths`.

## Service stack

- Web frontend: `nginx` (Alpine), main config served from `/etc/nginx/nginx.conf` -> proxies `*` to gunicorn over `unix:/run/apprise/gunicorn.sock`. We base our nginx.conf on the upstream `apprise-api/etc/nginx.conf` (route table for `/`, `/notify`, `/notify/<key>`, `/status`, `/metrics`, `/details`, `/cfg`, `/add`, `/del`, `/get`, `/json/urls/...`, `/_/`, `/s/`, `/favicon.ico`, `/robots.txt`, catch-all). Single `server { listen 8000; }` block.
- Application: `apprise-api` Django app cloned from upstream `github.com/caronc/apprise-api` to `/usr/local/share/apprise-api/webapp/` (matches upstream's `/opt/apprise/webapp` layout but in our `/usr/local/share/<app>/` convention). Run via gunicorn.
- WSGI server: `gunicorn` with `gevent` worker class — invoked as `gunicorn -c /usr/local/share/apprise-api/webapp/gunicorn.conf.py --worker-tmp-dir /dev/shm core.wsgi`. Listens on `unix:/run/apprise/gunicorn.sock`.
- Notification engine: `apprise` (Python lib, `pip install apprise`). Pulls in 80+ notification backends (the rest of the upstream `requirements.txt` such as `paho-mqtt`, `gntp`, `cryptography`, `PGPy`, `slixmpp`, `smpplib` — Alpine has packages for some, the rest come from pip).
- Process supervisor: a small shell script `start-apprise` at `/usr/local/etc/docker/bin/start-apprise` (mirrors ampache's `start-ampache` pattern) that starts gunicorn in the background, waits for the unix socket, then `exec`s nginx in the foreground. The framework's `99-apprise.sh` invokes this single binary as its `EXEC_CMD_BIN` — the framework already handles supervision/restart.

## Packages (PACK_LIST / ENV_PACKAGES)

Verified against `pkgs.alpinelinux.org` for the `edge` branch (community + main). Each entry has a one-line justification.

System glue:
- `bash` — entrypoint and 99-* scripts are bash.
- `tini` — PID 1 init.
- `curl`, `wget` — entrypoint healthcheck + cloning fallback.
- `git` — clone the apprise-api repo at build time.
- `tzdata` — TZ awareness in nginx and Python logging.
- `ca-certificates` — TLS to outbound notification services.
- `pwgen` — random secrets/seed material if needed.
- `tar`, `gzip` — unpack archives if any (defensive).

nginx:
- `nginx` — front HTTP(S) proxy (port 8000 inside the container).
- `nginx-mod-http-headers-more` — not strictly required, dropped to keep image lean. Default `nginx` ships `mod_http_realip` etc., which is enough for our X-Forwarded-* setup.

Python runtime + Alpine-packaged Python deps (saves a lot of pip compile time and avoids needing build toolchain):
- `python3` — Python 3.x runtime.
- `py3-pip` — pip for the leftover deps from upstream `requirements.txt`.
- `py3-setuptools`, `py3-wheel` — needed for pip installs.
- `py3-django` — Django web framework (5.x in Alpine edge; upstream pins to `Django` open).
- `py3-gunicorn` — WSGI HTTP server.
- `py3-gevent` — async worker class for gunicorn (upstream uses `worker_class = "gevent"`).
- `py3-cryptography` — X.509/key handling; required by apprise + PGPy.
- `py3-requests` — HTTP client.
- `py3-yaml` — YAML config parsing (apprise YAML configs).
- `py3-paho-mqtt` — MQTT notification backend.
- `py3-aiodns` — async DNS, used by gevent.
- `py3-prometheus-client` — `/metrics` endpoint support.
- `py3-charset-normalizer` — requests dep, packaged.
- `py3-markdown` — apprise UI markdown rendering.
- `py3-six` — packaged transitive dep.
- `py3-django-prometheus` — Django prometheus middleware (upstream requirement).
- `py3-zope-event`, `py3-zope-interface` — gevent transitive deps (avoid pip rebuild).

Dropped from a hypothetical kitchen-sink list: `py3-uwsgi`, `uwsgi`, `uwsgi-python3` — upstream switched to gunicorn long ago; we follow upstream. No `apache2/php-fpm/mariadb` either; this is a pure Python web service.

`pip install` (in `02-packages.sh`, with `--break-system-packages`) for the deps Alpine doesn't ship:
- `apprise` (the notification library itself; the apprise-api Django app imports it at runtime).
- `PGPy` (PGP message support; not in Alpine).
- `slixmpp >= 1.10.0` (XMPP; not in Alpine).
- `smpplib` (SMPP; not in Alpine).
- `gntp` (Growl; not in Alpine).

## Configs to ship in rootfs/tmp/etc/

Wipe-and-replace at build time (per template §4). All paths under `rootfs/tmp/etc/`.

- `nginx/nginx.conf` — based on upstream `apprise-api/webapp/etc/nginx.conf`, lifted into our standard structure. Top-level: `daemon off;`, `worker_processes auto;`, `pid /run/apprise/nginx.pid;`, `error_log /data/logs/apprise/nginx-error.log;`. Inside `events { worker_connections 4096; }`. Inside `http { ... }`: include `mime.types`; `client_max_body_size 500M`; `access_log /data/logs/apprise/nginx-access.log;`; rate-limit zone for `/status` and `/metrics`; the **`upstream apprise_upstream { server unix:/run/apprise/gunicorn.sock max_fails=0; keepalive 16; }`**; one `server { listen 8000; listen [::]:8000; ... }` block with the full route table copied from upstream (locations for `/`, `/notify`, `/notify/<key>`, `/status|metrics`, `/details|json/urls/...`, `/cfg`, `/_/`, `/cfg|add|del|get/<key>`, `/s/`, `/favicon.ico`, `/robots.txt`, catch-all). Final line: `include /config/apprise/conf.d/*.conf;` (optional include for user-supplied vhost overrides).
- `nginx/mime.types` — preserved from the Alpine `nginx` package (we copy it back after wiping `/etc/nginx/`).
- `nginx/conf.d/.gitkeep` — empty placeholder.
- `apprise/apprise.yml.sample` — a documented sample apprise YAML config the user can copy into `/config/apprise/store/<key>.yml`. Comments explain TEXT vs YAML formats.

We don't ship a separate `gunicorn.conf.py` — the upstream's lives at `/usr/local/share/apprise-api/webapp/gunicorn.conf.py` and we use it as-is, only overriding the bind path via env (`APPRISE_WORKER_COUNT`, `APPRISE_WORKER_TIMEOUT`) when the user wants to.

## /config/<svc>/ layout (user-editable)

The framework's `__initialize_system_etc` symlinks every file under `/config/<svc>/` back to its `/etc/<svc>/` peer. The user-editable seed mirrors `/etc/`:

- `/config/nginx/nginx.conf` -> `/etc/nginx/nginx.conf`
- `/config/nginx/conf.d/*.conf` -> picked up by the `include /config/apprise/conf.d/*.conf;` line in nginx.conf for user-supplied location overrides
- `/config/apprise/apprise.yml.sample` -> documentation/sample
- `/config/apprise/store/` — apprise-api **persistent config store** (Django writes `<key>.yml` / `<key>.cfg` here when the user POSTs to `/add/<key>`). The `APPRISE_CONFIG_DIR` env points at `/config/apprise/store`.
- `/config/apprise/attach/` — optional attachments dir (`APPRISE_ATTACH_DIR`).
- `/config/apprise/plugin/` — optional custom plugin path (`APPRISE_PLUGIN_PATHS`).
- `/config/secure/auth/{root,user}/apprise_{name,pass}` — generated by the framework if the user opts into HTTP basic auth (none by default; apprise-api itself has no built-in auth).
- `/config/env/apprise.sh` — per-service env overrides (TZ, APPRISE_WORKER_COUNT, etc.).

`ADDITIONAL_CONFIG_DIRS` for apprise will be `/config/nginx /config/apprise` so each one runs through `__initialize_system_etc`.

## init.d/99-apprise.sh

Single init.d script (no separate DB — apprise-api is stateless / file-backed). Based on ampache's `99-ampache.sh` structure, with these knobs:

- `SERVICE_NAME="apprise"`
- `SERVICE_USER="apprise"`, `SERVICE_GROUP="apprise"`, but daemon runs as root by default (Alpine nginx package's user is `nginx`; we keep it simple and use `root` for the start script — gunicorn worker drops privileges if `--user`/`--group` are set, but we follow upstream and keep root).
- `EXEC_CMD_BIN='/usr/local/etc/docker/bin/start-apprise'`
- `EXEC_CMD_ARGS=''`
- `IS_WEB_SERVER="yes"`, `IS_DATABASE_SERVICE="no"`, `USES_DATABASE_SERVICE="no"`
- `WWW_ROOT_DIR="/usr/local/share/apprise-api/webapp"`, `ETC_DIR="/etc/nginx"`, `CONF_DIR="/config/nginx"`
- `ADDITIONAL_CONFIG_DIRS="/config/apprise"`
- `SERVICE_PORT="8000"`
- `__execute_prerun_local`: `mkdir -p /run/apprise /tmp/apprise /config/apprise/store /config/apprise/attach /config/apprise/plugin /data/logs/apprise`; `chmod 1777 /tmp/apprise`; `chown -Rf root:root /run/apprise`; export `APPRISE_CONFIG_DIR=/config/apprise/store`, `APPRISE_ATTACH_DIR=/config/apprise/attach`, `APPRISE_PLUGIN_PATHS=/config/apprise/plugin`.
- `__run_pre_execute_checks_local`: `nginx -t -c /etc/nginx/nginx.conf` to validate config before launch.
- `__update_conf_files_local`: replace `REPLACE_TZ` token in any of our shipped configs with `${TZ:-UTC}`. (Currently only nginx error_log gets one, optional.)
- `PRE_EXEC_MESSAGE="Apprise REST API listening on http://localhost:${SERVICE_PORT:-8000}/"`.

## start-apprise wrapper script

`rootfs/usr/local/etc/docker/bin/start-apprise` — small bash wrapper:
1. `set -e`
2. `mkdir -p /run/apprise /tmp/apprise /data/logs/apprise /config/apprise/store /config/apprise/attach /config/apprise/plugin`
3. `chmod 1777 /tmp/apprise`
4. Export the `APPRISE_*` env vars (defaults if user hasn't set them).
5. Start gunicorn in background: `cd /usr/local/share/apprise-api/webapp && gunicorn -c gunicorn.conf.py --worker-tmp-dir /dev/shm core.wsgi >>/data/logs/apprise/gunicorn.log 2>&1 &`
6. Wait up to 15s for `/run/apprise/gunicorn.sock` to appear.
7. `exec /usr/sbin/nginx -c /etc/nginx/nginx.conf` (nginx.conf has `daemon off;`).

The gunicorn config file sets `bind = ["unix:/run/apprise/gunicorn.sock"]` — we patch this in 05-custom.sh because upstream's path is `/tmp/apprise/gunicorn.sock`.

## 05-custom.sh additions

Replace the placeholder content with:

1. Wipe distro-default `/etc/nginx/*` and copy in our shipped nginx config (preserving `mime.types` and `fastcgi_params` from the package since we don't ship them):
   ```sh
   if [ -d /tmp/etc/nginx ]; then
     [ -f /etc/nginx/mime.types ] && cp -f /etc/nginx/mime.types /tmp/nginx-mime.types.preserve
     [ -f /etc/nginx/fastcgi_params ] && cp -f /etc/nginx/fastcgi_params /tmp/nginx-fastcgi_params.preserve
     rm -Rf /etc/nginx/*
     cp -Rf /tmp/etc/nginx/. /etc/nginx/
     [ -f /tmp/nginx-mime.types.preserve ] && mv -f /tmp/nginx-mime.types.preserve /etc/nginx/mime.types
     [ -f /tmp/nginx-fastcgi_params.preserve ] && mv -f /tmp/nginx-fastcgi_params.preserve /etc/nginx/fastcgi_params
     mkdir -p /usr/local/share/template-files/config/nginx
     cp -Rf /etc/nginx/. /usr/local/share/template-files/config/nginx/
   fi
   ```
2. Same wipe-and-replace pattern for `/etc/apprise/`.
3. Clone apprise-api at a pinned tag from upstream:
   ```sh
   APPRISE_API_VERSION="${APPRISE_API_VERSION:-master}"
   git clone --depth 1 --branch "$APPRISE_API_VERSION" https://github.com/caronc/apprise-api /usr/local/share/apprise-api
   ```
   Layout note: upstream repo's `apprise_api/` contents become `/usr/local/share/apprise-api/`. Inside, the Django app is the `Apprise-API` checkout's root (it already has `manage.py`, `core/`, `api/`, `error/`, `gunicorn.conf.py`). We adopt their `webapp/` symlink convention by creating `/usr/local/share/apprise-api/webapp -> .` so paths in our nginx.conf and start script can reference `/usr/local/share/apprise-api/webapp/` consistently with upstream.
4. Patch `gunicorn.conf.py` to point at our socket path:
   ```sh
   sed -i 's|/tmp/apprise/gunicorn.sock|/run/apprise/gunicorn.sock|g' /usr/local/share/apprise-api/webapp/gunicorn.conf.py
   ```
5. `pip install --no-cache-dir --break-system-packages apprise PGPy slixmpp smpplib gntp` (the deps Alpine doesn't package).
6. Create runtime dirs:
   ```sh
   mkdir -p /run/apprise /tmp/apprise /var/log/nginx /usr/local/share/template-files/config/apprise
   chmod 1777 /tmp/apprise
   ```
7. Drop a sample apprise YAML (`apprise.yml.sample`) into `/usr/local/share/template-files/config/apprise/` so first-run seeding lands one in `/config/apprise/`.

## 04-users.sh additions

The `nginx` Alpine package creates the `nginx` user automatically. Add a defensive `apprise` system user in case the framework's user creation hasn't run yet (`addgroup -S apprise 2>/dev/null; adduser -S -G apprise -H -h /var/lib/apprise -s /sbin/nologin apprise 2>/dev/null`). Keep it idempotent (the `|| true` pattern).

## 02-packages.sh additions

Empty placeholder is fine — pip installs go in 05-custom.sh next to the upstream clone (needs to run after the clone so we can also install from the repo's own `requirements.txt`). Decision: do `pip install` in `05-custom.sh`.

## Dockerfile changes

- Update `BUILD_DATE` to `202605091200` (today, 2026-05-09).
- Replace `PACK_LIST=" "` with the trimmed list above (single line, trailing space).
- Change `ARG SERVICE_PORT="80"` -> `"8000"` and `ARG EXPOSE_PORTS="80"` -> `"8000"` in the header. (Final-stage labels reuse them.)
- Change `PHP_VERSION="system"` to `"none"` (no PHP at all).
- Add `ARG CONTAINER_VERSION="USE_DATE"` so the YYMM tag is auto-added like ampache.
- Keep everything else (multi-stage, scratch final, ENVs, volumes, healthcheck).

## .env.scripts changes

- Sync `ENV_PACKAGES` to match the new `PACK_LIST` (single space, no doubles).
- `SERVICE_PORT="8000"`, `EXPOSE_PORTS=""`.
- `PHP_VERSION="none"`.

## README updates

Document the first-run workflow:
- visit `http://localhost:8000/` -> the apprise-api welcome UI.
- create a stateful config: `curl -X POST http://localhost:8000/add/mykey -d 'urls=mailto://user:pass@gmail.com'` (or POST a YAML body).
- send a notification: `curl -X POST http://localhost:8000/notify/mykey -d 'body=hello&title=test'`.
- stateless one-shot: `curl -X POST http://localhost:8000/notify -d 'urls=json://localhost&body=hi'`.
- volumes: `/config` (apprise YAML/text profiles + nginx overrides), `/data` (logs, attachments not-mounted-elsewhere).
- env vars: `TZ`, `APPRISE_WORKER_COUNT`, `APPRISE_WORKER_TIMEOUT`, `APPRISE_BASE_URL`, `APPRISE_STATEFUL_MODE`.

## Verification (success criteria)

1. `cd /root/Projects/github/casjaysdevdocker/apprise && rm -f .build_failed && buildx run Dockerfile` succeeds for both `linux/amd64` and `linux/arm64`. Single retry permitted on transient network errors.
2. `docker run -d --rm --name test-apprise -p 18000:8000 docker.io/casjaysdevdocker/apprise:latest` boots; after ~30s `docker logs test-apprise | tail -50` shows nginx + gunicorn started, no fatal errors.
3. `curl -fsS -o /dev/null -w '%{http_code}' http://localhost:18000/` returns 200.
4. `curl -fsS -X POST http://localhost:18000/notify -d 'urls=json://&body=test&title=test'` returns 200 (or a clear 4xx if the URL is rejected — note which).
5. `docker exec test-apprise ls /config/apprise/store /config/nginx/ /usr/local/share/apprise-api/webapp/manage.py` — every path exists.
6. `docker stop test-apprise`.

## Rollback

If anything in this PLAN.md proves wrong, the existing files are recoverable from git (`git checkout -- rootfs/`). New files (init.d/99-apprise.sh, tmp/etc/, start-apprise) can be removed cleanly because they didn't exist before this migration.
