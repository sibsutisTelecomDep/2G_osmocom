#!/bin/bash
set -e

IMSI1="999010000049398"
KI1="27C9FF2A073044B4665C7045B4C2F4D0"
MSISDN1="079231138992"

IMSI2="901700000049396"
KI2="1ED5340E5BE8E6F4D335AEA1EC0F94C6"
MSISDN2="079231260690"

# Проверка доступности порта 4258
if ! nc -z 127.0.0.1 4258; then
    echo "❌ Ошибка: порт 4258 не прослушивается. Убедись, что osmo-hlr запущен."
    exit 1
fi

function add_subscriber() {
    local imsi=$1
    local ki=$2
    local msisdn=$3

    echo "📡 Обработка IMSI: $imsi"

    (
        echo "enable"
        echo "show subscriber imsi $imsi"
        sleep 1
        echo "subscriber imsi $imsi create"
        echo "subscriber imsi $imsi update aud2g comp128v2 ki $ki"
        echo "subscriber imsi $imsi update msisdn $msisdn"
    ) | telnet 127.0.0.1 4258 | tee /tmp/hlr_out.txt

    if grep -q "IMSI:" /tmp/hlr_out.txt; then
        echo "ℹ️  IMSI $imsi уже существует, пропускаем создание."
    else
        echo "✅ Добавлен новый IMSI $imsi"
    fi
}

# Добавление абонентов
add_subscriber "$IMSI1" "$KI1" "$MSISDN1"
add_subscriber "$IMSI2" "$KI2" "$MSISDN2"

# Показать всех
(
    echo "enable"
    echo "show subscribers all"
) | telnet 127.0.0.1 4258
