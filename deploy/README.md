# Деплой на VDS

Продакшен и стенд живут на одном сервере: `devquiz.zinchenlab.ru` и
`dev.devquiz.zinchenlab.ru`. Образы собирает GitHub Actions и кладёт в ghcr,
сервер их только скачивает — на 2 ГБ RAM собирать нечем.

## Что где лежит

```
/opt/devquiz/
├── repo/     git clone, CI обновляет из main
├── dc        обёртка над docker compose
├── .env      секреты, права 600, вне git
└── backups/  ночные дампы
```

`.env` и `backups/` намеренно вне клона: CI делает `git reset --hard`, и всё
внутри `repo/` может быть перезаписано в любой момент.

## Состав стека

| Сервис | Что делает |
|---|---|
| `caddy` | TLS для обоих доменов, сертификаты Let's Encrypt автоматом |
| `db` | один Postgres, внутри базы `devquiz_production` и `devquiz_dev` с разными ролями |
| `app` | прод, образ `:latest`, ветка `main` |
| `app-dev` | стенд, образ `:dev`, ветка `dev` |

Postgres наружу не публикуется. Caddy занимает 80 и 443.

---

# Первичная настройка

## 1. DNS

До всего остального. Обе A-записи на IP сервера:

```
devquiz.zinchenlab.ru      A  <IP>
dev.devquiz.zinchenlab.ru  A  <IP>
```

Проверить: `dig +short devquiz.zinchenlab.ru` — должен вернуть IP сервера.
Caddy не выпустит сертификат, пока домен не резолвится сюда.

## 2. Настройка сервера

Под root на свежей Ubuntu 24.04:

```bash
curl -fsSL https://raw.githubusercontent.com/ZinChen/devquiz/main/deploy/setup-server.sh -o /root/setup-server.sh
bash /root/setup-server.sh
```

Скрипт идемпотентный, повторный запуск безопасен. Создаёт пользователя
`deploy` (имя можно передать аргументом) с passwordless `sudo` (ключ — уже
единственный фактор для входа, второй пароль поверх него ничего не защищает,
только мешает), отключает вход по паролю и под root, поднимает ufw на
22/80/443, fail2ban, автообновления, 4 ГБ swap, ставит Docker, клонирует
репозиторий, ставит `dc`, заводит `.env` из шаблона и прописывает cron для
бэкапов и очистки образов.

Проверить результат:

```bash
id deploy                       # группы sudo и docker
ls -la /opt/devquiz             # repo/, dc, .env, backups/
docker --version
ufw status
swapon --show
```

**Не закрывай root-сессию, пока не проверишь вход под `deploy`** — вход по
паролю уже отключён, и при ошибке в ключах обратно не попасть.

Скрипт копирует `authorized_keys` из root, так что текущий ключ работает сразу:

```bash
ssh deploy@<IP> "docker ps && ls /opt/devquiz"
```

Если `docker ps` ругается на права — перелогинься, членство в группе
применяется только к новым сессиям.

**Если сервер настраивался скриптом до этой правки** (`sudo` без строки про
passwordless в выводе) — `deploy` создан без пароля, но и без права выполнять
`sudo` без пароля: команда просто зависает на `[sudo] password for deploy:`,
которого не существует. Чинится один раз через веб-консоль провайдера
(root-доступ туда не завязан на SSH-ограничения):

```bash
echo "deploy ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-deploy
chmod 440 /etc/sudoers.d/90-deploy
visudo -cf /etc/sudoers.d/90-deploy    # должно вывести "parsed OK"
```

## 3. Ключ для CI

Отдельная пара, не личный ключ: секрет доступен любому workflow репозитория.

```bash
ssh-keygen -t ed25519 -C "github-actions-devquiz" -f ~/.ssh/devquiz_deploy -N ""
ssh-copy-id -i ~/.ssh/devquiz_deploy.pub deploy@<IP>
ssh -i ~/.ssh/devquiz_deploy deploy@<IP> "docker ps && echo OK"
```

