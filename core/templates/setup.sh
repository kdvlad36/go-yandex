#!/bin/bash

echo "Установка прав на выполнение для шаблонов деплоя..."
chmod +x deploy-with-cron.sh deploy-with-ymq.sh deploy-with-secrets.sh deploy-full.sh

echo "Готово! Доступные шаблоны:"
echo "- deploy-with-cron.sh (Деплой с крон-триггером)"
echo "- deploy-with-ymq.sh (Деплой с триггером из YMQ)"
echo "- deploy-with-secrets.sh (Деплой с секретами)"
echo "- deploy-full.sh (Полный деплой с кроном, YMQ и секретами)"
echo ""
echo "Подробности смотрите в README.md"

# Выводим инструкции из README.md
echo ""
echo "====== ИНСТРУКЦИИ ======"
echo ""
cat README.md 