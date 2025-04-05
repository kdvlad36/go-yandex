# Скрипты деплоя

В этой директории находятся скрипты для деплоя функций в Yandex Cloud.

## Типы скриптов

1. **deploy-with-api.sh** - деплой функции с интеграцией в API Gateway
2. **deploy-without-api.sh** - деплой функции без API Gateway
3. **deploy-with-cron.sh** - деплой функции с cron-триггером

## Подготовка к использованию

Перед использованием скриптов необходимо установить права на исполнение:

```bash
# Из корневой директории проекта
chmod +x core/deploy/deploy-*.sh func/*/deploy*.sh

# Если вы находитесь в директории core/deploy
chmod +x deploy-*.sh ../../func/*/deploy*.sh
```

## Использование

Каждый скрипт принимает параметры через переменные окружения. Обычно функции имеют свои собственные скрипты деплоя, которые уже содержат все необходимые параметры и вызывают соответствующий скрипт из директории core/deploy.

### Запуск через Makefile

```bash
# Деплой с API Gateway
make deploy

# Деплой без API Gateway
make deploy-without-api

# Деплой с cron-триггером
make deploy-with-cron
```

### Прямой запуск скриптов функций

```bash
# Из корневой директории проекта
./func/excel-report/deploy.sh
./func/excel-report/deploy-without-api.sh
./func/excel-report/deploy-with-cron.sh
```

### Запуск универсальных скриптов напрямую

Если вы хотите запустить универсальный скрипт напрямую, вам необходимо задать все обязательные параметры:

```bash
# Пример запуска без API Gateway
FUNCTION_NAME="my-function" \
FUNCTION_DIR="func/my-function" \
FUNCTION_DESCRIPTION="Моя функция" \
./core/deploy/deploy-without-api.sh

# Пример запуска с cron-триггером
FUNCTION_NAME="my-function" \
FUNCTION_DIR="func/my-function" \
FUNCTION_DESCRIPTION="Моя функция" \
CRON_EXPRESSION="0 10 * * 1-5" \
./core/deploy/deploy-with-cron.sh
```

## Параметры

Полный список параметров для каждого скрипта описан в заголовке файла скрипта. 