Последняя команда — критерий готовности. Вывела `OK` без запроса пароля,
значит Actions зайдёт так же.

Если `Permission denied (publickey)`: проверь права на сервере — `~/.ssh`
должен быть `700`, `authorized_keys` — `600`.

## 4. Секреты в GitHub

Settings → Secrets and variables → **Actions** (не Deploy keys — те про доступ
*к* репозиторию, а нам нужен доступ *на сервер*):

| Секрет | Значение |
|---|---|
| `VDS_HOST` | IP сервера |
| `VDS_USER` | `deploy` |
| `VDS_SSH_KEY` | весь файл `~/.ssh/devquiz_deploy` |

Ключ копировать целиком, вместе со строками `BEGIN`/`END` и переводом строки
в конце — обрезанный даёт невнятное `ssh: handshake failed`:

```bash
pbcopy < ~/.ssh/devquiz_deploy
```

Это файл **без** `.pub`.

Старый `RENDER_DEPLOY_HOOK_URL` можно удалить.

## 5. OAuth-приложения

**GitHub** — нужны два приложения, у OAuth App ровно один callback URL:

- прод: `https://devquiz.zinchenlab.ru/auth/github/callback`
- стенд: `https://dev.devquiz.zinchenlab.ru/auth/github/callback`

**Google** — одного клиента достаточно, несколько redirect URI разрешены.
Оба адреса в Authorized redirect URIs, домен в Authorized domains.

## 6. Заполнить `.env`

```bash
ssh deploy@<IP>
nano /opt/devquiz/.env
```

Шаблон с комментариями — `repo/deploy/env.example`. Генерация значений:

```bash
openssl rand -hex 32   # POSTGRES_PASSWORD, DEV_DB_PASSWORD
openssl rand -hex 64   # SECRET_KEY_BASE, DEV_SECRET_KEY_BASE
```

`SECRET_KEY_BASE` и `DEV_SECRET_KEY_BASE` **обязаны различаться**: при
совпадении сессионная кука со стенда будет валидна на проде.

Пароли базы читаются init-скриптом только при первом создании volume.
Менять их позже — только через `ALTER ROLE` вручную.

## 7. Первый запуск

Важно: CI деплоит **точечно** — `./dc up -d app` при пуше в `main`,
`./dc up -d app-dev` при пуше в `dev` (см. «Как выкатывается код» ниже). Он
никогда не создаёт `caddy` и `db` сам, потому что не должен трогать сервисы,
не относящиеся к запушенной ветке. Значит первый раз их поднять нужно вручную
— иначе после успешного CI-деплоя `app` будет healthy, а сайт снаружи не
откроется вообще (порты 80/443 никто не слушает).

Порядок:

1. Дождаться, чтобы CI хотя бы раз прошёл на `main` (образ `:latest` в ghcr).

2. На сервере поднять всё разом:

   ```bash
   cd /opt/devquiz && ./dc up -d
   ```

   Если образа `:dev` ещё нет (в `dev` ещё не пушили) — команда упадёт на
   `app-dev` с `failed to resolve reference ...:dev: not found` и не поднимет
   вообще ничего, включая `caddy`. В этом случае поднять явно без `app-dev`:

   ```bash
   ./dc up -d caddy db app
   ```

   и добавить `app-dev` позже, когда появится образ `:dev` (после первого
   пуша в `dev` — CI сам его задеплоит, либо `./dc up -d app-dev` вручную).

Проверить:

```bash
./dc ps                              # все нужные сервисы healthy
./dc logs caddy --tail=50            # выпуск сертификата
curl -I https://devquiz.zinchenlab.ru
curl -I https://dev.devquiz.zinchenlab.ru
```

После этого разового шага дальнейшие пуши в `main`/`dev` уже ничего руками
поднимать не требуют — `caddy` и `db` продолжают работать, CI обновляет
только `app`/`app-dev`.

