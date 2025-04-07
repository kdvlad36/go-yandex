package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

// Request представляет входные данные для функции
type Request struct {
	Name string `json:"name"`
}

// Response структура для ответа HTTP
type Response struct {
	StatusCode      int               `json:"statusCode"`
	Headers         map[string]string `json:"headers"`
	Body            string            `json:"body,omitempty"`
	IsBase64Encoded bool              `json:"isBase64Encoded"`
}

// APIGatewayRequest представляет запрос от API Gateway
type APIGatewayRequest struct {
	Body                  string            `json:"body"`
	QueryStringParameters map[string]string `json:"queryStringParameters"`
	HTTPMethod            string            `json:"httpMethod"`
	Headers               map[string]string `json:"headers"`
	IsBase64Encoded       bool              `json:"isBase64Encoded"`
}

// Handler - функция обработчик для Yandex Cloud Function
func Handler(ctx context.Context, request json.RawMessage) (*Response, error) {
	// Пробуем интерпретировать запрос как API Gateway запрос
	var gatewayRequest APIGatewayRequest
	err := json.Unmarshal(request, &gatewayRequest)
	
	// Если это запрос от API Gateway
	if err == nil && gatewayRequest.HTTPMethod != "" {
		return handleAPIGatewayRequest(ctx, &gatewayRequest)
	}
	
	// Если это прямой вызов функции
	var reqData Request
	if err := json.Unmarshal(request, &reqData); err != nil {
		// Если не указано имя, используем значение по умолчанию
		reqData.Name = "мир"
	}
	
	return generateResponse(reqData.Name)
}

// handleAPIGatewayRequest обрабатывает запрос из API Gateway
func handleAPIGatewayRequest(ctx context.Context, request *APIGatewayRequest) (*Response, error) {
	// Проверяем метод
	if request.HTTPMethod != "POST" && request.HTTPMethod != "GET" {
		return errorResponse(405, "Метод не поддерживается, используйте GET или POST", nil), nil
	}
	
	var reqData Request
	
	// Обрабатываем GET-запрос (параметры в URL)
	if request.HTTPMethod == "GET" {
		name, ok := request.QueryStringParameters["name"]
		if ok {
			reqData.Name = name
		} else {
			reqData.Name = "мир"
		}
	} else {
		// Обрабатываем POST-запрос (параметры в JSON)
		if err := json.Unmarshal([]byte(request.Body), &reqData); err != nil {
			reqData.Name = "мир"
		}
	}
	
	return generateResponse(reqData.Name)
}

// generateResponse создает приветственное сообщение
func generateResponse(name string) (*Response, error) {
	if name == "" {
		name = "мир"
	}

	// Создаем ответ
	return &Response{
		StatusCode: 200,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body:            fmt.Sprintf(`{"message":"Привет, %s!"}`, name),
		IsBase64Encoded: false,
	}, nil
}

// errorResponse создает ответ с ошибкой
func errorResponse(code int, message string, err error) *Response {
	errorMsg := message
	if err != nil {
		errorMsg = fmt.Sprintf("%s: %v", message, err)
	}
	
	return &Response{
		StatusCode: code,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body:            fmt.Sprintf(`{"error":"%s"}`, errorMsg),
		IsBase64Encoded: false,
	}
}

// Для локального тестирования
func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		var name string
		
		// Обрабатываем GET запросы
		if r.Method == "GET" {
			name = r.URL.Query().Get("name")
		} else if r.Method == "POST" {
			// Для POST-запросов декодируем JSON
			var req Request
			decoder := json.NewDecoder(r.Body)
			if err := decoder.Decode(&req); err == nil {
				name = req.Name
			}
		}
		
		// Генерируем ответ
		response, _ := generateResponse(name)
		
		// Устанавливаем заголовки
		for k, v := range response.Headers {
			w.Header().Set(k, v)
		}
		
		// Устанавливаем статус-код
		w.WriteHeader(response.StatusCode)
		
		// Отправляем тело ответа
		w.Write([]byte(response.Body))
	})

	// Запускаем локальный сервер для тестирования
	fmt.Println("Запуск локального сервера на http://localhost:8080/")
	fmt.Println("Пример GET-запроса: http://localhost:8080/?name=Иван")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Printf("Ошибка сервера: %v\n", err)
	}
} 