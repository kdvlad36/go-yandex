.PHONY: build test deploy clean

# Сборка всех контейнеров
build: start-docker
	@echo "Сборка всех контейнеров..."
	docker build -t hello-world-container ./containers/hello-world

# Запуск тестов
test:
	@echo "Запуск тестов..."
	go test ./...

# Автоматическая проверка и запуск Docker
start-docker:
	@echo "Проверка состояния Docker..."
	@./tools/check-docker.sh

# Проверка наличия всех необходимых компонентов
check-deps:
	@echo "Проверка зависимостей..."
	@which yc >/dev/null || (echo "Ошибка: Yandex Cloud CLI не установлен"; exit 1)
	@which jq >/dev/null || (echo "Ошибка: jq не установлен"; exit 1)
	@echo "Все зависимости установлены."

# Проверка и выбор сервисного аккаунта
check-service-account: check-deps
	@echo "Проверка сервисных аккаунтов..."
	@./tools/check-service-account.sh

# Деплой контейнера hello-world (с полной сборкой)
deploy-hello: check-service-account start-docker
	@echo "Деплой контейнера hello-world..."
	./containers/hello-world/deploy/deploy.sh

# Обновление контейнера hello-world без сборки образа
update-hello: check-service-account
	@echo "Обновление контейнера hello-world без сборки образа..."
	./containers/hello-world/deploy/deploy.sh --skip-build

# Деплой нового контейнера (шаблон)
deploy-%: check-service-account start-docker
	@echo "Деплой контейнера $*..."
	@if [ -d "./containers/$*" ]; then \
		./containers/$*/deploy/deploy.sh; \
	else \
		echo "Ошибка: Контейнер $* не найден"; \
		exit 1; \
	fi

# Обновление контейнера без сборки образа (шаблон)
update-%: check-service-account
	@echo "Обновление контейнера $* без сборки образа..."
	@if [ -d "./containers/$*" ]; then \
		./containers/$*/deploy/deploy.sh --skip-build; \
	else \
		echo "Ошибка: Контейнер $* не найден"; \
		exit 1; \
	fi

# Создание нового контейнера на основе шаблона
create-container:
	@echo "Создание нового контейнера..."
	@read -p "Введите имя контейнера: " name; \
	if [ -z "$$name" ]; then echo "Ошибка: имя контейнера не может быть пустым"; exit 1; fi; \
	if [ -d "./containers/$$name" ]; then echo "Ошибка: контейнер $$name уже существует"; exit 1; fi; \
	mkdir -p "./containers/$$name/deploy"; \
	cp -r "./templates/container/Dockerfile" "./containers/$$name/"; \
	cp -r "./templates/container/deploy/api-gateway-spec.yaml" "./containers/$$name/deploy/"; \
	cp -r "./templates/container/deploy/deploy.sh" "./containers/$$name/deploy/"; \
	chmod +x "./containers/$$name/deploy/deploy.sh"; \
	sed -i'' -e "s/container-name/$$name-container/g" "./containers/$$name/deploy/deploy.sh"; \
	sed -i'' -e "s/Описание контейнера/Контейнер $$name для Serverless Containers/g" "./containers/$$name/deploy/deploy.sh"; \
	sed -i'' -e "s/Container Service/$$name Service/g" "./containers/$$name/deploy/api-gateway-spec.yaml"; \
	sed -i'' -e "s/Container API/$$name API/g" "./containers/$$name/deploy/api-gateway-spec.yaml"; \
	echo -e "package main\n\nimport (\n\t\"log\"\n\t\"net/http\"\n)\n\nfunc main() {\n\thttp.HandleFunc(\"/\", func(w http.ResponseWriter, r *http.Request) {\n\t\tw.Header().Set(\"Content-Type\", \"application/json\")\n\t\tw.Write([]byte(\"{\\\"status\\\":\\\"ok\\\",\\\"service\\\":\\\"$$name\\\"}\\n\"))\n\t})\n\n\tlog.Println(\"Сервер запущен на порту 8080\")\n\tlog.Fatal(http.ListenAndServe(\":8080\", nil))\n}" > "./containers/$$name/main.go"; \
	echo "✓ Контейнер $$name создан. Путь: ./containers/$$name"

# Очистка
clean:
	@echo "Очистка..."
	docker system prune -f

# Помощь
help:
	@echo "Доступные команды:"
	@echo "  make build             - сборка всех контейнеров"
	@echo "  make test              - запуск тестов"
	@echo "  make start-docker      - автоматический запуск Docker при необходимости"
	@echo "  make check-deps        - проверка необходимых зависимостей"
	@echo "  make check-service-account - выбор сервисного аккаунта"
	@echo "  make deploy-hello      - деплой контейнера hello-world (с полной сборкой)"
	@echo "  make update-hello      - обновление контейнера без сборки образа"
	@echo "  make deploy-CONTAINER  - деплой указанного контейнера (с полной сборкой)"
	@echo "  make update-CONTAINER  - обновление указанного контейнера без сборки образа"
	@echo "  make create-container  - создание нового контейнера на основе шаблона"
	@echo "  make clean             - очистка Docker-образов"
	@echo "  make help              - показать эту справку" 