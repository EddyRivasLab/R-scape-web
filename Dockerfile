FROM neomorphic/catalyst
MAINTAINER Jody Clements clementsj@janelia.hhmi.org

RUN apt-get update && apt-get install -y gnuplot

WORKDIR /build

COPY ./rscape.tar.gz .
RUN tar -zxvf rscape.tar.gz

WORKDIR /build/rscape_v2.0.0.i
RUN ./configure
RUN make && make install

WORKDIR /app

COPY ./R-scape/cpanfile .

RUN cpanm DBD::mysql@4.046
RUN cpanm --installdeps .

COPY ./R-scape/ .

EXPOSE 8080

CMD perl ./script/rscape_server.pl -d -r -p 8080
