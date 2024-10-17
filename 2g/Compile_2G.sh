#!/bin/bash

# Путь для установки
install_path="/home/kasperekd/2G"

update_system() {
    echo "Обновление списка пакетов и апгрейд системы..."
    sudo apt-get update
    read -p "Нажмите Enter для продолжения сборки"
    sudo apt-get upgrade -y
    read -p "Нажмите Enter для продолжения сборки"
}

# установка пакетов
install_packages() {
    echo "Установка необходимых пакетов..."
    sudo apt-get install -y python3
    read -p "Нажмите Enter для продолжения сборки"
    sudo apt-get install -y build-essential libtool libtalloc-dev libsctp-dev shtool autoconf automake git-core pkg-config make gcc gnutls-dev libusb-1.0.0-dev libmnl-dev libpcsclite-dev \
                            libortp-dev dahdi-source libsqlite3-dev libc-ares-dev libgnutls28-dev xterm xfonts-base libc6-dev

    read -p "Нажмите Enter для продолжения сборки"                         
}

# Функция для клонирования и сборки проекта
build_project() {
    local repo_url=$1
    local repo_name=$2
    local more_trx=$3 

    echo "Сборка $repo_name..."
    cd $install_path
    git clone $repo_url
    cd $repo_name
    autoreconf -fi
    ./configure
    # ./configure --prefix=$install_path

    if [ "$more_trx" == "true" ]; then
        file_path="$install_path/osmo-bts/src/Makefile"
        sudo sed -i 's/^#am__append_2 =/am__append_2 =/' "$file_path"
    fi

    make -j$(nproc)

    read -p "Нажмите Enter для продолжения сборки $repo_name"
    sudo make install
    sudo ldconfig
}

# Обновление системы
update_system
# Установка пакетов
install_packages

# Установка и сборка liburing 
osmo_src=$install_path
mkdir -p $osmo_src
sudo chown -R kasperekd osmo_src

cd $osmo_src
git clone https://github.com/axboe/liburing.git
cd liburing
./configure
make -j$(nproc)
sudo make install

# Сборка библиотеки libosmocore и связанных с ней библиотек
declare -a osmocom_libs=("libosmocore" "libosmo-abis" "libosmo-netif" "libosmo-sccp" "libosmo-sigtran" "libosmo-gprs")

for lib in "${osmocom_libs[@]}"; do
    build_project "https://gitea.osmocom.org/osmocom/$lib.git" "$lib" "false"
done

# Сборка библиотек и компонентов мобильной инфраструктуры
declare -a osmocom_components=("libsmpp34" "osmo-mgw" "libasn1c" "osmo-iuh" "osmo-hlr" "osmo-msc" "osmo-ggsn" "osmo-sgsn" "osmo-bsc")

for component in "${osmocom_components[@]}"; do
    build_project "https://gitea.osmocom.org/cellular-infrastructure/$component.git" "$component" "false"
done

build_project "https://gitea.osmocom.org/cellular-infrastructure/osmo-bts.git" "osmo-bts" "true"

cd $install_path
git clone https://gitea.osmocom.org/phone-side/osmocom-bb
cd osmocom-bb/src
sudo make -j$(nproc)

echo "Скрипт завершен!"
