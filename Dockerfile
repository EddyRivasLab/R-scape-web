FROM ubuntu:18.04
LABEL maintainer="Jody Clements clementsj@janelia.hhmi.org"

# Keep apt from prompting (e.g. tzdata) and hanging the build.
ENV DEBIAN_FRONTEND=noninteractive

# System tools, gnuplot, and the Perl/Catalyst stack. Ubuntu 18.04 ships
# gnuplot 5.2, whose SVG terminal produces valid XML (5.0 on the old Debian
# base emitted unbalanced <g> tags that browsers refused to render). Nearly the
# whole Catalyst stack is packaged, which is far faster and more reliable than
# building it from CPAN. gnuplot-nox gives the svg/pdf/postscript terminals
# without pulling Qt/X11 (R-scape renders headless). libdbd-mysql-perl is the
# 4.046 build the previous image pinned.
RUN apt-get update && apt-get install -y \
      build-essential autoconf automake libtool autotools-dev \
      gnuplot-nox gnuplot-data \
      perl cpanminus \
      libcatalyst-perl libcatalyst-modules-perl \
      libcatalyst-plugin-configloader-perl libcatalyst-plugin-static-simple-perl \
      libcatalyst-action-renderview-perl libcatalyst-view-tt-perl \
      libmoose-perl libnamespace-autoclean-perl libconfig-general-perl \
      libfile-slurp-perl libsereal-encoder-perl libsereal-decoder-perl \
      libdbd-mysql-perl \
    && rm -rf /var/lib/apt/lists/*

# These two are not packaged for bionic; pull from CPAN (skip tests for speed).
RUN cpanm -n CatalystX::RoleApplicator Catalyst::TraitFor::Request::ProxyBase

# Build R-scape from the bundled tarball. Kept below the dependency layers so an
# R-scape version bump doesn't invalidate them.
WORKDIR /build

COPY ./rscape.tar.gz .
RUN tar -zxvf rscape.tar.gz

WORKDIR /build/rscape_v2.6.8
# The tarball was packaged on macOS and ships stale Mach-O *.o/*.a build
# artifacts. The Linux linker can't read them ("file format not recognized"),
# so strip them and let make recompile everything from source for this platform.
RUN find . \( -name '*.o' -o -name '*.a' -o -name '*.lo' -o -name '*.la' \) -delete
# The config.sub/config.guess scripts bundled in the sub-projects (infernal,
# R2R, ...) predate aarch64 and reject this host ("machine aarch64 not
# recognized"). Refresh every copy with Ubuntu's current scripts so configure
# can auto-detect the architecture (native arm64 on Apple Silicon).
RUN find . -name config.sub  -exec cp /usr/share/misc/config.sub  {} \; \
 && find . -name config.guess -exec cp /usr/share/misc/config.guess {} \;
RUN ./configure
RUN make && make install

WORKDIR /app

COPY ./R-scape/ .

EXPOSE 8080

CMD perl ./script/rscape_server.pl -d -r -p 8080
