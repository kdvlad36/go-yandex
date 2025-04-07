package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

// Request представляет входные данные для контейнера
type Request struct {
	Name string `json:"name" form:"name"`
}

// Response структура для JSON-ответа
type Response struct {
	Message string `json:"message"`
}

func main() {
	// Настройка Gin
	gin.SetMode(gin.ReleaseMode)
	router := gin.Default()

	// Получаем порт из переменной окружения или используем 8080 по умолчанию
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Определяем маршрут GET /hello
	router.GET("/hello", func(c *gin.Context) {
		var req Request
		// Получаем параметр name из URL
		req.Name = c.Query("name")
		if req.Name == "" {
			req.Name = "мир"
		}

		// Формируем и отправляем ответ
		c.JSON(http.StatusOK, Response{
			Message: "Привет, " + req.Name + "!",
		})
	})

	// Определяем маршрут POST /hello
	router.POST("/hello", func(c *gin.Context) {
		var req Request
		// Привязываем JSON-тело запроса к структуре Request
		if err := c.ShouldBindJSON(&req); err != nil {
			req.Name = "мир"
		}

		// Формируем и отправляем ответ
		c.JSON(http.StatusOK, Response{
			Message: "Привет, " + req.Name + "!",
		})
	})

	// Определяем корневой маршрут
	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "Hello World Container",
		})
	})

	// Запускаем сервер
	log.Printf("Сервер запущен на порту %s", port)
	router.Run(":" + port)
} 