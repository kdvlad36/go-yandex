#!/bin/bash

# Универсальный скрипт для деплоя контейнеров в Yandex Cloud Serverless Containers с API Gateway

# Парсинг аргументов командной строки
SKIP_BUILD=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    *)
      echo "Неизвестный параметр: $1"
      echo "Доступные параметры:"
      echo "  --skip-build  - пропустить сборку и публикацию образа, использовать существующий"
      exit 1
      ;;
  esac
done

# Проверка наличия необходимых переменных окружения
if [ -z "$CONTAINER_NAME" ] || [ -z "$CONTAINER_DIR" ]; then
  echo "Ошибка: не указаны обязательные переменные CONTAINER_NAME и CONTAINER_DIR"
  exit 1
fi

# Определение пути к корневому каталогу проекта, если не задан
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(realpath "${CONTAINER_DIR}/../..")"
fi

# Установка значений по умолчанию
CONTAINER_DESCRIPTION="${CONTAINER_DESCRIPTION:-"Serverless Container $CONTAINER_NAME"}"
MEMORY="${MEMORY:-"512MB"}"
CORES="${CORES:-"1"}"
CONCURRENCY="${CONCURRENCY:-"16"}"
TIMEOUT="${TIMEOUT:-"30s"}"
LOG_LEVEL="${LOG_LEVEL:-"info"}"

# Получение ID сервисного аккаунта
if [ -f "/tmp/selected_service_account_id" ]; then
  SERVICE_ACCOUNT_ID=$(cat /tmp/selected_service_account_id)
  echo "Используется выбранный сервисный аккаунт с ID: $SERVICE_ACCOUNT_ID"
else
  echo "Ошибка: Не найден ID сервисного аккаунта"
  echo "Пожалуйста, запустите 'make check-service-account' перед деплоем"
  exit 1
fi

# Проверка аутентификации в Container Registry
echo "=== Проверка аутентификации в Container Registry ==="
if ! yc container registry list &>/dev/null; then
  echo "Ошибка аутентификации в Container Registry"
  echo "Запустите 'yc init' для настройки аутентификации"
  exit 1
fi

# Определение переменных окружения для Container Registry
YC_REGISTRY_ID=$(yc container registry get default --format json 2>/dev/null | jq -r .id)
if [ -z "$YC_REGISTRY_ID" ] || [ "$YC_REGISTRY_ID" == "null" ]; then
  echo "Создаем реестр контейнеров по умолчанию..."
  YC_REGISTRY_ID=$(yc container registry create --name default --format json | jq -r .id)
  
  if [ -z "$YC_REGISTRY_ID" ] || [ "$YC_REGISTRY_ID" == "null" ]; then
    echo "Ошибка: Не удалось создать реестр контейнеров"
    exit 1
  fi
fi

echo "ID реестра контейнеров: $YC_REGISTRY_ID"
CONTAINER_IMAGE_TAG="cr.yandex/$YC_REGISTRY_ID/$CONTAINER_NAME:latest"

# Проверка если образ существует в реестре
IMAGE_EXISTS=false
if yc container image list --repository-name "cr.yandex/${YC_REGISTRY_ID}/${CONTAINER_NAME}" --format json 2>/dev/null | jq -e '.[] | select(.tags[] | contains("latest"))' &>/dev/null; then
  IMAGE_EXISTS=true
  echo "Найден существующий образ в реестре: $CONTAINER_IMAGE_TAG"
fi

# Процесс сборки и публикации образа
if [ "$SKIP_BUILD" = false ]; then
  # Проверка работы Docker
  echo "=== Проверка работы Docker ==="
  if ! docker info &>/dev/null; then
    # Пытаемся запустить Docker автоматически
    if [ -f "$PROJECT_ROOT/tools/check-docker.sh" ]; then
      echo "Попытка автоматического запуска Docker..."
      if ! "$PROJECT_ROOT/tools/check-docker.sh"; then
        if [ "$IMAGE_EXISTS" = true ]; then
          echo "Не удалось запустить Docker, но найден существующий образ. Пропускаем сборку."
          SKIP_BUILD=true
        else
          echo "Ошибка: Docker не удалось запустить, а образ в реестре не найден"
          echo "Сборка невозможна. Попробуйте запустить Docker вручную или используйте --skip-build, если образ уже существует"
          exit 1
        fi
      fi
    else
      if [ "$IMAGE_EXISTS" = true ]; then
        echo "Предупреждение: Docker не запущен. Используем существующий образ из реестра."
        SKIP_BUILD=true
      else
        echo "Ошибка: Docker не запущен или недоступен, а образ в реестре не найден"
        echo "Пожалуйста, запустите Docker и повторите попытку или используйте параметр --skip-build, если образ уже существует"
        exit 1
      fi
    fi
  fi
fi

