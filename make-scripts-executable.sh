#!/bin/bash

# Скрипт для установки прав на исполнение всех скриптов деплоя

echo "Установка прав на исполнение для скриптов деплоя..."

# Скрипты в директории core/deploy
chmod +x core/deploy/deploy-*.sh
echo "✅ Права установлены для core/deploy/deploy-*.sh"

# Скрипты в директориях функций
chmod +x func/*/deploy*.sh
echo "✅ Права установлены для func/*/deploy*.sh"

# Сам этот скрипт
chmod +x make-scripts-executable.sh
echo "✅ Права установлены для make-scripts-executable.sh"

echo "Готово! Все скрипты теперь исполняемые."
echo "Для деплоя используйте команды:"
echo "  make deploy             - деплой с API Gateway"
echo "  make deploy-without-api - деплой без API Gateway"
echo "  make deploy-with-cron   - деплой с cron-триггером" 