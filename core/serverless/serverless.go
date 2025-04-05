package serverless

import (
	"fmt"
	"os"
	"path/filepath"
)

// CloudFunction представляет собой структуру Yandex Cloud Function
type CloudFunction struct {
	Name        string            // имя функции
	Description string            // описание функции
	Runtime     string            // среда выполнения
	Entrypoint  string            // точка входа
	Memory      string            // объем памяти
	Timeout     string            // таймаут выполнения
	SourcePath  string            // путь к исходникам
	Environment map[string]string // переменные окружения
	HasAPI      bool              // требуется ли API Gateway
	APISpec     string            // путь к спецификации API Gateway
	APIEndpoint string            // эндпоинт API Gateway
}

// DefaultFunction возвращает функцию с настройками по умолчанию
func DefaultFunction(name string) CloudFunction {
	return CloudFunction{
		Name:        name,
		Description: fmt.Sprintf("Функция %s", name),
		Runtime:     "golang121",
		Entrypoint:  "main.Handler",
		Memory:      "256m",
		Timeout:     "30s",
		SourcePath:  "",
		Environment: map[string]string{"LOG_LEVEL": "info"},
		HasAPI:      false,
	}
}

// Project представляет собой проект Yandex Cloud Functions
type Project struct {
	Name           string                  // имя проекта
	Path           string                  // путь к проекту
	RootModule     string                  // имя корневого модуля Go
	Functions      map[string]CloudFunction // функции проекта
	APIGatewayName string                  // имя API Gateway
}

// NewProject создает новый проект
func NewProject(name, path, rootModule string) *Project {
	return &Project{
		Name:           name,
		Path:           path,
		RootModule:     rootModule,
		Functions:      make(map[string]CloudFunction),
		APIGatewayName: fmt.Sprintf("%s-api", name),
	}
}

// AddFunction добавляет функцию в проект
func (p *Project) AddFunction(f CloudFunction) {
	p.Functions[f.Name] = f
}

// Deploy деплоит функцию
func (p *Project) Deploy(functionName string) error {
	f, exists := p.Functions[functionName]
	if !exists {
		return fmt.Errorf("функция %s не найдена", functionName)
	}
	
	// Создаем временную директорию для функции, если она не существует
	funcDir := filepath.Join(p.Path, "func", functionName)
	if _, err := os.Stat(funcDir); os.IsNotExist(err) {
		if err := os.MkdirAll(funcDir, 0755); err != nil {
			return fmt.Errorf("ошибка создания директории: %v", err)
		}
	}
	
	// Создаем скрипт деплоя для функции
	deployScript := filepath.Join(funcDir, "deploy.sh")
	if f.HasAPI {
		if err := p.createAPIDeployScript(deployScript, f); err != nil {
			return fmt.Errorf("ошибка создания скрипта деплоя: %v", err)
		}
	} else {
		if err := p.createDeployScript(deployScript, f); err != nil {
			return fmt.Errorf("ошибка создания скрипта деплоя: %v", err)
		}
	}
	
	// Делаем скрипт исполняемым
	if err := os.Chmod(deployScript, 0755); err != nil {
		return fmt.Errorf("ошибка установки прав на скрипт: %v", err)
	}
	
	// Запускаем скрипт деплоя
	// Примечание: в реальной реализации лучше использовать exec.Command
	fmt.Printf("Запуск деплоя функции %s...\n", functionName)
	fmt.Printf("Для деплоя выполните команду: %s\n", deployScript)
	
	return nil
}

// createDeployScript создает скрипт деплоя без API Gateway
func (p *Project) createDeployScript(path string, f CloudFunction) error {
	content := `#!/bin/bash

# Проверка на рекурсивный вызов
if [ -n "$DEPLOY_RUNNING" ]; then
    echo "Ошибка: обнаружен рекурсивный вызов скрипта деплоя"
    exit 1
fi
export DEPLOY_RUNNING=1

# Определение пути к корневому каталогу проекта
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../")"
export PROJECT_ROOT

# Параметры для деплоя без API Gateway
export FUNCTION_NAME="%s"
export FUNCTION_DIR="func/%s"
export FUNCTION_DESCRIPTION="%s"
export RUNTIME="%s"
export ENTRYPOINT="%s"
export MEMORY="%s"
export TIMEOUT="%s"
export LOG_LEVEL="%s"
export USE_ROOT_GOMOD="true"

# Запуск основного скрипта деплоя
"$PROJECT_ROOT/core/deploy/deploy-without-api.sh"
`
	content = fmt.Sprintf(content, 
		f.Name, 
		f.Name, 
		f.Description, 
		f.Runtime, 
		f.Entrypoint, 
		f.Memory, 
		f.Timeout, 
		f.Environment["LOG_LEVEL"],
	)
	
	return os.WriteFile(path, []byte(content), 0644)
}

