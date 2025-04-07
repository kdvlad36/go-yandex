#!/bin/bash

# Скрипт для тестирования шаблонов деплоя без реального создания ресурсов
# Добавляет ключ --dry-run к командам yc

# Директория с шаблонами
TEMPLATES_DIR="/Users/mac/projects/go-yandex/func/excel-report/templates"

# Делаем резервные копии шаблонов
echo "Создаем резервные копии шаблонов..."
mkdir -p $TEMPLATES_DIR/backup
cp $TEMPLATES_DIR/deploy-with-cron.sh $TEMPLATES_DIR/backup/
cp $TEMPLATES_DIR/deploy-with-ymq.sh $TEMPLATES_DIR/backup/
cp $TEMPLATES_DIR/deploy-with-secrets.sh $TEMPLATES_DIR/backup/
cp $TEMPLATES_DIR/deploy-full.sh $TEMPLATES_DIR/backup/

# Модифицируем шаблоны для dry-run
echo "Модифицируем шаблоны для dry-run тестирования..."
sed -i.bak 's/yc serverless function/yc --dry-run serverless function/g' $TEMPLATES_DIR/deploy-with-cron.sh
sed -i.bak 's/yc serverless trigger/yc --dry-run serverless trigger/g' $TEMPLATES_DIR/deploy-with-cron.sh

sed -i.bak 's/yc serverless function/yc --dry-run serverless function/g' $TEMPLATES_DIR/deploy-with-ymq.sh
sed -i.bak 's/yc serverless trigger/yc --dry-run serverless trigger/g' $TEMPLATES_DIR/deploy-with-ymq.sh
sed -i.bak 's/yc message-queue/yc --dry-run message-queue/g' $TEMPLATES_DIR/deploy-with-ymq.sh

sed -i.bak 's/yc serverless function/yc --dry-run serverless function/g' $TEMPLATES_DIR/deploy-with-secrets.sh
sed -i.bak 's/yc lockbox/yc --dry-run lockbox/g' $TEMPLATES_DIR/deploy-with-secrets.sh

sed -i.bak 's/yc serverless function/yc --dry-run serverless function/g' $TEMPLATES_DIR/deploy-full.sh
sed -i.bak 's/yc serverless trigger/yc --dry-run serverless trigger/g' $TEMPLATES_DIR/deploy-full.sh
sed -i.bak 's/yc message-queue/yc --dry-run message-queue/g' $TEMPLATES_DIR/deploy-full.sh
sed -i.bak 's/yc lockbox/yc --dry-run lockbox/g' $TEMPLATES_DIR/deploy-full.sh

# Тестируем каждый шаблон
echo -e "\n=== Тестирование deploy-with-cron.sh ==="
$TEMPLATES_DIR/deploy-with-cron.sh

echo -e "\n=== Тестирование deploy-with-ymq.sh ==="
$TEMPLATES_DIR/deploy-with-ymq.sh

echo -e "\n=== Тестирование deploy-with-secrets.sh ==="
$TEMPLATES_DIR/deploy-with-secrets.sh

echo -e "\n=== Тестирование deploy-full.sh ==="
$TEMPLATES_DIR/deploy-full.sh

# Восстанавливаем оригинальные файлы
echo -e "\n=== Восстанавливаем оригинальные файлы ==="
cp $TEMPLATES_DIR/backup/deploy-with-cron.sh $TEMPLATES_DIR/
cp $TEMPLATES_DIR/backup/deploy-with-ymq.sh $TEMPLATES_DIR/
cp $TEMPLATES_DIR/backup/deploy-with-secrets.sh $TEMPLATES_DIR/
cp $TEMPLATES_DIR/backup/deploy-full.sh $TEMPLATES_DIR/

# Удаляем временные файлы
rm -f $TEMPLATES_DIR/*.bak
rm -rf $TEMPLATES_DIR/backup

echo -e "\n=== Тестирование завершено ===" 