---

# Повседневное

`dc` — это `docker compose` с подставленными путями и `--env-file`:

```bash
cd /opt/devquiz
./dc ps                          # состояние
./dc logs -f app                 # логи прода
./dc logs -f app-dev             # логи стенда
./dc exec app ./bin/rails console
./dc restart app
./dc down                        # остановить всё (volumes целы)
```

## Как выкатывается код

Пуш в `main` → CI собирает `:latest` → `git reset --hard` в `repo/` →
`./dc pull app` → `./dc up -d app`. Стенд не затрагивается.

Пуш в `dev` → образ `:dev` → обновляется только `app-dev`. Конфиги стека
из ветки `dev` **не применяются** — `git reset` выполняется только для `main`,
иначе правка compose в дев-ветке переформатировала бы прод.

Контент квизов лежит внутри образа, поэтому правка YAML тоже требует
пересборки. При старте контейнера `bin/docker-entrypoint` выполняет
`db:prepare` и `yaml_sync:sync_all` — миграции и синхронизация контента идут
автоматически.

Пересинхронизировать контент принудительно:

```bash
./dc exec app ./bin/rails yaml_sync:force_sync
```

## Бэкапы

Cron каждую ночь в 03:17 делает `pg_dumpall` обеих баз в
`/opt/devquiz/backups`, хранит 14 дней. Лог — `backups/backup.log`.

Дампы лежат на том же диске, что и база: от случайного `DROP` спасут, от
потери сервера — нет. Стоит настроить выгрузку наружу (rclone в объектное
хранилище или `scp` на домашнюю машину) и хотя бы раз проверить
восстановление — непроверенный бэкап это не бэкап.

Восстановление:

```bash
gunzip -c backups/devquiz-2026-08-07.sql.gz | ./dc exec -T db psql -U devquiz -d postgres
```

---

# Если что-то не работает

**Сайт не открывается снаружи, хотя `app` healthy.** Почти всегда значит, что
`caddy` вообще не создан — `./dc ps` его не покажет. CI поднимает только тот
сервис, что относится к запушенной ветке, и никогда не трогает `caddy`/`db`
сам. Смотри «7. Первый запуск» — нужно один раз выполнить `./dc up -d` (или
`./dc up -d caddy db app`, если образа `:dev` ещё нет) вручную.

**`sudo` под `deploy` виснет на запросе пароля, которого нет.** Сервер
настраивался версией `setup-server.sh` без passwordless `sudo`. Чинится один
раз через веб-консоль провайдера — команды в «2. Настройка сервера».

**Caddy не выпускает сертификат.** Проверь DNS (`dig +short <домен>`) и что
80 порт свободен. Логи: `./dc logs caddy`. Let's Encrypt имеет лимит на
повторные запросы — сертификаты лежат в volume `caddy_data` и переживают
рестарт, специально чтобы в него не упереться.

**`app` перезапускается по кругу.** `./dc logs app`. Обычно `.env` заполнен
не полностью или `DATABASE_URL` расходится с `POSTGRES_*`.

**Бесконечный редирект.** Признак того, что `ASSUME_SSL` не выставлен: Caddy
идёт к Rails по http, а `force_ssl` гонит обратно на https. В compose
переменная задана обоим приложениям.

**Нет базы `devquiz_dev`.** Init-скрипт Postgres отрабатывает только при
первом создании volume. Если стек поднимался до заполнения `.env`, создай
роль и базу вручную по образцу `init-db/10-create-dev-database.sh` — либо
`./dc down -v` и заново, но это **сотрёт все данные**.

**Кончилось место.** `docker system prune -af` (еженедельный cron уже стоит).
Проверить: `df -h`, `docker system df`.

**Не хватает памяти.** `docker stats` покажет реальное потребление. Лимиты
заданы в `compose.yaml`; прод работает на одном Puma-воркере, стенд тоже —
на 1 vCPU второй воркер не даёт параллелизма, а память ест.
