.PHONY: build test deploy deploy-without-api deploy-with-cron clean

# Сборка всех функций
build:
	@echo "Сборка всех функций..."
	go build -o bin/excel-report ./func/excel-report

# Запуск тестов
test:
	@echo "Запуск тестов..."
	go test ./...

# Деплой функции excel-report с API Gateway
deploy:
	@echo "Деплой функции excel-report с API Gateway..."
	./func/excel-report/deploy.sh

# Деплой функции excel-report без API Gateway
deploy-without-api:
	@echo "Деплой функции excel-report без API Gateway..."
	./func/excel-report/deploy-without-api.sh

# Деплой функции excel-report с cron-триггером
deploy-with-cron:
	@echo "Деплой функции excel-report с cron-триггером..."
	./func/excel-report/deploy-with-cron.sh

# Очистка бинарных файлов
clean:
	@echo "Очистка..."
	rm -rf bin/

# Помощь
help:
	@echo "Доступные команды:"
	@echo "  make build              - сборка всех функций"
	@echo "  make test               - запуск тестов"
	@echo "  make deploy             - деплой функции с API Gateway"
	@echo "  make deploy-without-api - деплой функции без API Gateway"
	@echo "  make deploy-with-cron   - деплой функции с cron-триггером"
	@echo "  make clean              - очистка бинарных файлов"
	@echo "  make help               - показать эту справку" 