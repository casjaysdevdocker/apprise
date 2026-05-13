#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# casjaysdevdocker/apprise - 05-custom.sh
#   1. Wipe distro defaults under /etc/{nginx,apprise}/* and drop in our
#      optimized configs from /tmp/etc/.
#   2. Clone the upstream apprise-api Django app to /usr/local/share/apprise-api.
#   3. pip install the Python deps Alpine doesn't ship.
#   4. Stage runtime dirs that the init.d scripts will need.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set -e -o pipefail
[ "$DEBUGGER" = "on" ] && echo "Enabling debugging" && set -x$DEBUGGER_OPTIONS

exitCode=0

APPRISE_API_VERSION="${APPRISE_API_VERSION:-master}"
APPRISE_API_REPO="${APPRISE_API_REPO:-https://github.com/caronc/apprise-api}"
APPRISE_API_INSTALL_DIR="/usr/local/share/apprise-api"

echo "Wiping distro defaults and installing optimized configs"
for svc in nginx apprise; do
  src="/tmp/etc/$svc"
  dst="/etc/$svc"
  [ -d "$src" ] || continue
  if [ "$svc" = "nginx" ]; then
    # Preserve mime.types + fastcgi_params from the package; we don't ship them.
    [ -f "$dst/mime.types" ] && cp -f "$dst/mime.types" "/tmp/${svc}_mime.types.preserve" || true
    [ -f "$dst/fastcgi_params" ] && cp -f "$dst/fastcgi_params" "/tmp/${svc}_fastcgi_params.preserve" || true
    [ -f "$dst/scgi_params" ] && cp -f "$dst/scgi_params" "/tmp/${svc}_scgi_params.preserve" || true
    [ -f "$dst/uwsgi_params" ] && cp -f "$dst/uwsgi_params" "/tmp/${svc}_uwsgi_params.preserve" || true
    [ -d "$dst/modules" ] && cp -Rf "$dst/modules" "/tmp/${svc}_modules.preserve" || true
  fi
  rm -Rf "$dst"/*
  mkdir -p "$dst"
  cp -Rf "$src/." "$dst/"
  if [ "$svc" = "nginx" ]; then
    [ -f "/tmp/${svc}_mime.types.preserve" ] && mv -f "/tmp/${svc}_mime.types.preserve" "$dst/mime.types"
    [ -f "/tmp/${svc}_fastcgi_params.preserve" ] && mv -f "/tmp/${svc}_fastcgi_params.preserve" "$dst/fastcgi_params"
    [ -f "/tmp/${svc}_scgi_params.preserve" ] && mv -f "/tmp/${svc}_scgi_params.preserve" "$dst/scgi_params"
    [ -f "/tmp/${svc}_uwsgi_params.preserve" ] && mv -f "/tmp/${svc}_uwsgi_params.preserve" "$dst/uwsgi_params"
    [ -d "/tmp/${svc}_modules.preserve" ] && cp -Rf "/tmp/${svc}_modules.preserve" "$dst/modules" && rm -Rf "/tmp/${svc}_modules.preserve"
  fi
  mkdir -p "/usr/local/share/template-files/config/$svc"
  cp -Rf "$dst/." "/usr/local/share/template-files/config/$svc/"
done

echo "Installing apprise-api from prebundled source tarball"
# Tarball is shipped in rootfs/tmp/apprise-src/ (downloaded on host pre-build)
# because the buildx build environment intermittently fails SSL validation
# against github.com. The host download is in .gitignore.
APPRISE_API_TARBALL="/tmp/apprise-src/apprise-api.tar.gz"
if [ ! -f "$APPRISE_API_TARBALL" ]; then
  echo "Apprise-api source tarball missing at $APPRISE_API_TARBALL" >&2
  echo "Run 'curl -fsSL -o rootfs/tmp/apprise-src/apprise-api.tar.gz \\" >&2
  echo "  https://github.com/caronc/apprise-api/archive/refs/heads/master.tar.gz' on the host first." >&2
  exit 12
fi
mkdir -p "$(dirname "$APPRISE_API_INSTALL_DIR")"
rm -Rf "$APPRISE_API_INSTALL_DIR" /tmp/apprise-api-extract
mkdir -p /tmp/apprise-api-extract
tar -xzf "$APPRISE_API_TARBALL" -C /tmp/apprise-api-extract/
SRC_DIR="$(find /tmp/apprise-api-extract -mindepth 1 -maxdepth 1 -type d -name 'apprise-api-*' | head -1)"
if [ -z "$SRC_DIR" ] || [ ! -d "$SRC_DIR" ]; then
  echo "Tarball extracted but no apprise-api-* dir found" >&2
  ls -la /tmp/apprise-api-extract >&2
  exit 13
fi
mv "$SRC_DIR" "$APPRISE_API_INSTALL_DIR"
rm -Rf /tmp/apprise-api-extract

# Upstream layout (verified at master):
#   repo-root/
#     manage.py            (launcher; adds apprise_api/ to sys.path)
#     apprise_api/         <-- the actual Django app: core/, api/, static/, etc/, gunicorn.conf.py
# Upstream Dockerfile does `COPY apprise_api/ webapp` — i.e. the *inner* dir
# becomes "webapp". We mirror that by symlinking apprise_api -> webapp so
# /usr/local/share/apprise-api/webapp/{core,static,gunicorn.conf.py,etc} all
# resolve correctly.
if [ -d "$APPRISE_API_INSTALL_DIR/apprise_api" ] && [ ! -e "$APPRISE_API_INSTALL_DIR/webapp" ]; then
  ln -sf "apprise_api" "$APPRISE_API_INSTALL_DIR/webapp"
fi

# Sanity check
if [ ! -f "$APPRISE_API_INSTALL_DIR/webapp/manage.py" ] && [ ! -f "$APPRISE_API_INSTALL_DIR/webapp/gunicorn.conf.py" ]; then
  echo "Apprise-API layout unexpected: webapp/gunicorn.conf.py missing after symlink" >&2
  ls -la "$APPRISE_API_INSTALL_DIR" "$APPRISE_API_INSTALL_DIR/webapp" 2>&1 | head -40 >&2
  exit 11
fi

# Patch gunicorn.conf.py: change socket path to our /run/apprise location, and
# fix the hard-coded pythonpath that upstream points at /opt/apprise/webapp.
GUNICORN_CONF="$APPRISE_API_INSTALL_DIR/webapp/gunicorn.conf.py"
if [ -f "$GUNICORN_CONF" ]; then
  sed -i 's|/tmp/apprise/gunicorn.sock|/run/apprise/gunicorn.sock|g' "$GUNICORN_CONF"
  sed -i 's|/opt/apprise/webapp|/usr/local/share/apprise-api/webapp|g' "$GUNICORN_CONF"
  echo "Patched gunicorn.conf.py: $GUNICORN_CONF"
fi

echo "Installing Python deps not in Alpine"
pip3 install --no-cache-dir --break-system-packages \
  apprise PGPy slixmpp smpplib gntp || \
  pip3 install --no-cache-dir \
  apprise PGPy slixmpp smpplib gntp

# Install the rest of upstream's requirements.txt (defensive; most are already
# satisfied by our Alpine packages or the explicit pip list above).
if [ -f "$APPRISE_API_INSTALL_DIR/requirements.txt" ]; then
  pip3 install --no-cache-dir --break-system-packages \
    -r "$APPRISE_API_INSTALL_DIR/requirements.txt" 2>/dev/null || \
  pip3 install --no-cache-dir \
    -r "$APPRISE_API_INSTALL_DIR/requirements.txt" 2>/dev/null || true
fi

echo "Creating runtime dirs"
mkdir -p /run/apprise /tmp/apprise /var/log/nginx \
         /usr/local/share/template-files/config/apprise \
         /usr/local/share/template-files/config/nginx
chmod 1777 /tmp/apprise

# Drop a sample apprise YAML into the template-files seed dir so first-run lands one.
if [ -f /tmp/etc/apprise/apprise.yml.sample ]; then
  cp -f /tmp/etc/apprise/apprise.yml.sample /usr/local/share/template-files/config/apprise/
fi

exit $exitCode
