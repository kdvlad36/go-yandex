#!/bin/bash

# Скрипт с настройками для деплоя контейнера
# Основная логика вынесена в core/deploy/deploy-with-api.sh

# Определение пути к корневому каталогу проекта
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../../")"
CONTAINER_DIR="$(realpath "$SCRIPT_DIR/..")"

# Экспорт параметров для деплоя контейнера
export CONTAINER_NAME="container-name"                  # Имя контейнера
export CONTAINER_DESCRIPTION="Описание контейнера"      # Описание контейнера
export CONTAINER_DIR="$CONTAINER_DIR"
export PROJECT_ROOT="$PROJECT_ROOT"

# Настройки ресурсов контейнера
export CORES="1"           # Количество ядер процессора
export MEMORY="512MB"      # Объем оперативной памяти
export CONCURRENCY="16"    # Максимальное количество одновременных запросов
export TIMEOUT="30s"       # Таймаут выполнения
export LOG_LEVEL="info"    # Уровень логирования

# Путь к спецификации API Gateway
export API_GATEWAY_SPEC="$SCRIPT_DIR/api-gateway-spec.yaml"

# Запуск общего скрипта деплоя
exec "$PROJECT_ROOT/core/deploy/deploy-with-api.sh" "$@" 