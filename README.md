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

## Как устроена разработка

Каждая новая возможность живёт в отдельной ветке и привязана к [GitHub Issue](https://github.com/ZinChen/devquiz/issues). Это позволяет работать над фичами по одной, не перемешивая изменения, и чётко видеть историю — что, зачем и когда появилось.

### Взять фичу в работу

Открываешь нужный issue на GitHub, смотришь описание и чеклист. Создаёшь ветку от `main` с номером issue в названии:

```bash
git checkout main && git pull
git checkout -b feature/1-fill-blank-input
```

Разрабатываешь, коммитишь в обычном темпе. Когда готово — открываешь PR:

```bash
gh pr create --title "Fill-in-the-blank: ввод текста" --body "Closes #1" --base main
```

Фраза `Closes #N` в теле PR — главное. После merge в `main` GitHub автоматически закроет issue.

### Версии

Issues сгруппированы по [Milestones](https://github.com/ZinChen/devquiz/milestones) — каждый milestone соответствует версии приложения. Когда все issues milestone закрыты, выпускаем релиз:

```bash
git tag v0.2.0
git push origin v0.2.0
gh release create v0.2.0 --generate-notes
```

После этого GitHub Actions автоматически деплоит на Render.
