FROM neomorphic/catalyst
MAINTAINER Jody Clements clementsj@janelia.hhmi.org

# Debian 9 "stretch" (this image's base) is EOL, so its packages have moved
# off the live mirrors to archive.debian.org. Repoint apt there before installing.
RUN printf 'deb http://archive.debian.org/debian stretch main\ndeb http://archive.debian.org/debian-security stretch/updates main\n' > /etc/apt/sources.list \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --allow-unauthenticated gnuplot

# Install the Perl dependencies first. These change rarely (only when
# cpanfile changes), so keeping them ahead of the R-scape source means an
# R-scape version bump won't bust this slow CPAN layer.
WORKDIR /app

COPY ./R-scape/cpanfile .

RUN cpanm DBD::mysql@4.046
RUN cpanm --installdeps .

# Build R-scape from the bundled tarball. The tarball changes on every
# version upgrade, so it lives below the CPAN layer to avoid invalidating it.
WORKDIR /build

COPY ./rscape.tar.gz .
RUN tar -zxvf rscape.tar.gz

WORKDIR /build/rscape_v2.6.7
RUN ./configure
RUN make && make install

WORKDIR /app

COPY ./R-scape/ .

EXPOSE 8080

CMD perl ./script/rscape_server.pl -d -r -p 8080
