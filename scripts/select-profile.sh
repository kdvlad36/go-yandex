#!/bin/bash

# Скрипт для выбора и активации профиля Yandex Cloud

# Получаем список профилей и сохраняем в массив
echo "=== Получение списка профилей Yandex Cloud ==="
mapfile -t PROFILES < <(yc config profile list | awk 'NR>1 {print $1}')

if [ ${#PROFILES[@]} -eq 0 ]; then
    echo "Профили не найдены. Создайте профиль с помощью команды:"
    echo "yc config profile create <имя_профиля>"
    exit 1
fi

# Выводим список профилей с номерами
echo -e "\n=== Доступные профили Yandex Cloud ==="
for i in "${!PROFILES[@]}"; do
    ACTIVE=""
    if [[ "$(yc config profile get)" == "${PROFILES[$i]}" ]]; then
        ACTIVE=" (активный)"
    fi
    echo "$((i+1)). ${PROFILES[$i]}$ACTIVE"
done

# Запрашиваем у пользователя выбор профиля
echo -e "\nВведите номер профиля для активации (1-${#PROFILES[@]}):"
read -r PROFILE_NUMBER

# Проверяем корректность ввода
if ! [[ "$PROFILE_NUMBER" =~ ^[0-9]+$ ]] || [ "$PROFILE_NUMBER" -lt 1 ] || [ "$PROFILE_NUMBER" -gt "${#PROFILES[@]}" ]; then
    echo "Ошибка: введите корректный номер профиля от 1 до ${#PROFILES[@]}"
    exit 1
fi

# Вычисляем индекс в массиве (начинается с 0)
SELECTED_INDEX=$((PROFILE_NUMBER-1))
SELECTED_PROFILE="${PROFILES[$SELECTED_INDEX]}"

# Активируем выбранный профиль
echo -e "\nАктивация профиля '$SELECTED_PROFILE'..."
yc config profile activate "$SELECTED_PROFILE"

# Проверяем результат
if [ $? -eq 0 ]; then
    echo "Профиль '$SELECTED_PROFILE' успешно активирован!"
    
    # Показываем информацию о текущем профиле
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
else
    echo "Ошибка при активации профиля"
    exit 1
fi 