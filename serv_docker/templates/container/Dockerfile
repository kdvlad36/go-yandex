FROM golang:1.21-alpine AS builder

WORKDIR /app

# Копируем модули и зависимости
COPY go.mod go.sum ./
RUN go mod download

# Копируем код приложения
COPY . .

# Сборка приложения с параметрами для Linux/AMD64 (совместимость с Yandex Cloud)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/main ./containers/${CONTAINER_PATH:-.}

FROM alpine:latest

WORKDIR /app

# Копируем скомпилированный бинарник из предыдущего этапа
COPY --from=builder /app/main .

# Определение переменных окружения
ENV LOG_LEVEL=info

# Открываем порт
EXPOSE 8080

# Запуск приложения
CMD ["/app/main"] 