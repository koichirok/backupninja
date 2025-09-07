FROM debian:sid

RUN apt-get -qq update && \
  apt-get -yqq upgrade && \
  DEBIAN_FRONTEND=noninteractive \
   apt -Uyqq install automake make dialog && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/src/backupninja
WORKDIR /usr/local/src/backupninja

COPY . .

RUN ./autogen.sh && \
  ./configure \
    --prefix=/usr \
    --mandir=/usr/share/man \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --libdir=/usr/lib \
    --libexecdir=/usr/lib && \
  make && \
  make install

WORKDIR /

RUN rm -rf /usr/local/src/backupninja
