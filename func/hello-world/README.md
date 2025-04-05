# Hello World - Демонстрационная функция

Простая функция для демонстрации работы с Yandex Cloud Functions и API Gateway.

## Особенности

- Простая демонстрационная функция "Hello World"
- Поддержка параметров через URL или JSON
- Интеграция с API Gateway
- Готовый скрипт деплоя

## Использование

### Локальное тестирование

```bash
go run main.go
```

Затем откройте в браузере: http://localhost:8080/?name=Иван

### Деплой в Yandex Cloud

```bash
./deploy.sh
```

### Примеры запросов

#### GET-запрос

```
curl -X GET "https://<domain>/hello?name=Иван"
```

#### POST-запрос

```
curl -X POST "https://<domain>/hello" \
     -H "Content-Type: application/json" \
     -d '{"name": "Иван"}'
```

## Структура ответа

```json
{
  "message": "Привет, Иван!"
}
``` 