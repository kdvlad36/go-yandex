#!/bin/bash

# Определение пути к корневому каталогу проекта
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../../")"
export PROJECT_ROOT

# Параметры для деплоя функции
export FUNCTION_NAME="excel-report"
export FUNCTION_DIR="func/excel-report"
export FUNCTION_DESCRIPTION="Excel отчеты в формате XLSX"
export RUNTIME="golang121"
export ENTRYPOINT="main.Handler"
export MEMORY="256m"
export TIMEOUT="30s"
export LOG_LEVEL="info"

# Параметры для крон-триггера
export CRON_EXPRESSION="0 9 * * 1-5"  # В 9:00 по будням
export CRON_TIMEZONE="Europe/Moscow"

# Запуск основного скрипта деплоя
"$PROJECT_ROOT/core/deploy/deploy-without-api.sh"

# Создание триггера для крона
echo "=== Создание cron-триггера ==="
FUNCTION_ID=$(yc serverless function get --name "${FUNCTION_NAME}" --format json | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

# Проверяем существование триггера и удаляем его при необходимости
TRIGGER_EXISTS=$(yc serverless trigger list | grep "${FUNCTION_NAME}-cron-trigger" | wc -l)
if [ "$TRIGGER_EXISTS" -gt "0" ]; then
  echo "Триггер уже существует, удаляем..."
  yc serverless trigger delete --name="${FUNCTION_NAME}-cron-trigger"
fi

# Создаем триггер заново
yc serverless trigger create cron \
  --name="${FUNCTION_NAME}-cron-trigger" \
  --cron-expression="${CRON_EXPRESSION}" \
  --timezone="${CRON_TIMEZONE}" \
  --invoke-function-id="${FUNCTION_ID}" \
  --invoke-function-service-account-id="${SERVICE_ACCOUNT_ID:-"$(yc iam service-account get --name default --format json | jq -r .id)"}"

echo "=== Деплой функции ${FUNCTION_NAME} с cron-триггером завершен ===" 