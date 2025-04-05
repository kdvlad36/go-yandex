# Excel Report - Генератор отчетов

Функция для генерации Excel отчетов в формате XLSX для проектов в Yandex Cloud Functions.

## Особенности

- Генерация Excel отчетов по проектам
- Поддержка параметров через URL (GET) или JSON (POST)
- Интеграция с API Gateway
- Автоматическая стилизация отчетов

## Зависимости

Функция использует библиотеку `github.com/xuri/excelize/v2` для работы с Excel файлами. 

Установка зависимостей:
```bash
go get github.com/xuri/excelize/v2
```

## Использование

### Локальное тестирование

```bash
go run main.go
```

Затем откройте в браузере: http://localhost:8080/?projectName=МойПроект

### Деплой в Yandex Cloud

```bash
./deploy.sh
```

### Примеры запросов

#### GET-запрос

```
curl -X GET "https://<domain>/excel-report?projectName=МойПроект" --output report.xlsx
```

#### POST-запрос

```
curl -X POST "https://<domain>/excel-report" \
     -H "Content-Type: application/json" \
     -d '{"projectName": "МойПроект"}' \
     --output report.xlsx
```

## Структура отчета

Отчет содержит следующие колонки:
- № (порядковый номер)
- Показатель
- Значение
- Дата

## Настройка

Для изменения параметров деплоя отредактируйте файл `deploy.sh`. 