#!/bin/bash

# Определение пути к корневому каталогу проекта
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../../")"
export PROJECT_ROOT

# Параметры для деплоя функции
export FUNCTION_NAME="excel-report"
export FUNCTION_DIR="func/excel-report"
export FUNCTION_DESCRIPTION="Excel отчеты в формате XLSX, триггер из YMQ"
export RUNTIME="golang121"
export ENTRYPOINT="main.Handler"
export MEMORY="256m"
export TIMEOUT="30s"
export LOG_LEVEL="info"

# Параметры для YMQ триггера
export YMQ_QUEUE_NAME="excel-report-queue"
export SERVICE_ACCOUNT_ID="${SERVICE_ACCOUNT_ID:-"$(yc iam service-account get --name default --format json | jq -r .id)"}"

# Запуск основного скрипта деплоя
"$PROJECT_ROOT/core/deploy/deploy-without-api.sh"

# Проверяем существование очереди YMQ
echo "=== Проверка существования очереди YMQ ==="
QUEUE_EXISTS=$(yc message-queue queue list | grep "${YMQ_QUEUE_NAME}" | wc -l)
if [ "$QUEUE_EXISTS" -eq "0" ]; then
  echo "Создаем очередь YMQ ${YMQ_QUEUE_NAME}..."
  yc message-queue queue create --name="${YMQ_QUEUE_NAME}" --visibility-timeout=30s --redrive-policy="{\"deadLetterQueueName\":\"${YMQ_QUEUE_NAME}-dlq\",\"maxReceiveCount\":3}"
  
  # Создаем очередь для недоставленных сообщений (dead-letter queue)
  yc message-queue queue create --name="${YMQ_QUEUE_NAME}-dlq"
fi

# Создание триггера для YMQ
echo "=== Создание YMQ триггера ==="
FUNCTION_ID=$(yc serverless function get --name="${FUNCTION_NAME}" --format json | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

# Проверяем существование триггера и удаляем его при необходимости
TRIGGER_EXISTS=$(yc serverless trigger list | grep "${FUNCTION_NAME}-ymq-trigger" | wc -l)
if [ "$TRIGGER_EXISTS" -gt "0" ]; then
  echo "Триггер уже существует, удаляем..."
  yc serverless trigger delete --name="${FUNCTION_NAME}-ymq-trigger"
fi

# Создаем триггер заново
yc serverless trigger create message-queue \
  --name="${FUNCTION_NAME}-ymq-trigger" \
  --queue="${YMQ_QUEUE_NAME}" \
  --invoke-function-id="${FUNCTION_ID}" \
  --invoke-function-service-account-id="${SERVICE_ACCOUNT_ID}" \
  --batch-size=1 \
  --batch-cutoff=0

echo "=== Деплой функции ${FUNCTION_NAME} с YMQ триггером завершен ==="
echo "Вы можете отправить сообщение в очередь командой:"
echo "yc message-queue message send --queue-name=${YMQ_QUEUE_NAME} --data='{\"projectName\":\"Мой проект\"}'" 