// Package main обеспечивает функцию для генерации Excel отчетов
package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/xuri/excelize/v2"
)

// ProjectRequest содержит название проекта для генерации отчета
type ProjectRequest struct {
	ProjectName string `json:"projectName"`
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
// Может быть вызвана напрямую или через API Gateway
func Handler(ctx context.Context, request json.RawMessage) (*Response, error) {
	// Пробуем интерпретировать запрос как API Gateway запрос
	var gatewayRequest APIGatewayRequest
	err := json.Unmarshal(request, &gatewayRequest)
	
	// Если это запрос от API Gateway
	if err == nil && gatewayRequest.HTTPMethod != "" {
		return handleAPIGatewayRequest(ctx, &gatewayRequest)
	}
	
	// Если это прямой вызов функции
	var projectRequest ProjectRequest
	if err := json.Unmarshal(request, &projectRequest); err != nil {
		return errorResponse(400, "Некорректный запрос", err), nil
	}
	
	return GenerateExcelReport(ctx, &projectRequest)
}

// handleAPIGatewayRequest обрабатывает запрос из API Gateway
func handleAPIGatewayRequest(ctx context.Context, request *APIGatewayRequest) (*Response, error) {
	// Проверяем метод
	if request.HTTPMethod != "POST" && request.HTTPMethod != "GET" {
		return errorResponse(405, "Метод не поддерживается, используйте GET или POST", nil), nil
	}
	
	var projectRequest ProjectRequest
	
	// Обрабатываем GET-запрос (параметры в URL)
	if request.HTTPMethod == "GET" {
		projectName, ok := request.QueryStringParameters["projectName"]
		if !ok || projectName == "" {
			return errorResponse(400, "Параметр projectName не указан в URL", nil), nil
		}
		projectRequest.ProjectName = projectName
	} else {
		// Обрабатываем POST-запрос (параметры в JSON)
		if err := json.Unmarshal([]byte(request.Body), &projectRequest); err != nil {
			return errorResponse(400, "Некорректный формат JSON в теле запроса", err), nil
		}
	}
	
	return GenerateExcelReport(ctx, &projectRequest)
}

// encodeSafeFilename кодирует имя файла для безопасного использования в HTTP-заголовках
func encodeSafeFilename(filename string) string {
	// Транслитерация кириллицы (для простоты используем англ. название)
	translit := map[string]string{
		"Отчет": "Otchet",
		"по": "po",
		"проекту": "proektu",
	}
	
	for cyr, lat := range translit {
		filename = strings.ReplaceAll(filename, cyr, lat)
	}
	
	// URL-кодирование для безопасности
	return url.QueryEscape(filename)
}

// GenerateExcelReport создает Excel отчет для указанного проекта
func GenerateExcelReport(ctx context.Context, request *ProjectRequest) (*Response, error) {
	if request.ProjectName == "" {
		return errorResponse(400, "Не указано название проекта", nil), nil
	}

	// Создаем новый Excel файл
	f := excelize.NewFile()
	defer func() {
		if err := f.Close(); err != nil {
			fmt.Println(err)
		}
	}()

	// Устанавливаем заголовки в первой строке
	headers := []string{"№", "Показатель", "Значение", "Дата"}
	for i, header := range headers {
		cell, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue("Sheet1", cell, header)
	}

	// Добавляем стилизацию для заголовков
	style, err := f.NewStyle(&excelize.Style{
		Font: &excelize.Font{
			Bold: true,
		},
		Fill: excelize.Fill{
			Type:    "pattern",
			Color:   []string{"#DCE6F1"},
			Pattern: 1,
		},
	})
	if err != nil {
		return errorResponse(500, "Ошибка создания стиля", err), nil
	}

	// Применяем стиль к заголовкам
	f.SetCellStyle("Sheet1", "A1", "D1", style)

	// Добавляем примерные данные (в реальности здесь должна быть логика получения данных из БД)
	demoData := [][]interface{}{
		{1, "Общий бюджет", 5000000, time.Now().Format("02.01.2006")},
		{2, "Потрачено", 3200000, time.Now().Format("02.01.2006")},
		{3, "Осталось", 1800000, time.Now().Format("02.01.2006")},
		{4, "Прогресс", "64%", time.Now().Format("02.01.2006")},
	}

	// Добавляем демо-данные в таблицу
	for i, row := range demoData {
		for j, cell := range row {
			cellName, _ := excelize.CoordinatesToCellName(j+1, i+2)
			f.SetCellValue("Sheet1", cellName, cell)
		}
	}

	// Автоматически подстраиваем ширину столбцов
	for i := range headers {
		colName, _ := excelize.ColumnNumberToName(i + 1)
		f.SetColWidth("Sheet1", colName, colName, 20)
	}

	// Переименовываем лист
	reportName := fmt.Sprintf("Отчет по проекту %s", request.ProjectName)
	f.SetSheetName("Sheet1", reportName)

	// Сохраняем в буфер
	buffer, err := f.WriteToBuffer()
	if err != nil {
		return errorResponse(500, "Ошибка сохранения Excel", err), nil
	}

	// Создаем безопасное имя файла для HTTP-заголовка
	safeFilename := fmt.Sprintf("Project_Report_%s.xlsx", encodeSafeFilename(request.ProjectName))

	// Возвращаем Excel файл
	return &Response{
		StatusCode: 200,
		Body:       base64.StdEncoding.EncodeToString(buffer.Bytes()),
		Headers: map[string]string{
			"Content-Type":        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
			"Content-Disposition": fmt.Sprintf("attachment; filename=\"%s\"", safeFilename),
		},
		IsBase64Encoded: true,
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
		// Обрабатываем GET запросы напрямую
		if r.Method == "GET" {
			projectName := r.URL.Query().Get("projectName")
			if projectName == "" {
				http.Error(w, "Параметр projectName не указан", http.StatusBadRequest)
				return
			}
			
			// Создаем запрос вручную
			reqData, _ := json.Marshal(&ProjectRequest{ProjectName: projectName})
			response, err := Handler(r.Context(), reqData)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			
			// Устанавливаем заголовки и отправляем ответ
			for k, v := range response.Headers {
				w.Header().Set(k, v)
			}
			w.WriteHeader(response.StatusCode)
			
			if response.IsBase64Encoded {
				decoded, err := base64.StdEncoding.DecodeString(response.Body)
				if err != nil {
					http.Error(w, "Ошибка декодирования ответа", http.StatusInternalServerError)
					return
				}
				w.Write(decoded)
			} else {
				w.Write([]byte(response.Body))
			}
			return
		}
		
		// Для POST запросов читаем тело
		bodyData, err := ioutil.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Ошибка чтения тела запроса", http.StatusBadRequest)
			return
		}
		
		// Обрабатываем запрос
		response, err := Handler(r.Context(), bodyData)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Устанавливаем заголовки
		for k, v := range response.Headers {
			w.Header().Set(k, v)
		}
		
		// Устанавливаем статус-код
		w.WriteHeader(response.StatusCode)
		
		// Если ответ закодирован в base64, декодируем его
		if response.IsBase64Encoded {
			decoded, err := base64.StdEncoding.DecodeString(response.Body)
			if err != nil {
				http.Error(w, "Ошибка декодирования ответа", http.StatusInternalServerError)
				return
			}
			w.Write(decoded)
		} else {
			// Иначе отправляем как есть
			w.Write([]byte(response.Body))
		}
	})

	// Запускаем локальный сервер для тестирования
	fmt.Println("Запуск локального сервера на http://localhost:8080/")
	fmt.Println("Пример GET-запроса: http://localhost:8080/?projectName=МойПроект")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Printf("Ошибка сервера: %v\n", err)
	}
} 