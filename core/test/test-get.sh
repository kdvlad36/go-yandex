#!/bin/bash

# Скрипт для тестирования GET-запроса к функции Excel-отчета

# Получаем ID функции
FUNCTION_NAME="excel-report-go"
echo "Получаем информацию о функции ${FUNCTION_NAME}..."
FUNCTION_INFO=$(yc serverless function get --name=${FUNCTION_NAME} --format=json)
if [ $? -ne 0 ]; then
    echo "Ошибка: функция ${FUNCTION_NAME} не найдена"
    exit 1
fi

FUNCTION_ID=$(echo $FUNCTION_INFO | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)
FUNCTION_URL="https://functions.yandexcloud.net/${FUNCTION_ID}"

# Название проекта для теста
PROJECT_NAME="Тестовый проект GET-запрос"
PROJECT_NAME_ENCODED=$(echo -n "$PROJECT_NAME" | jq -sRr @uri)

echo "Выполняем тестовый GET-запрос к функции excel-report..."
echo "URL функции: $FUNCTION_URL"
echo "Название проекта: $PROJECT_NAME"

# Создаем временный файл для сохранения ответа
TMP_FILE="/tmp/excel-report-get-test.xlsx"

# Выполняем запрос
curl -X GET "$FUNCTION_URL?projectName=$PROJECT_NAME_ENCODED" \
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