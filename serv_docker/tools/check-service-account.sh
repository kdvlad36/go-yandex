#!/bin/bash

# Скрипт для проверки наличия сервисных аккаунтов и выбора одного из них

# Проверка наличия yc CLI
if ! command -v yc &> /dev/null; then
  echo "Ошибка: Yandex Cloud CLI (yc) не установлен"
  echo "Пожалуйста, установите yc CLI: https://cloud.yandex.ru/docs/cli/quickstart"
  exit 1
fi

# Проверка наличия jq
if ! command -v jq &> /dev/null; then
  echo "Ошибка: утилита jq не установлена"
  echo "Пожалуйста, установите jq для корректной работы скрипта"
  exit 1
fi

# Проверка аутентификации в Yandex Cloud
if ! yc config list &> /dev/null; then
  echo "Ошибка: Вы не аутентифицированы в Yandex Cloud"
  echo "Запустите 'yc init' для настройки аутентификации"
  exit 1
fi

# Получение списка сервисных аккаунтов
echo "Получение списка сервисных аккаунтов..."
SERVICE_ACCOUNTS_OUTPUT=$(yc iam service-account list --format json 2>&1)

# Проверка на ошибки в выводе команды
if echo "$SERVICE_ACCOUNTS_OUTPUT" | grep -q "ERROR"; then
  echo "Ошибка при получении списка сервисных аккаунтов:"
  echo "$SERVICE_ACCOUNTS_OUTPUT"
  exit 1
fi

SERVICE_ACCOUNTS="$SERVICE_ACCOUNTS_OUTPUT"

# Проверка, есть ли сервисные аккаунты
SA_COUNT=$(echo "$SERVICE_ACCOUNTS" | jq length)

if [ -z "$SA_COUNT" ] || [ "$SA_COUNT" == "null" ]; then
  echo "Ошибка: Не удалось получить количество сервисных аккаунтов"
  exit 1
fi

if [ "$SA_COUNT" -eq 0 ]; then
  echo "Сервисные аккаунты не найдены. Необходимо создать сервисный аккаунт."
  
  # Запрашиваем имя для нового сервисного аккаунта
  echo -n "Введите имя для нового сервисного аккаунта: "
  read -r SA_NAME
  
  if [ -z "$SA_NAME" ]; then
    echo "Ошибка: Имя сервисного аккаунта не может быть пустым"
    exit 1
  fi
  
  # Создаем сервисный аккаунт
  echo "Создание сервисного аккаунта '$SA_NAME'..."
  NEW_SA_OUTPUT=$(yc iam service-account create --name="$SA_NAME" --format json 2>&1)
  
  # Проверка на ошибки в выводе команды
  if echo "$NEW_SA_OUTPUT" | grep -q "ERROR"; then
    echo "Ошибка при создании сервисного аккаунта:"
    echo "$NEW_SA_OUTPUT"
    exit 1
  fi
  
  NEW_SA="$NEW_SA_OUTPUT"
  SA_ID=$(echo "$NEW_SA" | jq -r .id)
  
  if [ -z "$SA_ID" ] || [ "$SA_ID" == "null" ]; then
    echo "Ошибка: Не удалось получить ID созданного сервисного аккаунта"
    exit 1
  fi
  
  # Назначаем роли
  FOLDER_ID=$(yc config get folder-id)
  echo "Назначение прав сервисному аккаунту..."
  ROLE_OUTPUT=$(yc resource-manager folder add-access-binding --id="$FOLDER_ID" --service-account-id="$SA_ID" --role=editor 2>&1)
  
  # Проверка на ошибки в выводе команды
  if echo "$ROLE_OUTPUT" | grep -q "ERROR"; then
    echo "Ошибка при назначении прав сервисному аккаунту:"
    echo "$ROLE_OUTPUT"
    echo "Но аккаунт был создан, ID: $SA_ID"
  fi
  
  echo "Сервисный аккаунт создан и настроен. ID: $SA_ID"
  
  # Сохраняем ID сервисного аккаунта во временный файл для использования в следующих скриптах
  echo "$SA_ID" > /tmp/selected_service_account_id
  
  exit 0
fi

# Удаляем дубликаты из списка аккаунтов на основе ID
UNIQUE_ACCOUNTS=$(echo "$SERVICE_ACCOUNTS" | jq 'unique_by(.id)')

# Получаем количество уникальных аккаунтов
UNIQUE_COUNT=$(echo "$UNIQUE_ACCOUNTS" | jq length)

# Выводим список сервисных аккаунтов для выбора
echo "Найдено $UNIQUE_COUNT сервисных аккаунтов:"
echo "$UNIQUE_ACCOUNTS" | jq -r '.[] | "\(.id) - \(.name)"' | nl -v 1

# Автоматический выбор при наличии только одного аккаунта
if [ "$UNIQUE_COUNT" -eq 1 ]; then
  SA_ID=$(echo "$UNIQUE_ACCOUNTS" | jq -r '.[0].id')
  SA_NAME=$(echo "$UNIQUE_ACCOUNTS" | jq -r '.[0].name')
  echo "Автоматически выбран единственный сервисный аккаунт: $SA_NAME (ID: $SA_ID)"
  echo "$SA_ID" > /tmp/selected_service_account_id
  exit 0
fi

# Запрос выбора пользователя при наличии нескольких аккаунтов
MAX_ATTEMPTS=3
ATTEMPTS=0

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  echo -n "Выберите номер сервисного аккаунта (1-$UNIQUE_COUNT): "
  read -r SELECTION
  
  if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le "$UNIQUE_COUNT" ]; then
    # Индекс в JSON-массиве начинается с 0
    INDEX=$((SELECTION - 1))
    SA_ID=$(echo "$UNIQUE_ACCOUNTS" | jq -r ".[$INDEX].id")
    SA_NAME=$(echo "$UNIQUE_ACCOUNTS" | jq -r ".[$INDEX].name")
    
    echo "Выбран сервисный аккаунт: $SA_NAME (ID: $SA_ID)"
    echo "$SA_ID" > /tmp/selected_service_account_id
    break
  else
    ATTEMPTS=$((ATTEMPTS+1))
    if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
      echo "Превышено количество попыток ввода. Выход."
      exit 1
    else
      echo "Некорректный ввод. Пожалуйста, введите число от 1 до $UNIQUE_COUNT. Осталось попыток: $((MAX_ATTEMPTS-ATTEMPTS))"
    fi
  fi
done

exit 0 