// createAPIDeployScript создает скрипт деплоя с API Gateway
func (p *Project) createAPIDeployScript(path string, f CloudFunction) error {
	content := `#!/bin/bash

# Проверка на рекурсивный вызов
if [ -n "$DEPLOY_RUNNING" ]; then
    echo "Ошибка: обнаружен рекурсивный вызов скрипта деплоя"
    exit 1
fi
export DEPLOY_RUNNING=1

# Определение пути к корневому каталогу проекта
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../../")"
export PROJECT_ROOT

# Параметры для деплоя с API Gateway
export FUNCTION_NAME="%s"
export FUNCTION_DIR="func/%s"
export API_GATEWAY_NAME="%s"
export FUNCTION_DESCRIPTION="%s"
export RUNTIME="%s"
export ENTRYPOINT="%s"
export MEMORY="%s"
export TIMEOUT="%s"
export LOG_LEVEL="%s"
export API_SPEC_PATH="%s"
export API_ENDPOINT="%s"
export TEST_METHOD="POST"
export API_GATEWAY_DESCRIPTION="API Gateway для %s"
export USE_ROOT_GOMOD="true"

# Запуск основного скрипта деплоя
"$PROJECT_ROOT/core/deploy/deploy-with-api.sh"
`
	content = fmt.Sprintf(content, 
		f.Name, 
		f.Name, 
		p.APIGatewayName,
		f.Description, 
		f.Runtime, 
		f.Entrypoint, 
		f.Memory, 
		f.Timeout, 
		f.Environment["LOG_LEVEL"],
		f.APISpec,
		f.APIEndpoint,
		p.Name,
	)
	
	return os.WriteFile(path, []byte(content), 0644)
}

// DeployAll деплоит все функции проекта
func (p *Project) DeployAll() error {
	for name := range p.Functions {
		if err := p.Deploy(name); err != nil {
			return fmt.Errorf("ошибка деплоя %s: %v", name, err)
		}
	}
	return nil
}

// GenerateMain генерирует файл main.go для функции
func (p *Project) GenerateMain(functionName string) error {
	f, exists := p.Functions[functionName]
	if !exists {
		return fmt.Errorf("функция %s не найдена", functionName)
	}
	
	// Создаем временную директорию для функции, если она не существует
	funcDir := filepath.Join(p.Path, "func", functionName)
	if _, err := os.Stat(funcDir); os.IsNotExist(err) {
		if err := os.MkdirAll(funcDir, 0755); err != nil {
			return fmt.Errorf("ошибка создания директории: %v", err)
		}
	}
	
	mainPath := filepath.Join(funcDir, "main.go")
	
	// Если файл уже существует, не перезаписываем его
	if _, err := os.Stat(mainPath); err == nil {
		return nil
	}
	
	content := `package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	
	"%s/internal/handlers"
)

// Request представляет входящий запрос
type Request struct {
	Body    string            ` + "`json:\"body\"`" + `
	Headers map[string]string ` + "`json:\"headers\"`" + `
	Query   map[string]string ` + "`json:\"queryStringParameters\"`" + `
	Path    map[string]string ` + "`json:\"pathParameters\"`" + `
}

// Response представляет ответ функции
type Response struct {
	StatusCode int               ` + "`json:\"statusCode\"`" + `
	Headers    map[string]string ` + "`json:\"headers\"`" + `
	Body       string            ` + "`json:\"body\"`" + `
}

// NewResponse создает новый ответ функции
func NewResponse(statusCode int, body string) Response {
	return Response{
		StatusCode: statusCode,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: body,
	}
}

// Handler обрабатывает запросы к функции
func Handler(ctx context.Context, request Request) (Response, error) {
	// Вызываем обработчик из пакета handlers
	result, err := handlers.%sHandler(ctx, request.Body)
	if err != nil {
		return NewResponse(http.StatusInternalServerError, fmt.Sprintf("{\"error\":\"%s\"}", err.Error())), nil
	}
	
	responseBody, err := json.Marshal(result)
	if err != nil {
		return NewResponse(http.StatusInternalServerError, "{\"error\":\"failed to marshal response\"}"), nil
	}
	
	return NewResponse(http.StatusOK, string(responseBody)), nil
}
`
	content = fmt.Sprintf(content, p.RootModule, f.Name)
	
	return os.WriteFile(mainPath, []byte(content), 0644)
}