if [ "$SKIP_BUILD" = false ]; then
  # Аутентификация Docker в Container Registry
  echo "=== Аутентификация Docker в Container Registry ==="
  if ! yc container registry configure-docker; then
    echo "Ошибка при настройке аутентификации Docker в Container Registry"
    exit 1
  fi

  # Сборка контейнера
  echo "=== Сборка контейнера ==="

  # Переходим в корень проекта для сборки
  cd "$PROJECT_ROOT" || exit 1

  # Проверяем наличие Dockerfile
  if [ ! -f "$CONTAINER_DIR/Dockerfile" ]; then
    echo "Ошибка: Dockerfile не найден в директории $CONTAINER_DIR"
    exit 1
  fi

  # Собираем из корня проекта с указанием пути к Dockerfile
  if ! docker build -t "$CONTAINER_IMAGE_TAG" -f "$CONTAINER_DIR/Dockerfile" .; then
    echo "Ошибка при сборке образа Docker"
    exit 1
  fi

  # Публикация образа в Container Registry
  echo "=== Публикация образа в Container Registry ==="
  if ! docker push "$CONTAINER_IMAGE_TAG"; then
    echo "Ошибка при публикации образа в Container Registry"
    exit 1
  fi
else
  echo "=== Пропуск сборки и публикации образа ==="
  
  # Проверка существования образа, если мы пропускаем сборку
  if [ "$IMAGE_EXISTS" = false ]; then
    echo "Ошибка: Образ $CONTAINER_IMAGE_TAG не найден в реестре"
    echo "Необходимо построить и опубликовать образ хотя бы один раз перед использованием --skip-build"
    exit 1
  fi
fi

# Создание или обновление контейнера в Serverless Containers
echo "=== Создание контейнера в Serverless Containers ==="
CONTAINER_EXISTS=$(yc serverless container list --format json | jq -r ".[] | select(.name==\"$CONTAINER_NAME\") | .id")

if [ -z "$CONTAINER_EXISTS" ]; then
  echo "Создаем контейнер $CONTAINER_NAME..."
  CONTAINER_ID=$(yc serverless container create \
    --name="$CONTAINER_NAME" \
    --description="$CONTAINER_DESCRIPTION" \
    --format json | jq -r .id)
  
  if [ -z "$CONTAINER_ID" ] || [ "$CONTAINER_ID" == "null" ]; then
    echo "Ошибка при создании контейнера в Serverless Containers"
    exit 1
  fi
else
  echo "Контейнер $CONTAINER_NAME уже существует, обновляем..."
  CONTAINER_ID=$CONTAINER_EXISTS
fi

echo "ID контейнера: $CONTAINER_ID"

# Создание ревизии контейнера
echo "=== Создание ревизии контейнера ==="
REVISION_OUTPUT=$(yc serverless container revision deploy \
  --container-id="$CONTAINER_ID" \
  --image="$CONTAINER_IMAGE_TAG" \
  --cores="$CORES" \
  --memory="$MEMORY" \
  --concurrency="$CONCURRENCY" \
  --execution-timeout="$TIMEOUT" \
  --service-account-id="$SERVICE_ACCOUNT_ID" \
  --format json 2>&1)

# Проверка на ошибки в выводе команды
if echo "$REVISION_OUTPUT" | grep -q "ERROR"; then
  echo "Ошибка при создании ревизии контейнера:"
  echo "$REVISION_OUTPUT"
  exit 1
fi

# Сохраняем вывод для отладки
echo "$REVISION_OUTPUT" > /tmp/revision_output.json

# Проверяем, является ли вывод валидным JSON
if ! jq -e . < /tmp/revision_output.json &>/dev/null; then
  echo "Вывод команды не является валидным JSON. Вывод:"
  cat /tmp/revision_output.json
  
  # Попытаемся найти ID ревизии в выводе напрямую
  REVISION_ID=$(echo "$REVISION_OUTPUT" | grep -o '"id": "[^"]*"' | grep -o '[^"]*"$' | tr -d '"')
  
  if [ -z "$REVISION_ID" ]; then
    echo "Не удалось извлечь ID ревизии из вывода."
    exit 1
  fi
  
  echo "Извлечен ID ревизии из текста: $REVISION_ID"
else
  # Парсинг JSON для получения ID
  REVISION_ID=$(jq -r .id < /tmp/revision_output.json)
  
  if [ -z "$REVISION_ID" ] || [ "$REVISION_ID" == "null" ]; then
    echo "Ошибка: Не удалось получить ID ревизии из JSON"
    exit 1
  fi
fi

# Удаляем временный файл
rm -f /tmp/revision_output.json

echo "ID ревизии: $REVISION_ID"

# Ждем активации ревизии с таймаутом
echo "=== Ожидание активации ревизии ==="
MAX_ATTEMPTS=12  # Максимальное количество попыток (1 минута при sleep 5)
ATTEMPTS=0

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  REVISION_STATUS=$(yc serverless container revision get --id="$REVISION_ID" --format json 2>/dev/null | jq -r .status)
  
  if [ "$REVISION_STATUS" == "ACTIVE" ]; then
    echo "Ревизия активирована успешно!"
    break
  elif [ "$REVISION_STATUS" == "ERROR" ]; then
    echo "Ошибка активации ревизии"
    exit 1
  fi
  
  echo "Статус ревизии: $REVISION_STATUS, ожидаем... ($((ATTEMPTS+1))/$MAX_ATTEMPTS)"
  sleep 5
  ATTEMPTS=$((ATTEMPTS+1))
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
  echo "Превышено время ожидания активации ревизии"
  exit 1
