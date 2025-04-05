#!/bin/bash

# Скрипт для просмотра доступных профилей, облаков и каталогов Yandex Cloud

echo "=== Доступные профили Yandex Cloud ==="
yc config profile list

echo -e "\n=== Активный профиль ==="
yc config profile get

# Вывод текущего облака и каталога для активного профиля
echo -e "\n=== Доступные облака ==="
yc resource-manager cloud list

echo -e "\n=== Доступные каталоги ==="
yc resource-manager folder list

echo -e "\n=== Текущие настройки активного профиля ==="
CURRENT_CLOUD_ID=$(yc config get cloud-id)
CURRENT_FOLDER_ID=$(yc config get folder-id)

if [ -n "$CURRENT_CLOUD_ID" ]; then
    CLOUD_NAME=$(yc resource-manager cloud get --id="$CURRENT_CLOUD_ID" --format=json | grep -o '"name": "[^"]*"' | cut -d'"' -f4)
    echo "Текущее облако: $CLOUD_NAME ($CURRENT_CLOUD_ID)"
else
    echo "Облако не выбрано"
fi

if [ -n "$CURRENT_FOLDER_ID" ]; then
    FOLDER_NAME=$(yc resource-manager folder get --id="$CURRENT_FOLDER_ID" --format=json | grep -o '"name": "[^"]*"' | cut -d'"' -f4)
    echo "Текущий каталог: $FOLDER_NAME ($CURRENT_FOLDER_ID)"
else
    echo "Каталог не выбран"
fi 