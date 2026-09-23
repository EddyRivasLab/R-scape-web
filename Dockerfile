FROM ubuntu:26.04
LABEL maintainer="Jody Clements clementsj@janelia.hhmi.org"

# Keep apt from prompting (e.g. tzdata) and hanging the build.
ENV DEBIAN_FRONTEND=noninteractive

# System tools, gnuplot, and the Perl/Catalyst stack.
# Need gnuplot >= 5.2 to avoid SVG bug w/ unbalanced <g> tags.
# Almost the whole Catalyst stack is packaged for apt: faster, more reliable than CPAN
# gnuplot-nox gives the svg/pdf/postscript terminals without pulling Qt/X11 (R-scape renders headless). 
#
# curl (or wget) is needed to download RFview
# ca-certificates because RFview URL is https://
# zlib1g-dev works around a problem with current RFview image for linux/arm64
#
RUN apt-get update && apt-get install -y \
      build-essential autoconf automake libtool autotools-dev \
      curl ca-certificates \
      zlib1g-dev \
      gnuplot-nox gnuplot-data \
      perl cpanminus starman \
      libcatalyst-perl libcatalyst-modules-perl \
      libcatalyst-plugin-configloader-perl libcatalyst-plugin-static-simple-perl \
      libcatalyst-action-renderview-perl libcatalyst-view-tt-perl \
      libmoose-perl libnamespace-autoclean-perl libconfig-general-perl \
      libfile-slurp-perl libsereal-encoder-perl libsereal-decoder-perl \
    && rm -rf /var/lib/apt/lists/*

# These two are not packaged for Ubuntu. Pull from CPAN. Skip tests for speed.
#
RUN cpanm -n CatalystX::RoleApplicator Catalyst::TraitFor::Request::ProxyBase

# Build R-scape from the bundled tarball. 
#
WORKDIR /build
COPY ./rscape_v2.6.20.tar.gz .
RUN tar -zxvf rscape_v2.6.20.tar.gz

WORKDIR /build/rscape_v2.6.20
RUN ./configure
RUN make && make install

WORKDIR /app
COPY ./R-scape/ .

# Run the development server by default.
# For production server, this CMD is overidden by starman command in docker-compose.prod.yml.
#
EXPOSE 8080
CMD perl ./script/rscape_server.pl -d -r -p 8080
