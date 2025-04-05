#!/bin/bash

#
# @deploy - Деплой функции без интеграции API Gateway
#
# Параметры окружения:
# - FUNCTION_NAME - имя функции [обязательный]
# - FUNCTION_DIR - путь к директории функции [обязательный]
# - FUNCTION_DESCRIPTION - описание функции
# - RUNTIME - среда выполнения [по умолчанию: golang121]
# - ENTRYPOINT - точка входа [по умолчанию: main.Handler]
# - MEMORY - объем памяти [по умолчанию: 256m]
# - TIMEOUT - таймаут выполнения [по умолчанию: 30s]
# - LOG_LEVEL - уровень логирования [по умолчанию: info]
# - USE_ROOT_GOMOD - использовать go.mod из корневого каталога [по умолчанию: true]
#

# Проверка обязательных параметров
if [ -z "$FUNCTION_NAME" ] || [ -z "$FUNCTION_DIR" ]; then
    echo "Ошибка: Необходимо указать FUNCTION_NAME и FUNCTION_DIR"
    exit 1
fi

# Установка значений по умолчанию для необязательных параметров
RUNTIME=${RUNTIME:-"golang121"}
ENTRYPOINT=${ENTRYPOINT:-"main.Handler"}
MEMORY=${MEMORY:-"256m"}
TIMEOUT=${TIMEOUT:-"30s"}
LOG_LEVEL=${LOG_LEVEL:-"info"}
FUNCTION_DESCRIPTION=${FUNCTION_DESCRIPTION:-"Функция $FUNCTION_NAME"}
USE_ROOT_GOMOD=${USE_ROOT_GOMOD:-"true"}

echo "=== Начало деплоя функции ${FUNCTION_NAME} без интеграции API Gateway ==="

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
FUNCTION_URL=$(echo $FUNCTION_INFO | grep -o '"http_invoker": "[^"]*"' | cut -d'"' -f4)

echo "=== Деплой функции ${FUNCTION_NAME} завершен успешно ==="
echo "ID функции: ${FUNCTION_ID}"
echo "URL для вызова функции: ${FUNCTION_URL}"

# Удаляем временные файлы go.mod и go.sum если они были скопированы из корня
if [ "$USE_ROOT_GOMOD" = "true" ] && [ -f "${PROJECT_ROOT}/go.mod" ]; then
    rm -f go.mod go.sum
fi 