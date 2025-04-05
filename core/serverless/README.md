# Serverless для Yandex Cloud Functions

Фреймворк для удобного управления функциями Yandex Cloud. Аналог serverless-framework для Yandex Cloud с поддержкой Go.

## Особенности

* Общий код для всех функций в одном репозитории (монорепозиторий)
* Автоматическая генерация файлов функций (main.go, обработчики)
* Поддержка интеграции с API Gateway
* Использование общего файла go.mod для всех функций
* Удобный деплой функций через CLI

## Структура проекта

```
├── core/                       # Ядро проекта
│   ├── deploy/                 # Скрипты деплоя
│   └── serverless/             # Фреймворк serverless
│       ├── cmd/                # CLI
│       ├── Makefile            # Makefile с командами
│       └── serverless.go       # Основной код фреймворка
├── func/                       # Директория с функциями
│   ├── func1/                  # Функция 1
│   │   ├── deploy.sh           # Скрипт деплоя для функции 1
│   │   ├── main.go             # Точка входа для функции 1
│   │   └── api-gateway-spec.yaml # Спецификация API Gateway (если нужна)
│   └── func2/                  # Функция 2
│       └── ...
├── internal/                   # Внутренние пакеты
│   ├── handlers/               # Обработчики функций
│   │   ├── func1.go            # Обработчик для функции 1
│   │   └── func2.go            # Обработчик для функции 2
│   └── ... 
├── go.mod                      # Общий файл go.mod
└── go.sum                      # Общий файл go.sum
```

## Начало работы

### Установка

1. Склонируйте репозиторий:
```bash
git clone https://github.com/username/go-yandex.git
cd go-yandex
```

2. Скомпилируйте утилиту serverless:
```bash
cd core/serverless
make build
```

### Использование

#### Генерация проекта

```bash
make generate
```

Эта команда сгенерирует основную структуру проекта, включая пример функций.

#### Создание новой функции

Для создания новой функции без API Gateway:

```bash
make generate
```

Для создания новой функции с API Gateway:

```bash
make new-api-function FUNCTION=my-function ENDPOINT=my-api
```

#### Деплой функции

```bash
make deploy FUNCTION=hello-world
```

Для деплоя всех функций:

```bash
make deploy-all
```

## Примеры

### Пример функции без API Gateway

```go
// internal/handlers/hello-world.go
package handlers

import (
	"context"
	"fmt"
)

func HelloWorldHandler(ctx context.Context, requestBody string) (*HelloWorldResponse, error) {
	return &HelloWorldResponse{
		Message: "Привет, мир!",
	}, nil
}

type HelloWorldResponse struct {
	Message string `json:"message"`
}
```

### Пример функции с API Gateway

```go
// internal/handlers/excel-report.go
package handlers

import (
	"context"
	"encoding/json"
)

type ExcelReportRequest struct {
	ProjectName string `json:"projectName"`
}

type ExcelReportResponse struct {
	FileURL string `json:"fileUrl"`
	Message string `json:"message"`
}

func ExcelReportHandler(ctx context.Context, requestBody string) (*ExcelReportResponse, error) {
	var request ExcelReportRequest
	if err := json.Unmarshal([]byte(requestBody), &request); err != nil {
		return nil, err
	}
	
	// Здесь логика генерации Excel-файла
	
	return &ExcelReportResponse{
		FileURL: "https://example.com/reports/report.xlsx",
		Message: fmt.Sprintf("Отчет для проекта %s сгенерирован", request.ProjectName),
	}, nil
}
```

## Добавление зависимостей

Добавляйте зависимости в корневой файл go.mod:

```bash
cd /path/to/project
go get github.com/some/package
```

## Лицензия

MIT 