// GenerateHandler генерирует файл обработчика для функции
func (p *Project) GenerateHandler(functionName string) error {
	// Создаем директорию для обработчиков, если она не существует
	handlersDir := filepath.Join(p.Path, "internal", "handlers")
	if _, err := os.Stat(handlersDir); os.IsNotExist(err) {
		if err := os.MkdirAll(handlersDir, 0755); err != nil {
			return fmt.Errorf("ошибка создания директории: %v", err)
		}
	}
	
	handlerPath := filepath.Join(handlersDir, fmt.Sprintf("%s.go", functionName))
	
	// Если файл уже существует, не перезаписываем его
	if _, err := os.Stat(handlerPath); err == nil {
		return nil
	}
	
	content := `package handlers

import (
	"context"
	"encoding/json"
)

// %sRequest представляет входящий запрос для функции %s
type %sRequest struct {
	// Добавьте поля запроса здесь
}

// %sResponse представляет ответ функции %s
type %sResponse struct {
	Message string ` + "`json:\"message\"`" + `
}

// %sHandler обрабатывает запросы к функции %s
func %sHandler(ctx context.Context, requestBody string) (*%sResponse, error) {
	var request %sRequest
	if requestBody != "" {
		if err := json.Unmarshal([]byte(requestBody), &request); err != nil {
			return nil, err
		}
	}
	
	// Реализуйте логику обработки здесь
	
	return &%sResponse{
		Message: "Привет из функции %s!",
	}, nil
}
`
	content = fmt.Sprintf(content, 
		functionName, functionName, functionName,
		functionName, functionName, functionName,
		functionName, functionName, functionName, functionName, functionName,
		functionName, functionName,
	)
	
	return os.WriteFile(handlerPath, []byte(content), 0644)
}

// GenerateAPISpec генерирует спецификацию API Gateway для функции
func (p *Project) GenerateAPISpec(functionName string) error {
	f, exists := p.Functions[functionName]
	if !exists || !f.HasAPI {
		return fmt.Errorf("функция %s не найдена или не требует API", functionName)
	}
	
	// Создаем временную директорию для функции, если она не существует
	funcDir := filepath.Join(p.Path, "func", functionName)
	if _, err := os.Stat(funcDir); os.IsNotExist(err) {
		if err := os.MkdirAll(funcDir, 0755); err != nil {
			return fmt.Errorf("ошибка создания директории: %v", err)
		}
	}
	
	apiSpecPath := filepath.Join(funcDir, "api-gateway-spec.yaml")
	
	// Если файл уже существует, не перезаписываем его
	if _, err := os.Stat(apiSpecPath); err == nil {
		return nil
	}
	
	content := `openapi: 3.0.0
info:
  title: %s API
  version: 1.0.0
  description: API для функции %s

paths:
  /%s:
    post:
      summary: Вызов функции %s
      description: Отправляет запрос к функции %s
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                # Укажите свойства запроса здесь
                message:
                  type: string
                  example: "Тестовое сообщение"
      responses:
        '200':
          description: Успешный ответ
          content:
            application/json:
              schema:
                type: object
                properties:
                  message:
                    type: string
      x-yc-apigateway-integration:
        type: cloud_functions
        function_id: ${FUNCTION_ID}
        service_account_id: ${SERVICE_ACCOUNT_ID}
`
	content = fmt.Sprintf(content, 
		functionName, functionName,
		f.APIEndpoint,
		functionName, functionName,
	)
	
	return os.WriteFile(apiSpecPath, []byte(content), 0644)
}

// GenerateProject генерирует все необходимые файлы для проекта
func (p *Project) GenerateProject() error {
	// Генерируем файлы для каждой функции
	for name, f := range p.Functions {
		if err := p.GenerateMain(name); err != nil {
			return fmt.Errorf("ошибка генерации main.go для %s: %v", name, err)
		}
		
		if err := p.GenerateHandler(name); err != nil {
			return fmt.Errorf("ошибка генерации обработчика для %s: %v", name, err)
		}
		
		if f.HasAPI {
			if err := p.GenerateAPISpec(name); err != nil {
				return fmt.Errorf("ошибка генерации API-спецификации для %s: %v", name, err)
			}
		}
	}
	
	return nil
} 