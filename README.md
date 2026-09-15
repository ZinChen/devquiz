# DevQuiz

Платформа интерактивного тестирования для backend-разработчиков.

**[devquiz.zinchenlab.ru](https://devquiz.zinchenlab.ru/)**

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

Каждая возможность привязана к [GitHub Issue](https://github.com/ZinChen/devquiz/issues), а issues сгруппированы по [Milestones](https://github.com/ZinChen/devquiz/milestones) — один milestone соответствует одной версии.

### Ветки и окружения

| Ветка | Куда выкатывается | Когда |
|---|---|---|
| `dev` | [dev.devquiz.zinchenlab.ru](https://dev.devquiz.zinchenlab.ru/) | при каждом push |
| `main` | [devquiz.zinchenlab.ru](https://devquiz.zinchenlab.ru/) | при каждом push |

Деплой автоматический: CI прогоняет линтер, тесты и E2E, собирает образ, кладёт его в ghcr и перезапускает нужный сервис на VDS. Конфиг стенда (`compose.yaml`, `Caddyfile`) подтягивается только из `main`, поэтому push в `dev` не может задеть продакшен.

### Взять фичу в работу

Смотришь описание и чеклист в issue, ветвишься от `dev`:

```bash
git checkout dev && git pull
git checkout -b feature/6-weak-topics
```

Небольшие правки можно вести прямо в `dev` — она и так выкатывается только на стенд.

Когда готово, открываешь PR в `dev` либо мержишь напрямую. Дальше — проверка на стенде: CI зелёный ещё не значит, что вёрстка не поехала.

### Выпустить версию

Когда все issues milestone готовы и проверены на стенде:

**1. Влить `dev` в `main`.**

```bash
gh pr create --base main --head dev --title "v0.5 — Weak topics" --body "Closes #6"
```

Фраза `Closes #N` закроет issue после merge. Если issues закрываются отдельно, достаточно перечислить их в теле PR.

**2. Закрыть milestone** — на странице milestones или командой:

```bash
gh api -X PATCH repos/ZinChen/devquiz/milestones/4 -f state=closed
```

Дальше всё автоматически: workflow [milestone-release.yml](.github/workflows/milestone-release.yml) создаёт тег и GitHub Release со списком закрытых issue.

Порядок важен: релиз создаётся от `main` (`--target main`), поэтому milestone закрывают **после** вливания, иначе тег встанет на код без этой работы.

### Про версии

Номер версии живёт только в названии milestone, git-теге и GitHub Release — в коде его нет, поднимать вручную ничего не нужно.

Название milestone задаётся как `vX.Y — Описание` (например, `v0.5 — Weak topics`). Тегом становится версия из начала строки: `v0.5`. Остальное уходит в заголовок релиза, потому что пробелы и тире в имени git-тега недопустимы.

Если заголовок milestone не начинается с версии, workflow просто ничего не делает — релиз придётся создать руками.

Настройка сервера и эксплуатация — [deploy/README.md](deploy/README.md).
