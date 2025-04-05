#!/bin/bash

# Проверка на рекурсивный вызов
if [ -n "$DEPLOY_RUNNING" ]; then
    echo "Ошибка: обнаружен рекурсивный вызов скрипта деплоя"
    exit 1
fi
export DEPLOY_RUNNING=1

# Параметры функции для деплоя
FUNCTION_NAME="hello-world"
FUNCTION_DIR="func/hello-world"
API_GATEWAY_NAME="nodejs-dev"
FUNCTION_DESCRIPTION="Простая демонстрационная функция приветствия"
RUNTIME="golang121"
ENTRYPOINT="main.Handler"
SOURCE_PATH="."
MEMORY="128m"
TIMEOUT="5s"
LOG_LEVEL="info"
API_SPEC_PATH="api-gateway-spec.yaml"
API_ENDPOINT="hello"
TEST_METHOD="GET"
API_GATEWAY_DESCRIPTION="API Gateway для демонстрационных сервисов"

# Путь к корневому каталогу проекта (относительно текущего скрипта)
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../")"

# Экспорт переменных для использования в основном скрипте деплоя
export FUNCTION_NAME
export FUNCTION_DIR
export API_GATEWAY_NAME
export FUNCTION_DESCRIPTION
export RUNTIME
export ENTRYPOINT
export SOURCE_PATH
export MEMORY
export TIMEOUT
export LOG_LEVEL
export API_SPEC_PATH
export API_ENDPOINT
export TEST_METHOD
export API_GATEWAY_DESCRIPTION

echo "Запуск деплоя функции ${FUNCTION_NAME} с интеграцией в API Gateway ${API_GATEWAY_NAME}..."

# Запуск основного скрипта деплоя
"$PROJECT_ROOT/core/deploy/deploy-with-api.sh" "$0" 