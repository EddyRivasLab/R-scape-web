# Deploying R-scape-web (production)

## Overview

1. (First time on machine only): Provision a new machine.

2. Build new docker image.

   The image contains the current version of R-scape, the
   R-scape-web Catalyst server, and system tools.  Built on my laptop
   for testing as me (seddy); deployment version is built as sudo on
   eddylab.org.
   
3. Run (compose) the container.

   The production container is configured to automatically restart
   upon reboot, using the podman-restart.service. It runs the R-scape
   web app under a starman web server which listens at localhost port
   3000.
   
4. (First time running under Apache only): Configure the Apache server
   to forward eddylab.org/R-scape to localhost:3000, where the container's
   starman server is listening.


--------------------------------------------------------------------------------

## 1. Provision a new machine (one time only)

On production server `eddylab.org`, Ubuntu Linux x86_64:

    sudo apt-get update
    sudo apt-get install -y podman docker-compose-v2 
    
    sudo systemctl enable --now podman.socket
    sudo systemctl enable podman-restart.service

    sudo mkdir -p /opt/rscape/rscape-data

    cd ~/
    git clone https://github.com/EddyRivasLab/R-scape-web


### or on laptop, for development/debugging

    brew install podman docker-compose
    podman machine init --cpus 8 --memory 8192 --disk-size 100       # initialize a VM for 8 cpu, 8GRAM, 100G disk.

    # R-scape-web source is in my ~/web/R-scape-web
    
    

### notes on using podman (https://podman.io/)

Runs Open Container Initiative (OCI) containers and pods  
CLI compatible with Docker  
daemonless  

"image":     frozen filesystem, read-only, result of `podman build`.   example: `localhost/rscape:2.6.20`  
"container": composed image, with writable layer (running or stopped).  example: `r-scape-web-r-scape-1`  
"pod":       smallest computing unit in Kubernetes; >=1 containers.     (unused here)  

    podman machine list          # lists available machines (including new podman-machine-default)
    podman machine inspect       # info on the default machine
    podman machine ssh <cmd>     # run <cmd> in the VM, see the output
    
    podman images                # list available images
    podman rmi <image id|name>   # delete an image
    podman image prune           # delete untagged images no longer referenced
    podman rmi -a                # delete all local images

    podman ps                    # list running containers
    podman ps -a                 # list all containers, running + stopped
    podman logs r-scape-web-r-scape-1   # show output/error log from a (stopped/failed) container
    podman rm <container>        # remove a container
    
    podman cp ./<localfile> <container:>/<path>  # copy a file into a container
    
    podman run --rm localhost/rscape:2.6.20 bash -c 'ls -d /usr/share/gnuplot/gnuplot/*/PostScript'
       # run one command in the rscape:2.6.20 container, and stop container when done (--rm)

    podman system connection list     # see what kernel `podman build` will use: VM (on Mac) or native (on Linux)


The (MacOS development) podman VM is in `/Users/seddy/.local/share/containers/podman/machine/`.
The Mac's podman VM runs Fedora Linux by default. That's fine; the container runs the Ubuntu we configure it for.
We don't need a podman VM on eddylab.org; podman uses the native Linux kernel.




--------------------------------------------------------------------------------

## 2. Build a docker image with R-scape + R-scape-web Catalyst server.

Edit two configuration files:  
`Dockerfile`:            container configuration; what gets put in the docker container.  
`R-scape/rscape.conf`:  Catalyst server configuration that's copied into the docker container.  

Replace R-scape version with current: 2.6.20.

    # on eddylab.org
    cd ~/R-scape-web
    git pull
    wget https://github.com/EddyRivasLab/R-scape/releases/download/v2.6.20/rscape_v2.6.20.tar.gz
    sudo podman build -t localhost/rscape:2.6.20 .

The image is stored by podman in `/var/lib/containers/storage/`.

    sudo podman images
    # 2.92G image


### development/debugging

Can build on laptop too, as regular user, for testing.  
Depends on a Linux VM from podman.

    cd ~/web/R-scape-web
    git pull
    wget https://github.com/EddyRivasLab/R-scape/releases/download/v2.6.20/rscape_v2.6.20.tar.gz
    podman machine start
    podman build -t localhost/rscape:2.6.20 .

This image is stored in `~/.local/share/containers/storage/`.

### further explanation

the `-t localhost/rscape:2.6.20` in the `podman build` tags the image
with the `localhost/rscape:2.6.20` label.  The `docker-compose{.prod}.yml`
configuration looks for this image label.  We previously used a longer
tag `eddylab.org/rscape:<version>` that had to be downloaded from ghcr.io.

The `.` in the `podman build` specifies that the "build context" is
the repo root. All COPY commands resolve relative to R-scape-web
top-level.

In the `Dockerfile`, the `FROM ubuntu:26.04` causes `podman` to
download and run Ubuntu 26.04 as it builds the image. It's
architecture-dependent, so on my Mac it builds for arm64. For that
reason, the production image is created on an x86_64/amd64 platform
(which may as well be eddylab.org itself).

The `CMD` at the end of Dockerfile is only a default - it's set to
start the development server, `rscape_server.pl`, on port 8080.  The
production CMD is set by `docker-compose.prod.yml`: `command: starman
--listen :3000 --workers 5 rscape.psgi`, on port 3000.


--------------------------------------------------------------------------------

   
## 3. Run the image (compose the container):

Production config file: `docker-compose.prod.yml`  
Development config file: `docker-compose.yml`  

You don't have to stop the current container. Composing the new one
replaces the running one.

    cd ~/R-scape-web
    sudo podman compose -f docker-compose.prod.yml up -d

The `-d` is "detached": the container keeps running after you log
out. Without it, the container and its logging output are foreground
in the terminal.

Tmp files are stored in `/opt/rscape/rscape-data`. This path is configured
in `docker-compose.prod.yml`.

### Development/debugging version on Mac

    podman compose up           # starts the default development server
    
This will create a subdir `./rscape-data`, which the container mounts as `/tmp/rscape`. 
The tmp files from the R-scape server (inputs and results) are stored persistently here.

Specifically for development/debugging, the `R-scape/` copy in the
image is overridden: the `docker-compose.yml` configuration mounts the
local `./R-scape` directory live in the running container. Any changes
in the local (repo) copy of `./R-scape` will be live in the running
development server.



--------------------------------------------------------------------------------

## 4. eddylab.org Apache server configuration (one-time)

Once Apache is configured, you don't have to change or reconfig the
Apache server again just because you started running a new
container. Apache forwards to port :3000, and whatever container you
have listening to :3000 will handle the request.
    
`/etc/apache2/sites-available/eddylab.org.conf` contains this block of
configuration:

```
 # Jody's R-scape web server [SRE:2026/0916-rscape-web]
  <Location /R-scape/>
   ProxyPass http://localhost:3000/
   ProxyPassReverse http://localhost:3000/
       RequestHeader set X-Forwarded-Script-Name /R-scape
       RequestHeader set X-Forwarded-Path /R-scape
       RequestHeader set X-Request-Base http://eddylab.org/R-scape
       RequestHeader set X-Forwarded-Port 80
   </Location>
```

This configuration forwards to an application listening at
http://localhost:3000/.

The RequestHeader lines add extra information to the http header
before forwarding.

If you do modify `eddylab.org.conf` for some reason, restart apache:

    sudo apache2ctl configtest
    sudo systemctl restart apache2

