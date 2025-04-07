#!/bin/bash

#
# @deploy - Деплой функции с cron-триггером
#
# Параметры окружения:
# - FUNCTION_NAME - имя функции [обязательный]
# - FUNCTION_DIR - путь к директории функции [обязательный]
# - CRON_EXPRESSION - выражение cron [обязательный]
# - FUNCTION_DESCRIPTION - описание функции
# - RUNTIME - среда выполнения [по умолчанию: golang121]
# - ENTRYPOINT - точка входа [по умолчанию: main.Handler]
# - SOURCE_PATH - путь к исходникам [по умолчанию: .]
# - MEMORY - объем памяти [по умолчанию: 256m]
# - TIMEOUT - таймаут выполнения [по умолчанию: 30s]
# - LOG_LEVEL - уровень логирования [по умолчанию: info]
# - CRON_TIMEZONE - часовой пояс [по умолчанию: Europe/Moscow]
#

# Проверка обязательных параметров
if [ -z "$FUNCTION_NAME" ] || [ -z "$FUNCTION_DIR" ] || [ -z "$CRON_EXPRESSION" ]; then
    echo "Ошибка: Необходимо указать FUNCTION_NAME, FUNCTION_DIR и CRON_EXPRESSION"
    exit 1
fi

# Установка значений по умолчанию для необязательных параметров
RUNTIME=${RUNTIME:-"golang121"}
ENTRYPOINT=${ENTRYPOINT:-"main.Handler"}
SOURCE_PATH=${SOURCE_PATH:-"."}
MEMORY=${MEMORY:-"256m"}
TIMEOUT=${TIMEOUT:-"30s"}
LOG_LEVEL=${LOG_LEVEL:-"info"}
CRON_TIMEZONE=${CRON_TIMEZONE:-"Europe/Moscow"}

echo "=== Начало деплоя функции ${FUNCTION_NAME} с cron-триггером ==="

# Сборка функции
echo "1. Сборка функции..."
cd "${PROJECT_ROOT}/${FUNCTION_DIR}" || exit 1
go build -o "${PROJECT_ROOT}/bin/${FUNCTION_NAME}" .

# Создание zip-архива
echo "2. Создание zip-архива..."
cd "${PROJECT_ROOT}/bin" || exit 1
zip -r "${FUNCTION_NAME}.zip" "${FUNCTION_NAME}"

# Деплой функции в Yandex Cloud
echo "3. Деплой функции в Yandex Cloud..."
FUNCTION_ID=$(yc serverless function create "${FUNCTION_NAME}" \
    --description "${FUNCTION_DESCRIPTION}" \
    --runtime "${RUNTIME}" \
    --entrypoint "${ENTRYPOINT}" \
    --memory "${MEMORY}" \
    --execution-timeout "${TIMEOUT}" \
    --source-path "${PROJECT_ROOT}/bin/${FUNCTION_NAME}.zip" \
    --log-level "${LOG_LEVEL}" \
    --folder-id "${FOLDER_ID}" \
    --service-account-id "${SERVICE_ACCOUNT_ID}" \
    --environment "${ENVIRONMENT}" \
    --network-id "${NETWORK_ID}" \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SECURITY_GROUP_IDS}" \
    --format json | jq -r '.id')

# Публикация новой версии функции
echo "4. Публикация новой версии функции..."
VERSION_ID=$(yc serverless function version create \
    --function-id "${FUNCTION_ID}" \
    --runtime "${RUNTIME}" \
    --entrypoint "${ENTRYPOINT}" \
    --memory "${MEMORY}" \
    --execution-timeout "${TIMEOUT}" \
    --source-path "${PROJECT_ROOT}/bin/${FUNCTION_NAME}.zip" \
    --service-account-id "${SERVICE_ACCOUNT_ID}" \
    --environment "${ENVIRONMENT}" \
    --network-id "${NETWORK_ID}" \
    --subnet-id "${SUBNET_ID}" \
    --security-group-ids "${SECURITY_GROUP_IDS}" \
    --format json | jq -r '.id')

# Создание cron-триггера
echo "5. Создание cron-триггера..."
TRIGGER_ID=$(yc serverless trigger create cron "${FUNCTION_NAME}-trigger" \
    --function-id "${FUNCTION_ID}" \
    --function-service-account-id "${SERVICE_ACCOUNT_ID}" \
    --cron-expression "${CRON_EXPRESSION}" \
    --timezone "${CRON_TIMEZONE}" \
    --retry-attempts 3 \
    --retry-interval 10s \
    --folder-id "${FOLDER_ID}" \
    --format json | jq -r '.id')

echo "=== Деплой функции ${FUNCTION_NAME} с cron-триггером завершен успешно ==="
echo "ID функции: ${FUNCTION_ID}"
echo "ID последней версии: ${VERSION_ID}"
echo "ID cron-триггера: ${TRIGGER_ID}"
echo "Cron-выражение: ${CRON_EXPRESSION} (${CRON_TIMEZONE})" 