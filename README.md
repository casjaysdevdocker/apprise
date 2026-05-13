## Welcome to apprise

REST API gateway for the [apprise](https://github.com/caronc/apprise)
notification library. POST a notification to `http://<host>:8000/notify` (or
`/notify/<key>` for stateful configs) and apprise fans it out to dozens of
notification services (Discord, Slack, Telegram, Pushover, email, MQTT, ...).

This image bundles **nginx + gunicorn + Django + apprise-api** on top of Alpine.

### Ports

| Port | Purpose |
|------|---------|
| 8000 | Apprise REST API + web UI |

### Volumes

| Path | Purpose |
|------|---------|
| `/config` | Apprise YAML/text configs (`/config/apprise/store/<key>.yml`), nginx overrides (`/config/nginx/`), per-service env (`/config/env/apprise.sh`) |
| `/data`   | Logs (`/data/logs/apprise/`), runtime state |

## Install my system scripts

```shell
 sudo bash -c "$(curl -q -LSsf "https://github.com/systemmgr/installer/raw/main/install.sh")"
 sudo systemmgr --config && sudo systemmgr install scripts
```

## Automatic install/update

```shell
dockermgr update apprise
```

## Install and run container

```shell
dockerHome="/var/lib/srv/$USER/docker/casjaysdevdocker/apprise/apprise/latest/rootfs"
mkdir -p "$dockerHome/data" "$dockerHome/config"
docker run -d \
  --restart always \
  --name casjaysdevdocker-apprise-latest \
  --hostname apprise \
  -e TZ=${TIMEZONE:-America/New_York} \
  -v "$dockerHome/data:/data:z" \
  -v "$dockerHome/config:/config:z" \
  -p 8000:8000 \
  casjaysdevdocker/apprise:latest
```

## via docker-compose

```yaml
version: "2"
services:
  apprise:
    image: casjaysdevdocker/apprise
    container_name: casjaysdevdocker-apprise
    environment:
      - TZ=America/New_York
      - HOSTNAME=apprise
    volumes:
      - "./data:/data:z"
      - "./config:/config:z"
    ports:
      - 8000:8000
    restart: always
```

## First-run usage

1. Visit `http://localhost:8000/` to see the apprise-api welcome UI.
2. Save a stateful config (a named bundle of notification URLs):
   ```shell
   curl -X POST http://localhost:8000/add/mykey -d 'urls=mailto://user:pass@gmail.com'
   ```
3. Send a notification through it:
   ```shell
   curl -X POST http://localhost:8000/notify/mykey -d 'body=hello&title=test'
   ```
4. One-shot stateless notify (no saved config):
   ```shell
   curl -X POST http://localhost:8000/notify -d 'urls=json://localhost&body=hi&title=test'
   ```

## Useful environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `TZ` | `America/New_York` | Timezone for log timestamps |
| `APPRISE_WORKER_COUNT` | `(2*CPUs)+1` | gunicorn worker count |
| `APPRISE_WORKER_TIMEOUT` | `300` | gunicorn worker timeout (seconds) |
| `APPRISE_BASE_URL` | _(none)_ | Mount under a URL prefix, e.g. `/apprise` |
| `APPRISE_STATEFUL_MODE` | `simple` | `simple`, `hash`, or `disabled` |
  
## Get source files  
  
```shell
dockermgr download src casjaysdevdocker/apprise
```
  
OR
  
```shell
git clone "https://github.com/casjaysdevdocker/apprise" "$HOME/Projects/github/casjaysdevdocker/apprise"
```
  
## Build container  
  
```shell
cd "$HOME/Projects/github/casjaysdevdocker/apprise"
buildx 
```
  
## Authors  
  
🤖 casjay: [Github](https://github.com/casjay) 🤖  
⛵ casjaysdevdocker: [Github](https://github.com/casjaysdevdocker) [Docker](https://hub.docker.com/u/casjaysdevdocker) ⛵  
