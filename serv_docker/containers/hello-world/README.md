# Hello World - демонстрационный контейнер

Простой контейнер с API на Gin для демонстрации работы Yandex Cloud Serverless Containers.

## Возможности

- Обработка GET-запросов с параметром `name`
- Обработка POST-запросов с JSON-телом, содержащим поле `name`
- Возвращает приветственное сообщение в формате JSON

## Локальное тестирование

Для локального запуска контейнера выполните:

```bash
# Сборка образа
docker build -t hello-world-container .

# Запуск контейнера
docker run -p 8080:8080 hello-world-container
```

## Примеры запросов

### GET-запрос

```bash
curl "http://localhost:8080/hello?name=Иван"
```

### POST-запрос

```bash
curl -X POST http://localhost:8080/hello \
  -H "Content-Type: application/json" \
  -d '{"name":"Иван"}'
```

### Проверка статуса

```bash
curl http://localhost:8080/
```

## Деплой в Yandex Cloud

Для деплоя контейнера выполните:

```bash
cd deploy/
./deploy.sh
```

После деплоя вы получите URL для доступа к развернутому контейнеру через API Gateway. 