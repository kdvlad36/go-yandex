#!/bin/bash

#
# @deploy - Деплой функции с интеграцией API Gateway
#
# Параметры окружения:
# - FUNCTION_NAME - имя функции [обязательный]
# - FUNCTION_DIR - путь к директории функции [обязательный]
# - API_GATEWAY_NAME - имя API Gateway [обязательный]
# - API_SPEC_PATH - путь к файлу спецификации API Gateway [обязательный]
# - FUNCTION_DESCRIPTION - описание функции
# - API_GATEWAY_DESCRIPTION - описание API Gateway
# - RUNTIME - среда выполнения [по умолчанию: golang121]
# - ENTRYPOINT - точка входа [по умолчанию: main.Handler]
# - MEMORY - объем памяти [по умолчанию: 256m]
# - TIMEOUT - таймаут выполнения [по умолчанию: 30s]
# - LOG_LEVEL - уровень логирования [по умолчанию: info]
# - API_ENDPOINT - эндпоинт API [по умолчанию: совпадает с FUNCTION_NAME]
# - TEST_METHOD - метод для тестирования API [по умолчанию: GET]
# - USE_ROOT_GOMOD - использовать go.mod из корневого каталога [по умолчанию: true]
#

# Проверка обязательных параметров
if [ -z "$FUNCTION_NAME" ] || [ -z "$FUNCTION_DIR" ] || [ -z "$API_GATEWAY_NAME" ] || [ -z "$API_SPEC_PATH" ]; then
    echo "Ошибка: Необходимо указать FUNCTION_NAME, FUNCTION_DIR, API_GATEWAY_NAME и API_SPEC_PATH"
    exit 1
fi

# Установка значений по умолчанию для необязательных параметров
RUNTIME=${RUNTIME:-"golang121"}
ENTRYPOINT=${ENTRYPOINT:-"main.Handler"}
MEMORY=${MEMORY:-"256m"}
TIMEOUT=${TIMEOUT:-"30s"}
LOG_LEVEL=${LOG_LEVEL:-"info"}
API_ENDPOINT=${API_ENDPOINT:-"$FUNCTION_NAME"}
TEST_METHOD=${TEST_METHOD:-"GET"}
FUNCTION_DESCRIPTION=${FUNCTION_DESCRIPTION:-"Функция $FUNCTION_NAME"}
API_GATEWAY_DESCRIPTION=${API_GATEWAY_DESCRIPTION:-"API Gateway для $FUNCTION_NAME"}
USE_ROOT_GOMOD=${USE_ROOT_GOMOD:-"true"}

echo "=== Начало деплоя функции ${FUNCTION_NAME} с интеграцией API Gateway ==="

# Переходим в директорию с функцией
cd "${PROJECT_ROOT}/${FUNCTION_DIR}" || exit 1

# Проверяем наличие go.mod файла и создаем его при необходимости
if [ ! -f "go.mod" ]; then
    if [ "$USE_ROOT_GOMOD" = "true" ] && [ -f "${PROJECT_ROOT}/go.mod" ]; then
        echo "Копируем go.mod из корневого каталога проекта..."
        cp "${PROJECT_ROOT}/go.mod" ./
        if [ -f "${PROJECT_ROOT}/go.sum" ]; then
            cp "${PROJECT_ROOT}/go.sum" ./
        fi
    else
        echo "Файл go.mod не найден. Инициализация модуля..."
        go mod init "github.com/yandex-cloud/${FUNCTION_NAME}"
        if [ $? -ne 0 ]; then
            echo "Ошибка при инициализации go модуля. Деплой прерван."
            exit 1
        fi
    fi
fi

# Обновляем зависимости
echo "1. Обновляем зависимости..."
go mod tidy

# Проверяем наличие необходимых зависимостей
grep -q "github.com/xuri/excelize/v2" go.mod
if [ $? -ne 0 ] && grep -q "excelize" main.go; then
    echo "Добавляем зависимость excelize для работы с Excel..."
    go get github.com/xuri/excelize/v2
    go mod tidy
fi

# Проверяем ошибки компиляции
echo "2. Проверяем ошибки компиляции..."
go build -o /tmp/${FUNCTION_NAME}-test
if [ $? -ne 0 ]; then
    echo "Ошибка компиляции. Деплой прерван."
    exit 1
fi

