package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/username/go-yandex/core/serverless"
)

func main() {
	// Парсим флаги командной строки
	projectName := flag.String("project", "yandex-serverless", "имя проекта")
	action := flag.String("action", "generate", "действие: generate, deploy, deploy-all")
	functionName := flag.String("function", "", "имя функции для деплоя")
	hasAPI := flag.Bool("api", false, "требуется ли API Gateway")
	apiEndpoint := flag.String("endpoint", "", "эндпоинт API Gateway")
	
	flag.Parse()
	
	// Определяем путь к корневому каталогу проекта
	execPath, err := os.Executable()
	if err != nil {
		fmt.Printf("Ошибка определения пути к исполняемому файлу: %v\n", err)
		os.Exit(1)
	}
	
	projectRoot := filepath.Dir(filepath.Dir(filepath.Dir(filepath.Dir(execPath))))
	
	// Создаем проект
	project := serverless.NewProject(*projectName, projectRoot, "github.com/username/go-yandex")
	
	// Примеры функций
	addExampleFunctions(project, *hasAPI, *apiEndpoint)
	
	// Выполняем действие
	switch *action {
	case "generate":
		if err := project.GenerateProject(); err != nil {
			fmt.Printf("Ошибка генерации проекта: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Проект успешно сгенерирован!")
		
	case "deploy":
		if *functionName == "" {
			fmt.Println("Ошибка: необходимо указать имя функции для деплоя")
			os.Exit(1)
		}
		
		if err := project.Deploy(*functionName); err != nil {
			fmt.Printf("Ошибка деплоя функции %s: %v\n", *functionName, err)
			os.Exit(1)
		}
		fmt.Printf("Функция %s успешно подготовлена к деплою!\n", *functionName)
		
	case "deploy-all":
		if err := project.DeployAll(); err != nil {
			fmt.Printf("Ошибка деплоя всех функций: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Все функции успешно подготовлены к деплою!")
		
	default:
		fmt.Printf("Неизвестное действие: %s\n", *action)
		os.Exit(1)
	}
}

// addExampleFunctions добавляет примеры функций в проект
func addExampleFunctions(project *serverless.Project, hasAPI bool, apiEndpoint string) {
	// Пример функции без API Gateway
	helloFunc := serverless.DefaultFunction("hello-world")
	project.AddFunction(helloFunc)
	
	// Пример функции с API Gateway
	excelFunc := serverless.DefaultFunction("excel-report")
	excelFunc.Description = "Excel отчеты в формате XLSX"
	excelFunc.HasAPI = true
	excelFunc.APISpec = "api-gateway-spec.yaml"
	excelFunc.APIEndpoint = "excel-report"
	project.AddFunction(excelFunc)
	
	// Если указаны параметры API, создаем дополнительную функцию
	if hasAPI {
		customFunc := serverless.DefaultFunction("custom-function")
		customFunc.HasAPI = true
		
		if apiEndpoint != "" {
			customFunc.APIEndpoint = apiEndpoint
		} else {
			customFunc.APIEndpoint = "custom"
		}
		
		customFunc.APISpec = "api-gateway-spec.yaml"
		project.AddFunction(customFunc)
	}
} 