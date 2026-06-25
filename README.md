# DevQuiz

Платформа интерактивного тестирования для backend-разработчиков.

**[devquiz-1kom.onrender.com](https://devquiz-1kom.onrender.com/)**

## Локальный запуск

### Требования

- Ruby 3.3.6
- Node.js 20.20.1
- PostgreSQL

Версии Ruby и Node.js можно установить вручную или через [mise](https://mise.jdx.dev/) (конфиг в `mise.toml`).

### Установка

```bash
cd app

bundle install
npm install

cp .env.example .env

bundle exec rails db:create db:migrate

# Загрузить тесты из YAML-файлов
bundle exec rails runner "YamlSyncService.new.call"
```

### Запуск

В двух отдельных терминалах:

```bash
cd app

# Vite dev server
npm run dev

# Rails сервер
bundle exec rails server
```

Приложение доступно на [http://localhost:3000](http://localhost:3000)

## Создание и редактирование тестов

Квизы хранятся в YAML-файлах в папке `tests/` и автоматически синхронизируются с базой при деплое. При создании или изменении YAML-файла тесты в приложении обновятся автоматически.

Именование файлов: `<тема>-<уровень>-<номер>.yml`, например `docker-advanced-1.yml`.

### Структура файла

```yaml
slug: my-quiz          # уникальный идентификатор
title: "Название теста"
description: "Краткое описание."
tags: [tag1, tag2]
difficulty: beginner   # beginner | intermediate | advanced
estimated_time: 15     # минуты

questions:
  - id: q1
    text: "Текст вопроса?"
    type: single        # single | multiple
    difficulty: easy    # easy | medium
    options:
      - id: a
        text: "Вариант A"
        correct: false
      - id: b
        text: "Вариант B"
        correct: true
    explanation: "Объяснение правильного ответа."
```