fi

# Проверяем наличие файла спецификации API Gateway
API_GATEWAY_SPEC="${API_GATEWAY_SPEC:-"$CONTAINER_DIR/deploy/api-gateway-spec.yaml"}"
if [ ! -f "$API_GATEWAY_SPEC" ]; then
  echo "Ошибка: файл спецификации API Gateway не найден: $API_GATEWAY_SPEC"
  exit 1
fi

# Создание или обновление API Gateway
echo "=== Создание или обновление API Gateway ==="
API_GATEWAY_NAME="$CONTAINER_NAME-api"
API_GATEWAY_EXISTS=$(yc serverless api-gateway get --name="$API_GATEWAY_NAME" 2>/dev/null | grep -c "id:" || echo "0")

# Подготовка спецификации API Gateway
TEMP_SPEC_FILE="/tmp/api-gateway-spec-$$.yaml"

# Замена переменных в спецификации
sed "s/\${CONTAINER_ID}/$CONTAINER_ID/g" "$API_GATEWAY_SPEC" |
  sed "s/\${SERVICE_ACCOUNT_ID}/$SERVICE_ACCOUNT_ID/g" > "$TEMP_SPEC_FILE"

API_GATEWAY_CREATED=false
if [ "$API_GATEWAY_EXISTS" -eq 0 ]; then
  echo "Создаем API Gateway $API_GATEWAY_NAME..."
  if API_GATEWAY_OUTPUT=$(yc serverless api-gateway create \
    --name="$API_GATEWAY_NAME" \
    --description="API Gateway для $CONTAINER_NAME" \
    --spec="$TEMP_SPEC_FILE" \
    --format json 2>&1); then
    
    # Пытаемся извлечь ID из успешного вывода
    if echo "$API_GATEWAY_OUTPUT" | jq -e . &>/dev/null; then
      API_GATEWAY_ID=$(echo "$API_GATEWAY_OUTPUT" | jq -r .id)
      API_GATEWAY_CREATED=true
    else
      echo "Предупреждение: Не удалось получить валидный JSON после создания API Gateway"
      echo "$API_GATEWAY_OUTPUT"
    fi
  else
    echo "Предупреждение: Не удалось создать API Gateway. Будет использован прямой URL контейнера."
    echo "$API_GATEWAY_OUTPUT"
  fi
else
  echo "API Gateway $API_GATEWAY_NAME уже существует, обновляем..."
  if API_GATEWAY_INFO=$(yc serverless api-gateway get --name="$API_GATEWAY_NAME" --format json 2>/dev/null); then
    API_GATEWAY_ID=$(echo "$API_GATEWAY_INFO" | jq -r .id)
    
    if API_GATEWAY_UPDATE_OUTPUT=$(yc serverless api-gateway update \
      --id="$API_GATEWAY_ID" \
      --spec="$TEMP_SPEC_FILE" 2>&1); then
      
      API_GATEWAY_CREATED=true
    else
      echo "Предупреждение: Не удалось обновить API Gateway. Будет использован прямой URL контейнера."
      echo "$API_GATEWAY_UPDATE_OUTPUT"
    fi
  else
    echo "Предупреждение: Не удалось получить информацию о существующем API Gateway"
  fi
fi

# Удаляем временную спецификацию
rm -f "$TEMP_SPEC_FILE"

# Получение URL для доступа
if [ "$API_GATEWAY_CREATED" = true ] && [ -n "$API_GATEWAY_ID" ]; then
  echo "API Gateway успешно создан/обновлен."
  # Получаем домен API Gateway
  if API_GATEWAY_INFO=$(yc serverless api-gateway get --id="$API_GATEWAY_ID" --format json 2>/dev/null); then
    API_GATEWAY_DOMAIN=$(echo "$API_GATEWAY_INFO" | jq -r .domain)
    
    echo "=== Деплой завершен ==="
    echo "ID контейнера: $CONTAINER_ID"
    echo "ID API Gateway: $API_GATEWAY_ID"
    echo "URL API Gateway: https://$API_GATEWAY_DOMAIN"
    echo "Пример запроса: https://$API_GATEWAY_DOMAIN/hello?name=Иван"
  else
    echo "Предупреждение: Не удалось получить домен API Gateway"
  fi
else
  # Если API Gateway не создался, получаем прямую ссылку на контейнер
  echo "Получение прямого URL контейнера..."
  CONTAINER_INFO=$(yc serverless container get --id="$CONTAINER_ID" --format json)
  CONTAINER_URL=$(echo "$CONTAINER_INFO" | jq -r .url 2>/dev/null || echo "URL не найден")
  
  echo "=== Деплой завершен ==="
  echo "ID контейнера: $CONTAINER_ID"
  echo "ID ревизии: $REVISION_ID"
  echo "URL для прямого вызова контейнера: $CONTAINER_URL"
  echo "Пример запроса: ${CONTAINER_URL}hello?name=Иван"
fi 