# Проверяем, существует ли функция
echo "3. Проверяем, существует ли функция..."
if ! yc serverless function get --name="${FUNCTION_NAME}" &>/dev/null; then
    echo "Создаем новую функцию ${FUNCTION_NAME}..."
    yc serverless function create --name="${FUNCTION_NAME}" --description="${FUNCTION_DESCRIPTION}"
else 
    echo "Функция ${FUNCTION_NAME} уже существует, создаем новую версию..."
fi

# Деплой новой версии функции
echo "4. Деплой функции на Yandex Cloud..."
yc serverless function version create \
  --function-name=${FUNCTION_NAME} \
  --runtime=${RUNTIME} \
  --entrypoint=${ENTRYPOINT} \
  --source-path=./ \
  --memory=${MEMORY} \
  --execution-timeout=${TIMEOUT} \
  --environment LOG_LEVEL=${LOG_LEVEL}

if [ $? -ne 0 ]; then
    echo "Произошла ошибка при деплое функции. Деплой прерван."
    exit 1
fi

# Получаем ID функции
echo "5. Получаем информацию о функции..."
FUNCTION_INFO=$(yc serverless function get --name=${FUNCTION_NAME} --format=json)
FUNCTION_ID=$(echo $FUNCTION_INFO | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "Функция успешно задеплоена! ID функции: ${FUNCTION_ID}"

# Назначаем права на вызов функции для всех пользователей (для API Gateway)
echo "6. Назначаем права доступа к функции..."
yc serverless function allow-unauthenticated-invoke ${FUNCTION_NAME}

# Проверяем, существует ли API Gateway
echo "7. Проверяем, существует ли API Gateway ${API_GATEWAY_NAME}..."
if ! yc serverless api-gateway get --name="${API_GATEWAY_NAME}" &>/dev/null; then
    echo "Создаем новый API Gateway ${API_GATEWAY_NAME}..."
    yc serverless api-gateway create --name="${API_GATEWAY_NAME}" --description="${API_GATEWAY_DESCRIPTION}"
fi

# Получаем ID сервисного аккаунта API Gateway
echo "8. Получаем информацию о API Gateway..."
API_GATEWAY_INFO=$(yc serverless api-gateway get --name="${API_GATEWAY_NAME}" --format=json)
SERVICE_ACCOUNT_ID=$(echo $API_GATEWAY_INFO | grep -o '"service_account_id": "[^"]*"' | head -1 | cut -d'"' -f4)

# Подготавливаем спецификацию API Gateway
echo "9. Подготавливаем спецификацию API Gateway..."
TMP_SPEC_FILE="/tmp/api-gateway-spec-${FUNCTION_NAME}.yaml"
cat "${API_SPEC_PATH}" | \
  sed "s/\${FUNCTION_ID}/${FUNCTION_ID}/g" | \
  sed "s/\${SERVICE_ACCOUNT_ID}/${SERVICE_ACCOUNT_ID}/g" > ${TMP_SPEC_FILE}

# Обновляем API Gateway
echo "10. Обновляем API Gateway..."
yc serverless api-gateway update \
  --name=${API_GATEWAY_NAME} \
  --spec=${TMP_SPEC_FILE} \
  --description="${API_GATEWAY_DESCRIPTION}"

if [ $? -eq 0 ]; then
    # Получаем информацию о API Gateway для формирования URL
    API_GATEWAY_INFO=$(yc serverless api-gateway get --name=${API_GATEWAY_NAME} --format=json)
    DOMAIN=$(echo $API_GATEWAY_INFO | grep -o '"domain": "[^"]*"' | cut -d'"' -f4)
    
    echo "=== Деплой функции ${FUNCTION_NAME} с интеграцией API Gateway завершен успешно ==="
    echo "ID функции: ${FUNCTION_ID}"
    echo "API Gateway: ${API_GATEWAY_NAME}"
    echo "URL для доступа к функции: https://${DOMAIN}/${API_ENDPOINT}"
    echo "Для тестирования выполните ${TEST_METHOD}-запрос на этот URL"
else
    echo "Произошла ошибка при обновлении API Gateway. Проверьте логи."
fi

# Удаляем временные файлы go.mod и go.sum если они были скопированы из корня
if [ "$USE_ROOT_GOMOD" = "true" ] && [ -f "${PROJECT_ROOT}/go.mod" ]; then
    rm -f go.mod go.sum
fi 