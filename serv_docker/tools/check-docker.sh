#!/bin/bash

# Скрипт для проверки и автоматического запуска Docker на macOS

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
  echo "Ошибка: Docker не установлен"
  echo "Пожалуйста, установите Docker: https://docs.docker.com/get-docker/"
  exit 1
fi

# Проверка, запущен ли Docker
if ! docker info &> /dev/null; then
  echo "Docker не запущен. Попытка автоматического запуска..."
  
  # Определение операционной системы
  OS_TYPE=$(uname -s)
  
  if [ "$OS_TYPE" == "Darwin" ]; then
    # macOS
    echo "Обнаружена macOS. Запуск Docker..."
    
    # Проверка, установлен ли Docker Desktop
    if [ -d "/Applications/Docker.app" ]; then
      echo "Запуск Docker Desktop..."
      open -a Docker
      
      # Ожидание запуска Docker (до 60 секунд)
      MAX_ATTEMPTS=12
      ATTEMPTS=0
      
      echo "Ожидание запуска Docker..."
      while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        if docker info &> /dev/null; then
          echo "Docker успешно запущен!"
          break
        fi
        
        echo "Ожидание запуска Docker... ($((ATTEMPTS+1))/$MAX_ATTEMPTS)"
        sleep 5
        ATTEMPTS=$((ATTEMPTS+1))
      done
      
      if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
        echo "Превышено время ожидания запуска Docker"
        echo "Пожалуйста, запустите Docker вручную и повторите команду"
        exit 1
      fi
    else
      echo "Ошибка: Docker Desktop не найден в /Applications"
      echo "Пожалуйста, запустите Docker вручную и повторите команду"
      exit 1
    fi
  elif [ "$OS_TYPE" == "Linux" ]; then
    # Linux
    echo "Обнаружен Linux. Попытка запуска службы Docker..."
    
    # Проверка прав суперпользователя
    if [ "$(id -u)" != "0" ]; then
      echo "Для запуска Docker на Linux требуются права суперпользователя"
      
      # Попытка запуска через sudo
      if sudo systemctl start docker &> /dev/null || sudo service docker start &> /dev/null; then
        echo "Docker успешно запущен через sudo"
        
        # Ожидание запуска Docker
        sleep 3
        if ! sudo docker info &> /dev/null; then
          echo "Ошибка: Docker не удалось запустить"
          exit 1
        fi
      else
        echo "Ошибка: Не удалось запустить Docker"
        echo "Пожалуйста, запустите Docker вручную и повторите команду"
        exit 1
      fi
    else
      # Уже запущен с правами root
      if systemctl start docker &> /dev/null || service docker start &> /dev/null; then
        echo "Docker успешно запущен"
        sleep 3
      else
        echo "Ошибка: Не удалось запустить Docker"
        exit 1
      fi
    fi
  else
    echo "Ошибка: Неподдерживаемая операционная система: $OS_TYPE"
    echo "Пожалуйста, запустите Docker вручную и повторите команду"
    exit 1
  fi
  
  # Финальная проверка Docker
  if ! docker info &> /dev/null; then
    echo "Ошибка: Docker не удалось запустить автоматически"
    exit 1
  fi
  
  echo "Docker запущен и готов к использованию!"
else
  echo "Docker уже запущен."
fi

exit 0 