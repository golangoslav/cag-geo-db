# geo_db — База данных географии офисов

## Обзор

`geo_db` — это пространственная база данных CAG Ecosystem, хранящая всю информацию об офисах обмена валют (как официальных офисах Cash&Go, так и партнёрских). Она использует расширение PostGIS для эффективных запросов географической близости, позволяя клиентам найти ближайший пункт обмена от их текущего местоположения.

База данных выполняет две основные роли:

1. **Каталог офисов**: Постоянное хранилище всех метаданных офисов — название, адрес, контактные данные, часы работы, интеграция с Google Maps.
2. **Геопространственные запросы**: Эффективный поиск офисов по радиусу с использованием типов геометрии PostGIS и пространственных индексов, возвращающий результаты, упорядоченные по реальному расстоянию в километрах.

---

## Сервисы, использующие эту БД

| Сервис | Паттерн доступа |
|---|---|
| `geo-service` (порт 8082) | Основной владелец — полное чтение/запись, использует все таблицы и функции |
| `office-service` (порт 8090) | Чтение/запись — также подключается к geo_db для управления офисами |
| `transaction-service` (порт 8084) | Только чтение (через currency_cache) — UUID офисов хранятся в инвойсах как внешние ключи без принудительного FK |
| `crm-requests-service` (порт 8086) | Ссылки только для чтения — ID офисов хранятся в инвойсах |

---

## Расширения PostgreSQL

| Расширение | Версия | Назначение |
|---|---|---|
| `uuid-ossp` | — | Функции генерации UUID (`uuid_generate_v4`, `uuid_generate_v5`) |
| `postgis` | 3.4 (postgis/postgis:16-3.4-alpine) | Пространственные типы данных, операции с геометрией, расчёт расстояний |

---

## Таблицы

### `office_types`

Справочная таблица категорий офисов.

| Столбец | Тип | Ограничения | Описание |
|---|---|---|---|
| `type_id` | UUID | PK, DEFAULT uuid_generate_v4() | Уникальный идентификатор |
| `type_code` | VARCHAR(50) | UNIQUE NOT NULL | Короткий код, напр. `cag`, `partner` |
| `type_name` | VARCHAR(100) | NOT NULL | Человекочитаемое название, напр. `Cash & Go` |
| `description` | TEXT | — | Необязательное описание |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Временная метка создания |

**Начальные данные** (миграция 009): Два детерминированных типа с использованием UUID v5:
- `cag` — Официальные офисы Cash&Go
- `partner` — Партнёрские обменные пункты

---

### `offices`

Основная таблица, хранящая все записи обменных пунктов с полными географическими данными.

| Столбец | Тип | Ограничения | Описание |
|---|---|---|---|
| `office_id` | UUID | PK, DEFAULT uuid_generate_v4() | Уникальный идентификатор |
| `office_name` | TEXT | NOT NULL | Отображаемое название офиса |
| `office_type_id` | UUID | NOT NULL, FK → office_types(type_id) ON DELETE RESTRICT | Ссылка на категорию офиса |
| `country` | VARCHAR(100) | NOT NULL | Название страны |
| `city` | VARCHAR(100) | NOT NULL | Название города |
| `address` | TEXT | NOT NULL | Полный адрес |
| `contact_info` | TEXT | — | Имя контактного лица |
| `tg_info` | BIGINT | CHECK (> 0 OR NULL) | ID пользователя Telegram контактного лица |
| `phone_number` | VARCHAR(50) | CHECK (соответствует регулярному выражению телефона OR NULL) | Контактный телефон |
| `location` | GEOMETRY(Point, 4326) | — | Точечная геометрия PostGIS (автоматически заполняется из lat/lon триггером) |
| `latitude` | DECIMAL(10,8) | CHECK (от -90 до 90) | Широта в десятичных градусах |
| `longitude` | DECIMAL(11,8) | CHECK (от -180 до 180) | Долгота в десятичных градусах |
| `google_place_id` | VARCHAR(255) | — | ID места из Google Places API |
| `google_maps_url` | TEXT | — | Прямая ссылка на Google Maps |
| `google_rating` | DECIMAL(2,1) | CHECK (0–5 OR NULL) | Рейтинг Google |
| `google_user_total` | INTEGER | CHECK (>= 0 OR NULL) | Количество отзывов Google |
| `working_hours` | JSONB | — | Часы работы по дням, напр. `{"monday": "09:00-18:00", "saturday": "10:00-16:00"}` |
| `is_active` | BOOLEAN | DEFAULT true | Работает ли офис в данный момент |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Временная метка создания |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() | Последнее обновление (поддерживается триггером) |

