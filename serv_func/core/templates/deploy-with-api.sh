#!/bin/bash

# Проверка на рекурсивный вызов
if [ -n "$DEPLOY_RUNNING" ]; then
    echo "Ошибка: обнаружен рекурсивный вызов скрипта деплоя"
    exit 1
fi
export DEPLOY_RUNNING=1

# Определение пути к корневому каталогу проекта
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../../")"
export PROJECT_ROOT

# Параметры для деплоя с API Gateway
export FUNCTION_NAME="excel-report"
export FUNCTION_DIR="func/excel-report"
export API_GATEWAY_NAME="nodejs-dev"
export FUNCTION_DESCRIPTION="Excel отчеты в формате XLSX"
export RUNTIME="golang121"
export ENTRYPOINT="main.Handler"
export MEMORY="256m"
export TIMEOUT="30s"
export LOG_LEVEL="info"
export API_SPEC_PATH="api-gateway-spec.yaml"
export API_ENDPOINT="excel-report"
export TEST_METHOD="POST"
export API_GATEWAY_DESCRIPTION="API Gateway для сервисов отчетности"
export USE_ROOT_GOMOD="true"

echo "Запуск деплоя функции ${FUNCTION_NAME} с интеграцией в API Gateway ${API_GATEWAY_NAME}..."

# Удаляем существующие go.mod и go.sum если они есть в директории функции
if [ -f "${PROJECT_ROOT}/${FUNCTION_DIR}/go.mod" ]; then
    echo "Удаляем существующие go.mod и go.sum из директории функции..."
    rm -f "${PROJECT_ROOT}/${FUNCTION_DIR}/go.mod" "${PROJECT_ROOT}/${FUNCTION_DIR}/go.sum"
fi

# Запуск основного скрипта деплоя
"$PROJECT_ROOT/core/deploy/deploy-with-api.sh"