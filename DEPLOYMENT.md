# Deploying R-scape-web (production)

The app ships as a prebuilt container image, `ghcr.io/eddyrivaslab/r-scape-web:2.6.8`,
and runs Starman on `127.0.0.1:3000` behind the existing Apache reverse proxy
(`/R-scape/` → `http://localhost:3000/`). You only need `docker-compose.prod.yml`
from this repo — no source checkout or build on the server.

The production host runs **Ubuntu 18.04**, so Docker is installed from Docker's
official apt repo (the version in Ubuntu's own repo is too old).

## 1. Install Docker + compose (Ubuntu 18.04)

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Docker's official GPG key + repo for bionic
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu bionic stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
```

This gives Docker 24.x and the `docker compose` (v2) command. (Optional: add your
user to the `docker` group with `sudo usermod -aG docker $USER` and re-login to
drop the `sudo` prefix below.)

## 2. Get the compose file

Put `docker-compose.prod.yml` in a stable working directory (results are
persisted next to it under `./rscape-data`):
```bash
sudo mkdir -p /opt/rscape && cd /opt/rscape
# copy docker-compose.prod.yml here (scp, curl from the repo, etc.)
```

If the ghcr.io package is still **private**, log in once first (needs a GitHub
token with `read:packages`):
```bash
sudo docker login ghcr.io -u <github-user>
```
If it has been made public, no login is needed.

## 3. Retire the old service

The current site runs from the systemd unit `starman-rscape.service`, which holds
port 3000. Stop and disable it so it frees the port and won't restart:
```bash
sudo systemctl stop starman-rscape
sudo systemctl disable starman-rscape
# confirm nothing is still listening on 3000:
sudo ss -tlnp | grep ':3000' || echo "port 3000 free"
```

## 4. Start the new container

```bash
cd /opt/rscape
sudo docker compose -f docker-compose.prod.yml up -d
```
This pulls the right architecture (amd64), starts Starman on `127.0.0.1:3000`, and
restarts automatically unless stopped. Apache already proxies `/R-scape/` to that
port, so **no Apache change is needed**.

## 5. Verify

```bash
sudo docker ps                                              # container is Up
curl -sf -o /dev/null -w '%{http_code}\n' localhost:3000/   # expect 200
```
Then load the public URL (e.g. `http://eddylab.org/R-scape/`) and run a test
alignment.

## Rollback

If something is wrong, revert to the old service:
```bash
cd /opt/rscape && sudo docker compose -f docker-compose.prod.yml down
sudo systemctl enable --now starman-rscape
```

## Notes

- **Start on boot:** handled by the Docker daemon (`systemctl enable docker`) plus
  the compose file's `restart: unless-stopped`.
- **Upgrades:** push a new image tag (`...r-scape-web:2.6.9`), bump the `image:`
  line in `docker-compose.prod.yml`, then
  `sudo docker compose -f docker-compose.prod.yml pull && sudo docker compose -f docker-compose.prod.yml up -d`.
- **Disk:** result directories accumulate in `./rscape-data`; prune old ones
  periodically.
