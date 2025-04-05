#!/bin/bash

# Определение пути к корневому каталогу проекта
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../")"
export PROJECT_ROOT

# Параметры для деплоя без API Gateway
export FUNCTION_NAME="excel-report"
export FUNCTION_DIR="func/excel-report"
export FUNCTION_DESCRIPTION="Excel отчеты в формате XLSX"
export RUNTIME="golang121"
export ENTRYPOINT="main.Handler"
export MEMORY="256m"
export TIMEOUT="30s"
export LOG_LEVEL="info"

# Запуск основного скрипта деплоя
"$PROJECT_ROOT/core/deploy/deploy-without-api.sh" 