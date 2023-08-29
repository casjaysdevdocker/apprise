## 👋 Welcome to apprise 🚀  

apprise README  
  
  
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
mkdir -p "$HOME/.local/share/srv/docker/apprise/rootfs"
git clone "https://github.com/dockermgr/apprise" "$HOME/.local/share/CasjaysDev/dockermgr/apprise"
cp -Rfva "$HOME/.local/share/CasjaysDev/dockermgr/apprise/rootfs/." "$HOME/.local/share/srv/docker/apprise/rootfs/"
docker run -d \
--restart always \
--privileged \
--name casjaysdevdocker-apprise \
--hostname apprise \
-e TZ=${TIMEZONE:-America/New_York} \
-v "$HOME/.local/share/srv/docker/casjaysdevdocker-apprise/rootfs/data:/data:z" \
-v "$HOME/.local/share/srv/docker/casjaysdevdocker-apprise/rootfs/config:/config:z" \
-p 80:80 \
casjaysdevdocker/apprise:latest
```
  
## via docker-compose  
  
```yaml
version: "2"
services:
  ProjectName:
    image: casjaysdevdocker/apprise
    container_name: casjaysdevdocker-apprise
    environment:
      - TZ=America/New_York
      - HOSTNAME=apprise
    volumes:
      - "$HOME/.local/share/srv/docker/casjaysdevdocker-apprise/rootfs/data:/data:z"
      - "$HOME/.local/share/srv/docker/casjaysdevdocker-apprise/rootfs/config:/config:z"
    ports:
      - 80:80
    restart: always
```
  
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
