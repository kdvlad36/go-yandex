#!/bin/bash

# Определение пути к корневому каталогу проекта
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../../")"
export PROJECT_ROOT

# Параметры для деплоя функции
export FUNCTION_NAME="excel-report"
export FUNCTION_DIR="func/excel-report"
export FUNCTION_DESCRIPTION="Excel отчеты в формате XLSX с использованием секретов"
export RUNTIME="golang121"
export ENTRYPOINT="main.Handler"
export MEMORY="256m"
export TIMEOUT="30s"
export LOG_LEVEL="info"

# Параметры для секретов
export SECRET_NAME="excel-report-secrets"
export SECRET_VERSION_ID="latest"
export SECRET_ENV_PREFIX="SECRET_"

# Запуск основного скрипта деплоя
"$PROJECT_ROOT/core/deploy/deploy-without-api.sh"

# Проверяем существование секрета
echo "=== Проверка существования секрета ==="
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
FUNCTION_ID=$(yc serverless function get --name="${FUNCTION_NAME}" --format json | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

# Обновляем версию функции с секретами
yc serverless function version update \
  --id=$(yc serverless function version list --function-name="${FUNCTION_NAME}" --format=json | jq -r '.[0].id') \
  --secret-id="${SECRET_ID}" \
  --secret-version-id="${SECRET_VERSION_ID}" \
  --secret-environment-variable="${SECRET_ENV_PREFIX}"

echo "=== Деплой функции ${FUNCTION_NAME} с секретами завершен ==="
echo "Доступ к секретам в функции будет через переменные окружения, например:"
echo "SECRET_DB_HOST, SECRET_DB_USER, SECRET_DB_PASSWORD, SECRET_API_KEY" 