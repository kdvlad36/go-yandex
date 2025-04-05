# Makefile для serverless фреймворка

GO := go
BUILD_DIR := ../../bin
BIN_NAME := serverless

# Определение целевой платформы
GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)

.PHONY: all build clean generate deploy deploy-all help

all: build

# Компиляция утилиты serverless
build:
	@echo "Компиляция утилиты $(BIN_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(GO) build -o $(BUILD_DIR)/$(BIN_NAME) ./cmd/main.go

# Очистка сгенерированных файлов
clean:
	@echo "Очистка..."
	rm -f $(BUILD_DIR)/$(BIN_NAME)

# Генерация проекта
generate:
	@echo "Генерация проекта..."
	$(BUILD_DIR)/$(BIN_NAME) -action=generate

# Деплой конкретной функции
deploy:
	@if [ -z "$(FUNCTION)" ]; then \
		echo "Ошибка: необходимо указать имя функции FUNCTION=<имя_функции>"; \
		exit 1; \
	fi
	@echo "Деплой функции $(FUNCTION)..."
	$(BUILD_DIR)/$(BIN_NAME) -action=deploy -function=$(FUNCTION)

# Деплой всех функций
deploy-all:
	@echo "Деплой всех функций..."
	$(BUILD_DIR)/$(BIN_NAME) -action=deploy-all

# Создание новой функции с API Gateway
new-api-function:
	@if [ -z "$(FUNCTION)" ]; then \
		echo "Ошибка: необходимо указать имя функции FUNCTION=<имя_функции>"; \
		exit 1; \
	fi
	@echo "Создание новой функции $(FUNCTION) с API Gateway..."
	$(BUILD_DIR)/$(BIN_NAME) -action=generate -api=true -function=$(FUNCTION) -endpoint=$(or $(ENDPOINT),$(FUNCTION))

# Помощь
help:
	@echo "Доступные команды:"
	@echo "  make build          - Компиляция утилиты serverless"
	@echo "  make generate       - Генерация файлов проекта"
	@echo "  make deploy         - Деплой конкретной функции"
	@echo "                        Пример: make deploy FUNCTION=hello-world"
	@echo "  make deploy-all     - Деплой всех функций"
	@echo "  make new-api-function - Создание новой функции с API Gateway"
	@echo "                        Пример: make new-api-function FUNCTION=my-function ENDPOINT=custom-api"
	@echo "  make clean          - Очистка сгенерированных файлов"
	@echo "  make help           - Показать эту справку" 