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
                            libortp-dev dahdi-source libsqlite3-dev libc-ares-dev libgnutls28-dev xfonts-base

    read -p "Нажмите Enter для продолжения сборки"                         
}

# Функция для клонирования и сборки проекта
build_project() {
    local repo_url=$1
    local repo_name=$2
    local skip_check=$3 

    echo "Сборка $repo_name..."
    cd $install_path
    git clone $repo_url
    cd $repo_name
    autoreconf -fi
    ./configure
    # ./configure --prefix=$install_path
    make -j$(nproc)

    if [ "$skip_check" != "true" ]; then
        make check
    else
        echo "Пропуск make check для $repo_name"
    fi

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

git clone https://github.com/axboe/liburing.git
cd liburing
./configure
make -j$(nproc)
sudo make install

# Сборка библиотеки libosmocore и связанных с ней библиотек
declare -a osmocom_libs=("libosmocore" "libosmo-abis" "libosmo-netif" "libosmo-sccp" "libosmo-sigtran")

for lib in "${osmocom_libs[@]}"; do
    build_project "https://gitea.osmocom.org/osmocom/$lib.git" "$lib" "false"
done

# Сборка библиотек и компонентов мобильной инфраструктуры
declare -a osmocom_components=("libsmpp34" "osmo-mgw" "libasn1c" "osmo-iuh" "osmo-hlr" "osmo-msc" "osmo-ggsn" "osmo-sgsn" "osmo-bsc" "osmo-bts" "osmo-bb")

for component in "${osmocom_components[@]}"; do
    build_project "https://gitea.osmocom.org/cellular-infrastructure/$component.git" "$component" "false"
done

echo "Скрипт завершен!"