**CHECK-ограничения:**
- `valid_latitude`: широта между -90 и 90
- `valid_longitude`: долгота между -180 и 180
- `valid_phone`: номер телефона соответствует `^[+]?[0-9\s\-\(\)]+$` или NULL
- `valid_tg_info`: tg_info > 0 или NULL
- `valid_google_rating`: google_rating между 0 и 5 или NULL
- `valid_google_user_total`: google_user_total >= 0 или NULL

**Внешние ключи:**
- `fk_office_type` → `office_types(type_id)` ON DELETE RESTRICT

**Индексы:**

| Индекс | Тип | Столбцы | Условие |
|---|---|---|---|
| `idx_offices_location` | GIST (пространственный) | `location` | — |
| `idx_offices_country` | BTREE | `country` | — |
| `idx_offices_city` | BTREE | `city` | — |
| `idx_offices_office_type_id` | BTREE | `office_type_id` | — |
| `idx_offices_active` | BTREE | `is_active` | — |
| `idx_offices_country_city` | BTREE | `(country, city)` | — |
| `idx_offices_google_place_id` | BTREE | `google_place_id` | WHERE NOT NULL |

---

## Функции и триггеры

### `update_location_from_coordinates()` — Триггерная функция

**Возвращает:** TRIGGER

**Описание:** Автоматически вычисляет столбец PostGIS `GEOMETRY(Point, 4326)` из `latitude` и `longitude` с помощью `ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)`. Выполняется BEFORE INSERT OR UPDATE OF latitude, longitude в таблице `offices`.

Это гарантирует, что столбец пространственного индекса `location` всегда синхронизирован с человекочитаемыми столбцами десятичных градусов. Выполняется только если и широта, и долгота не равны NULL.

**Триггер:** `update_office_location` — BEFORE INSERT OR UPDATE OF latitude, longitude ON offices, FOR EACH ROW.

---

### `update_updated_at_column()` — Триггерная функция

**Возвращает:** TRIGGER

**Описание:** Устанавливает `NEW.updated_at = CURRENT_TIMESTAMP` при каждом обновлении строки. Универсальная функция поддержки временных меток.

**Триггер:** `update_offices_updated_at` — BEFORE UPDATE ON offices, FOR EACH ROW.

---

### `find_nearest_offices(user_lat, user_lon, max_distance_km, limit_count)` — Функция запроса

**Параметры:**
- `user_lat DECIMAL` — Широта пользователя
- `user_lon DECIMAL` — Долгота пользователя
- `max_distance_km DECIMAL DEFAULT 50` — Максимальный радиус поиска в километрах
- `limit_count INTEGER DEFAULT 10` — Максимальное количество результатов

**Возвращает:** TABLE со столбцами: `office_id`, `office_name`, `office_type` (type_code), `country`, `city`, `address`, `contact_info`, `tg_info`, `phone_number`, `latitude`, `longitude`, `working_hours`, `google_place_id`, `google_maps_url`, `google_rating`, `google_user_total`, `is_active`, `created_at`, `updated_at`, `distance_km`

**Описание:** Основная функция поиска, используемая фичей Mini App "Найти ближайший офис". Выполняет пространственный запрос по радиусу с помощью `ST_DWithin` по типам географии (что автоматически учитывает кривизну Земли), затем присоединяет `office_types` для получения кода типа и вычисляет расстояние в километрах как округлённое значение NUMERIC. Результаты упорядочены по возрастанию расстояния и отфильтрованы только по `is_active = true`.

Функция использует приведение к типу географии (`::geography`) вместо геометрии для точных расчётов расстояний в реальном мире.

**Вызывается:** `geo-service` и `office-service` — основной эндпоинт поиска офисов.

---

## Начальные данные

Миграция 010 вставляет 6 примеров офисов по Таиланду:
- **Бангкок**: Cash&Go Bangkok Central, Partner Exchange Siam Square, Cash&Go Chatuchak
- **Пхукет**: Cash&Go Phuket Patong, Partner Exchange Phuket Town
- **Чиангмай**: Cash&Go Chiang Mai Old City

Все офисы используют UUID v5 для детерминированных ID, стабильных при пересоздании базы данных.

---

## История миграций

| Миграция | Описание |
|---|---|
| 001 | Подключение расширений `uuid-ossp` и `postgis` |
| 002 | Установка `search_path TO public` |
| 003 | Создание таблицы `office_types` |
| 004 | Создание таблицы `offices` со всеми столбцами и ограничениями |
| 005 | Создание индексов, включая пространственный GIST-индекс PostGIS |
| 006 | Создание функции `update_location_from_coordinates()` и триггера |
| 007 | Создание функции `update_updated_at_column()` и триггера |
| 008 | Создание функции поиска `find_nearest_offices()` |
| 009 | Вставка начальных типов офисов (`cag`, `partner`) с детерминированными UUID |
| 010 | Вставка 6 примеров офисов по Бангкоку, Пхукету, Чиангмаю |
| 011 | Добавление документации `COMMENT ON` для таблиц и столбцов |
