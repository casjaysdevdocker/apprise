# TODO — apprise

## Done

- [x] Dockerfile: BUILD_DATE=202605131434, prerequisites RUN=`true`, removed inline APK repos block, added `.profile` touch
- [x] .env.scripts: 2026 header, all ENV_ fields verified correct
- [x] entrypoint.sh: header updated (version + date), CONTAINER_NAME="apprise" confirmed
- [x] pkmgr: verified identical to template — no change needed
- [x] functions/entrypoint.sh: replaced with 2026 version from example (1724 lines)
- [x] 99-apprise.sh: full canonical rewrite — trap handler, script_exit, all 8 hook functions, framework call sequence, apprise-specific env/dirs
- [x] Setup scripts 00,01,02,03,06,07: updated to current example stubs
- [x] Setup scripts 04-users.sh, 05-custom.sh: preserved (service-specific logic)
- [x] `bash -n` syntax checks: all shell scripts pass
- [x] IDEA.md: created
- [x] AI.md: created
- [x] TODO.AI.md: this file

## Pending

- [ ] Build verification: `buildx run Dockerfile` for linux/amd64 + linux/arm64
- [ ] Smoke test: `docker run -d -p 18000:8000 casjaysdevdocker/apprise:latest`
  - [ ] `curl http://localhost:18000/` returns 200
  - [ ] `curl -X POST http://localhost:18000/notify -d 'urls=json://&body=test&title=test'` returns expected response
  - [ ] `/config/apprise/store`, `/config/nginx/`, `/usr/local/share/apprise-api/webapp/manage.py` all exist in container
