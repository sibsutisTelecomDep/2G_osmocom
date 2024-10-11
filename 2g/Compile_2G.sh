#!/bin/bash

sudo apt-get install -y build-essential libtool libtalloc-dev libsctp-dev shtool autoconf automake git-core pkg-config make gcc gnutls-dev python2-minimal libusb-1.0.0-dev libmnl-dev libpcsclite-dev
sudo apt-get install -y build-essential libtool libortp-dev dahdi-source libsctp-dev shtool autoconf automake git-core pkg-config make gcc 
sudo apt-get install -y libsqlite3-dev libc-ares-dev libtalloc-dev libpcsclite-dev libusb-1.0-0-dev libgnutls28-dev libmnl-dev xfonts-base
osmo_src=$HOME/2G
#Компиляция libosmocore.
mkdir $osmo_src
cd $osmo_src
git clone https://github.com/axboe/liburing.git
cd liburing
./configure
make
sudo make install
read -p "libosmocore"
array=(libosmocore libosmo-abis libosmo-netif libosmo-sccp libosmo-sigtran)
for i in ${array[@]}
do

cd $osmo_src
git clone https://gitea.osmocom.org/osmocom/$i.git
cd $i
autoreconf -fi
./configure
make -j$(nproc)
make check
read -p "$i"
sudo make install
sudo ldconfig
done

array=(libsmpp34 osmo-mgw libasn1c osmo-iuh osmo-hlr osmo-msc osmo-ggsn osmo-sgsn osmo-sgsn osmo-bsc osmo-bts)
for i in ${array[@]}
do

cd $osmo_src
git clone https://gitea.osmocom.org/cellular-infrastructure/$i.git
cd $i
autoreconf -fi
./configure
make -j$(nproc)
make check
read -p "$i"
sudo make install
sudo ldconfig
done