#!/bin/bash

# Скрипт для сборки и деплоя функции Excel-отчета с интеграцией API Gateway

echo "Начинаем процесс деплоя функции excel-report и интеграции с API Gateway nodejs-dev..."

# Переходим в директорию с функцией
cd "$(dirname "$0")"

# Обновляем зависимости
echo "Обновляем зависимости..."
go mod tidy

# Проверяем ошибки компиляции
echo "Проверяем ошибки компиляции..."
go build -o /tmp/excel-report-test
if [ $? -ne 0 ]; then
    echo "Ошибка компиляции. Деплой прерван."
    exit 1
fi

# Определяем имя функции
FUNCTION_NAME="excel-report-go"

# Проверяем, существует ли функция
echo "Проверяем, существует ли функция..."
if ! yc serverless function get --name="${FUNCTION_NAME}" &>/dev/null; then
    echo "Создаем новую функцию ${FUNCTION_NAME}..."
    yc serverless function create --name="${FUNCTION_NAME}" --description="Excel report generator in Go"
else 
    echo "Функция ${FUNCTION_NAME} уже существует, создаем новую версию..."
fi

# Деплой новой версии функции напрямую из текущего каталога
echo "Деплой функции на Yandex Cloud..."
yc serverless function version create \
  --function-name=${FUNCTION_NAME} \
  --runtime=golang121 \
  --entrypoint=main.Handler \
  --source-path=./ \
  --memory=256m \
  --execution-timeout=30s \
  --environment LOG_LEVEL=info

if [ $? -ne 0 ]; then
    echo "Произошла ошибка при деплое функции. Деплой прерван."
    exit 1
fi

# Получаем ID функции и сервисного аккаунта
echo "Получаем информацию о функции..."
FUNCTION_INFO=$(yc serverless function get --name=${FUNCTION_NAME} --format=json)
FUNCTION_ID=$(echo $FUNCTION_INFO | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "Функция успешно задеплоена! ID функции: ${FUNCTION_ID}"

# Назначаем права на вызов функции для всех пользователей (для API Gateway)
echo "Назначаем права доступа к функции..."
yc serverless function allow-unauthenticated-invoke ${FUNCTION_NAME}

# Определяем API Gateway
API_GATEWAY_NAME="nodejs-dev"

# Проверяем, существует ли API Gateway
echo "Проверяем, существует ли API Gateway ${API_GATEWAY_NAME}..."
if ! yc serverless api-gateway get --name="${API_GATEWAY_NAME}" &>/dev/null; then
    echo "Ошибка: API Gateway ${API_GATEWAY_NAME} не найден"
    echo "Создайте API Gateway или укажите существующий в скрипте"
    exit 1
fi

# Получаем ID сервисного аккаунта API Gateway
echo "Получаем информацию о API Gateway..."
API_GATEWAY_INFO=$(yc serverless api-gateway get --name="${API_GATEWAY_NAME}" --format=json)
SERVICE_ACCOUNT_ID=$(echo $API_GATEWAY_INFO | grep -o '"service_account_id": "[^"]*"' | head -1 | cut -d'"' -f4)

# Подготавливаем спецификацию API Gateway
echo "Подготавливаем спецификацию API Gateway..."
TMP_SPEC_FILE="/tmp/api-gateway-spec-excel.yaml"
cat api-gateway-spec.yaml | \
  sed "s/\${FUNCTION_ID}/${FUNCTION_ID}/g" | \
  sed "s/\${SERVICE_ACCOUNT_ID}/${SERVICE_ACCOUNT_ID}/g" > ${TMP_SPEC_FILE}

# Обновляем API Gateway
echo "Обновляем API Gateway..."
yc serverless api-gateway update \
  --name=${API_GATEWAY_NAME} \
  --spec=${TMP_SPEC_FILE} \
  --description="API Gateway для сервисов nodejs и golang"

if [ $? -eq 0 ]; then
    # Получаем информацию о API Gateway
    API_GATEWAY_INFO=$(yc serverless api-gateway get --name=${API_GATEWAY_NAME} --format=json)
    DOMAIN=$(echo $API_GATEWAY_INFO | grep -o '"domain": "[^"]*"' | cut -d'"' -f4)
    
    echo "Функция успешно интегрирована с API Gateway ${API_GATEWAY_NAME}!"
    echo "URL для доступа к функции: https://${DOMAIN}/excel-report"
    echo "Для тестирования выполните POST-запрос на этот URL с JSON телом {\"projectName\": \"Название проекта\"}"
else
    echo "Произошла ошибка при обновлении API Gateway. Проверьте логи."
fi 