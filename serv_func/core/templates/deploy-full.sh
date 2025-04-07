#!/bin/bash

# Определение пути к корневому каталогу проекта
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../../")"
export PROJECT_ROOT

# Параметры для деплоя функции
export FUNCTION_NAME="excel-report"
export FUNCTION_DIR="func/excel-report"
export FUNCTION_DESCRIPTION="Excel отчеты в формате XLSX - полный деплой (крон, YMQ, секреты)"
export RUNTIME="golang121"
export ENTRYPOINT="main.Handler"
export MEMORY="256m"
export TIMEOUT="30s"
export LOG_LEVEL="info"

# Параметры для крон-триггера
export CRON_EXPRESSION="0 9 * * 1-5"  # В 9:00 по будням
export CRON_TIMEZONE="Europe/Moscow"

# Параметры для YMQ триггера
export YMQ_QUEUE_NAME="excel-report-queue"
export SERVICE_ACCOUNT_ID="${SERVICE_ACCOUNT_ID:-"$(yc iam service-account get --name default --format json | jq -r .id)"}"

# Параметры для секретов
export SECRET_NAME="excel-report-secrets"
export SECRET_VERSION_ID="latest"
export SECRET_ENV_PREFIX="SECRET_"

# Запуск основного скрипта деплоя
echo "=== Деплой базовой функции ==="
"$PROJECT_ROOT/core/deploy/deploy-without-api.sh"

# Получаем ID функции
FUNCTION_ID=$(yc serverless function get --name="${FUNCTION_NAME}" --format json | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

# Настройка CRON триггера
echo "=== Настройка CRON триггера ==="
TRIGGER_EXISTS=$(yc serverless trigger list | grep "${FUNCTION_NAME}-cron-trigger" | wc -l)
if [ "$TRIGGER_EXISTS" -gt "0" ]; then
  echo "Триггер CRON уже существует, удаляем..."
  yc serverless trigger delete --name="${FUNCTION_NAME}-cron-trigger"
fi

# Создаем CRON триггер
yc serverless trigger create cron \
  --name="${FUNCTION_NAME}-cron-trigger" \
  --cron-expression="${CRON_EXPRESSION}" \
  --timezone="${CRON_TIMEZONE}" \
  --invoke-function-id="${FUNCTION_ID}" \
  --invoke-function-service-account-id="${SERVICE_ACCOUNT_ID}"

# Настройка YMQ триггера
echo "=== Настройка YMQ триггера ==="
# Проверяем существование очереди YMQ
QUEUE_EXISTS=$(yc message-queue queue list | grep "${YMQ_QUEUE_NAME}" | wc -l)
if [ "$QUEUE_EXISTS" -eq "0" ]; then
  echo "Создаем очередь YMQ ${YMQ_QUEUE_NAME}..."
  yc message-queue queue create --name="${YMQ_QUEUE_NAME}" --visibility-timeout=30s --redrive-policy="{\"deadLetterQueueName\":\"${YMQ_QUEUE_NAME}-dlq\",\"maxReceiveCount\":3}"
  
  # Создаем очередь для недоставленных сообщений (dead-letter queue)
  yc message-queue queue create --name="${YMQ_QUEUE_NAME}-dlq"
fi

# Проверяем существование YMQ триггера и удаляем его при необходимости
TRIGGER_EXISTS=$(yc serverless trigger list | grep "${FUNCTION_NAME}-ymq-trigger" | wc -l)
if [ "$TRIGGER_EXISTS" -gt "0" ]; then
  echo "Триггер YMQ уже существует, удаляем..."
  yc serverless trigger delete --name="${FUNCTION_NAME}-ymq-trigger"
fi

# Создаем YMQ триггер
yc serverless trigger create message-queue \
  --name="${FUNCTION_NAME}-ymq-trigger" \
  --queue="${YMQ_QUEUE_NAME}" \
  --invoke-function-id="${FUNCTION_ID}" \
  --invoke-function-service-account-id="${SERVICE_ACCOUNT_ID}" \
  --batch-size=1 \
  --batch-cutoff=0

# Настройка секретов
echo "=== Настройка секретов ==="
# Проверяем существование секрета
SECRET_EXISTS=$(yc lockbox secret list | grep "${SECRET_NAME}" | wc -l)
if [ "$SECRET_EXISTS" -eq "0" ]; then
  echo "Создаем секрет ${SECRET_NAME}..."
  
  # Создаем временный файл с секретами
  TMP_SECRET_FILE=$(mktemp)
  cat > "$TMP_SECRET_FILE" << EOF
{
  "DB_HOST": "db-host.example.com",
  "DB_USER": "db_user",
  "DB_PASSWORD": "secure_password",
  "API_KEY": "your_api_key_here"
}
EOF

  # Создаем секрет
  yc lockbox secret create \
    --name="${SECRET_NAME}" \
    --description="Секреты для функции ${FUNCTION_NAME}" \
    --payload-file="$TMP_SECRET_FILE"
    
  # Удаляем временный файл
  rm "$TMP_SECRET_FILE"
else
  echo "Секрет ${SECRET_NAME} уже существует"
fi

# Получаем ID секрета
SECRET_ID=$(yc lockbox secret get --name="${SECRET_NAME}" --format json | jq -r .id)

# Привязка секрета к функции
echo "=== Привязка секрета к функции ==="
# Обновляем версию функции с секретами
yc serverless function version update \
  --id=$(yc serverless function version list --function-name="${FUNCTION_NAME}" --format=json | jq -r '.[0].id') \
  --secret-id="${SECRET_ID}" \
  --secret-version-id="${SECRET_VERSION_ID}" \
  --secret-environment-variable="${SECRET_ENV_PREFIX}"

echo "=== Полный деплой функции ${FUNCTION_NAME} завершен ==="
echo "✅ CRON триггер настроен на: ${CRON_EXPRESSION} (${CRON_TIMEZONE})"
echo "✅ YMQ триггер настроен на очередь: ${YMQ_QUEUE_NAME}"
echo "✅ Секреты доступны через префикс: ${SECRET_ENV_PREFIX}"
echo ""
echo "📝 Для тестирования YMQ триггера отправьте сообщение в очередь:"
echo "yc message-queue message send --queue-name=${YMQ_QUEUE_NAME} --data='{\"projectName\":\"Тестовый проект\"}'" 