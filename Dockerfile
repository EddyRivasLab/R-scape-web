FROM neomorphic/catalyst
MAINTAINER Jody Clements clementsj@janelia.hhmi.org

WORKDIR /app

COPY ./R-scape/cpanfile .

RUN cpanm DBD::mysql@4.046
RUN cpanm --installdeps .

COPY ./R-scape/ .

EXPOSE 8080

CMD perl ./script/rscape_server.pl -d -r -p 8080
