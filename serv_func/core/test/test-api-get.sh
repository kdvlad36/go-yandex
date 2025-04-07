#!/bin/bash

# Скрипт для тестирования функции Excel-отчета через API Gateway с GET-запросом

# Определяем API Gateway
API_GATEWAY_NAME="nodejs-dev"

# Получаем информацию о API Gateway
echo "Получаем информацию о API Gateway ${API_GATEWAY_NAME}..."
API_GATEWAY_INFO=$(yc serverless api-gateway get --name=${API_GATEWAY_NAME} --format=json)
if [ $? -ne 0 ]; then
    echo "Ошибка: API Gateway ${API_GATEWAY_NAME} не найден"
    exit 1
fi

DOMAIN=$(echo $API_GATEWAY_INFO | grep -o '"domain": "[^"]*"' | cut -d'"' -f4)

# Название проекта для теста
PROJECT_NAME="Тестовый проект GET через API Gateway"
PROJECT_NAME_ENCODED=$(echo -n "$PROJECT_NAME" | jq -sRr @uri)

API_URL="https://${DOMAIN}/excel-report?projectName=${PROJECT_NAME_ENCODED}"

echo "Выполняем тестовый GET-запрос к API Gateway..."
echo "URL API: $API_URL"
echo "Название проекта: $PROJECT_NAME"

# Создаем временный файл для сохранения ответа
TMP_FILE="/tmp/excel-report-api-get-test.xlsx"

# Выполняем запрос
curl -X GET "$API_URL" \
  --output "$TMP_FILE"

# Проверяем результат
if [ $? -eq 0 ] && [ -f "$TMP_FILE" ] && [ -s "$TMP_FILE" ]; then
    echo "Тест успешен! Отчет сохранен в $TMP_FILE"
    echo "Открываем файл..."
    open "$TMP_FILE" || xdg-open "$TMP_FILE" || echo "Отчет не удалось открыть автоматически, он сохранен в $TMP_FILE"
else
    echo "Произошла ошибка при тестировании. Ответ API:"
    cat "$TMP_FILE"
fi 