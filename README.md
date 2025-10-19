# Geo Database (geo_db)

База данных для хранения геолокационных данных офисов Cash&Go и партнёров. Использует PostGIS для spatial queries, поиска ближайших офисов, расчёта расстояний.

---

## 1. Экстеншены

### uuid-ossp
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

**Назначение:** Генерация UUID для первичных ключей

**Используемые функции:**
- `uuid_generate_v4()` - генерация случайного UUID v4
- `uuid_generate_v5(namespace, name)` - генерация детерминированного UUID v5 (для office_types)

---

### PostGIS
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

**Назначение:** Геопространственные типы данных и функции

**Используемые типы:**
- `GEOMETRY(Point, 4326)` - точка на карте (SRID 4326 = WGS84, используется GPS)
- `GEOGRAPHY` - для вычисления расстояний на сфере (Земля)

**Используемые функции:**
- `ST_MakePoint(longitude, latitude)` - создание точки из координат
- `ST_SetSRID(geometry, srid)` - установка Spatial Reference System ID
- `ST_Distance(geography1, geography2)` - расстояние в метрах на сфере
- `ST_DWithin(geography1, geography2, distance)` - проверка что расстояние < заданного

**SRID 4326:**
- WGS84 coordinate system
- Используется GPS и Google Maps
- Latitude: -90 to 90
- Longitude: -180 to 180

---

## 2. Паттерны проектирования

### Database Patterns

**PostGIS Spatial Pattern**
- `location GEOMETRY(Point, 4326)` - PostGIS тип для координат
- Автоматическая синхронизация с latitude/longitude через триггер
- GIST index для efficient spatial queries
- `::geography` cast для расстояний на сфере

**Dual Coordinate Storage Pattern**
- `location GEOMETRY(Point, 4326)` - для PostGIS queries
- `latitude DECIMAL(10,8)` + `longitude DECIMAL(11,8)` - для простого доступа
- Триггер синхронизирует: lat/lng → location
- **Benefits:** PostGIS для spatial queries, decimals для API responses

**Schema Separation Pattern**
- Dedicated schema `geo` для геоданных
- `SET search_path TO geo, public`
- Namespace isolation от других таблиц

**Office Type Pattern**
- Separate таблица `office_types` для типов офисов
- 2 типа: `cag` (Cash & Go official) и `partner`
- UUID v5 для стабильных IDs
- FK RESTRICT - нельзя удалить тип если есть офисы

**Trigger-Driven Sync Pattern**
- Триггер `update_office_location` автоматически обновляет `location` при изменении lat/lng
- INSERT/UPDATE → location пересчитывается
- Гарантирует consistency между lat/lng и PostGIS geometry

**JSONB Metadata Pattern**
- `working_hours JSONB` - гибкая структура для часов работы
- Example: `{"monday": {"open": "09:00", "close": "18:00"}}`
- Schema-less для разных форматов

**Soft Delete Pattern**
- `is_active BOOLEAN` для soft delete
- Неактивные офисы не показываются клиентам
- История сохраняется для audit

**CHECK Constraints Pattern**
- `valid_latitude` - lat between -90 and 90
- `valid_longitude` - lng between -180 and 180
- `valid_phone` - regex validation для телефонных номеров
- `valid_tg_info` - telegram_id > 0 или NULL

**Timestamp Pattern**
- `created_at` - дата создания (immutable)
- `updated_at` - автообновление через триггер

**Distance-Based Filtering Pattern**
- `find_nearest_offices()` использует `ST_DWithin()` для pre-filtering
- Только офисы в радиусе проверяются для distance calculation
- Оптимизация для больших датасетов

**Sphere-Based Distance Calculation**
- `::geography` cast для точных расстояний
- Учитывает кривизну Земли
- Более точно чем Euclidean distance

---

## 3. Переменные окружения

### Standard PostgreSQL Variables
Используются стандартные переменные PostgreSQL из `vault-entrypoint.sh`:

| Переменная | Описание |
|------------|----------|
| `POSTGRES_USER` | Пользователь БД |
| `POSTGRES_PASSWORD` | Пароль БД |
| `POSTGRES_DB` | Имя БД (geo_db) |
| `POSTGRES_HOST` | Хост PostgreSQL (для клиентов) |
| `POSTGRES_PORT` | Порт PostgreSQL (5432) |
| `POSTGRES_SSLMODE` | SSL режим (disable/require) |

### Vault Integration
Переменные загружаются из HashiCorp Vault через `vault-entrypoint.sh`:

**Vault Path:**
- `secret/data/cag/shared/credentials/geo_db`

**Container Variables:**
- `VAULT_ADDR` - URL HashiCorp Vault
- `VAULT_TOKEN` - токен для доступа к Vault

---

## 4. Таблицы и данные

### Schema: geo

Все таблицы находятся в схеме `geo`:
- `geo.office_types`
- `geo.offices`

---

### geo.office_types
**Описание:** Типы офисов (Cash & Go official vs Partner)

**Структура:**
```sql
type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4()
type_code VARCHAR(50) UNIQUE NOT NULL
type_name VARCHAR(100) NOT NULL
description TEXT
created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
```

**Хранимые данные (предзаполненные):**

| type_code | type_name | description |
|-----------|-----------|-------------|
| `cag` | Cash & Go | Official Cash & Go office |
| `partner` | Partner | Partner exchange office |

**UUID v5 IDs:**
- Генерируются детерминированно: `uuid_generate_v5(uuid_ns_oid(), 'cag')`
- Стабильные IDs при пересоздании БД

**Constraints:**
- type_code UNIQUE

---

### geo.offices
**Описание:** Офисы Cash&Go и партнёрские для обмена валют

**Структура:**
```sql
office_id UUID PRIMARY KEY DEFAULT uuid_generate_v4()
office_name TEXT NOT NULL
office_type_id UUID NOT NULL REFERENCES office_types(type_id)
country VARCHAR(100) NOT NULL
city VARCHAR(100) NOT NULL
address TEXT NOT NULL
contact_info TEXT
tg_info BIGINT
phone_number VARCHAR(50)

-- PostGIS geometry
location GEOMETRY(Point, 4326)

-- Duplicate as decimals
latitude DECIMAL(10, 8)
longitude DECIMAL(11, 8)

working_hours JSONB
is_active BOOLEAN DEFAULT TRUE
created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

-- Constraints
CONSTRAINT valid_latitude CHECK (latitude >= -90 AND latitude <= 90)
CONSTRAINT valid_longitude CHECK (longitude >= -180 AND longitude <= 180)
CONSTRAINT valid_phone CHECK (phone_number ~ '^[+]?[0-9\s\-\(\)]+$' OR phone_number IS NULL)
CONSTRAINT valid_tg_info CHECK (tg_info > 0 OR tg_info IS NULL)
CONSTRAINT fk_office_type FOREIGN KEY (office_type_id) REFERENCES office_types(type_id) ON DELETE RESTRICT
```

**Хранимые данные:**
- `office_name` - название офиса (Bangkok Central, Pattaya Beach)
- `office_type_id` - тип офиса (cag или partner)
- `country` - страна
- `city` - город
- `address` - полный адрес
- `contact_info` - контактная информация
- `tg_info` - Telegram ID офиса
- `phone_number` - телефон офиса
- `location` - **PostGIS Point** (автоматически из lat/lng)
- `latitude` - широта (-90 to 90)
- `longitude` - долгота (-180 to 180)
- `working_hours` - JSONB с расписанием
- `is_active` - активен ли офис

**Working Hours Format:**
```json
{
  "monday": {"open": "09:00", "close": "18:00"},
  "tuesday": {"open": "09:00", "close": "18:00"},
  "saturday": {"open": "10:00", "close": "16:00"},
  "sunday": "closed"
}
```

**Индексы:**
- `idx_offices_location` - **GIST index** на location (для spatial queries)
- `idx_offices_country` - на country
- `idx_offices_city` - на city
- `idx_offices_office_type_id` - на office_type_id
- `idx_offices_active` - на is_active
- `idx_offices_country_city` - composite index

**Триггеры:**
- `update_office_location` - автосинхронизация lat/lng → location
- `update_offices_updated_at` - auto updated_at

**CHECK Constraints:**
- Latitude validation (-90 to 90)
- Longitude validation (-180 to 180)
- Phone regex validation
- Telegram ID > 0

---

## 5. Функции и триггеры

### Функции

#### find_nearest_offices(user_lat, user_lon, max_distance_km, limit_count)
**Тип:** TABLE-RETURNING FUNCTION

**Назначение:** Найти ближайшие офисы к координатам пользователя

**Параметры:**
- `user_lat DECIMAL` - широта пользователя
- `user_lon DECIMAL` - долгота пользователя
- `max_distance_km DECIMAL` - максимальный радиус поиска (default 50 km)
- `limit_count INTEGER` - максимальное количество результатов (default 10)

**Возвращает:**
```sql
office_id UUID
office_name TEXT
office_type TEXT (type_code)
country VARCHAR
city VARCHAR
address TEXT
distance_km DECIMAL
```

**Алгоритм:**
1. Создаёт Point из user coordinates: `ST_MakePoint(user_lon, user_lat)`
2. Устанавливает SRID 4326: `ST_SetSRID(..., 4326)`
3. Cast to geography для sphere distance: `::geography`
4. Фильтр с `ST_DWithin()` - только офисы в радиусе (оптимизация)
5. Вычисляет distance с `ST_Distance()` в метрах
6. Конвертирует в километры: `/ 1000`
7. Округляет до 2 знаков: `ROUND(..., 2)`
8. Сортирует по distance ASC
9. LIMIT для ограничения результатов

**PostGIS Functions:**
- `ST_MakePoint(lon, lat)` - создание точки (NOTE: lon first!)
- `ST_SetSRID(geom, 4326)` - установка coordinate system
- `ST_DWithin(geog1, geog2, meters)` - проверка расстояния (uses GIST index)
- `ST_Distance(geog1, geog2)` - точное расстояние в метрах

**Performance:**
- GIST index на `location` используется для `ST_DWithin`
- Pre-filtering reduces candidates перед distance calculation
- Efficient для больших датасетов

---

#### update_location_from_coordinates()
**Тип:** TRIGGER FUNCTION

**Назначение:** Автоматическая синхронизация latitude/longitude → location

**Триггер:** `update_office_location` BEFORE INSERT OR UPDATE OF latitude, longitude ON offices

**Логика:**
```sql
IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
END IF;
```

**Гарантирует:** location всегда синхронизирован с lat/lng

---

#### update_updated_at_column()
**Тип:** TRIGGER FUNCTION

**Назначение:** Автоматическое обновление updated_at timestamp

**Триггер:** `update_offices_updated_at` BEFORE UPDATE ON offices

**Логика:**
```sql
NEW.updated_at = CURRENT_TIMESTAMP;
```

---

### Триггеры Summary

| Триггер | Таблица | Событие | Функция | Назначение |
|---------|---------|---------|---------|------------|
| update_office_location | offices | BEFORE INSERT/UPDATE (lat/lng) | update_location_from_coordinates() | Auto sync lat/lng → location |
| update_offices_updated_at | offices | BEFORE UPDATE | update_updated_at_column() | Auto updated_at |

---

## PostGIS Concepts

### Coordinate System (SRID 4326)
- **SRID:** Spatial Reference System Identifier
- **4326:** WGS84 (World Geodetic System 1984)
- Используется GPS, Google Maps, OpenStreetMap
- Longitude: -180 to 180 (East/West)
- Latitude: -90 to 90 (North/South)

### GEOMETRY vs GEOGRAPHY
- **GEOMETRY:** Flat 2D plane (faster, less accurate для больших расстояний)
- **GEOGRAPHY:** Sphere (Earth surface, точные расстояния, медленнее)
- **Usage:** Храним как GEOMETRY, cast to GEOGRAPHY для distance calculations

### GIST Index
- **GiST:** Generalized Search Tree
- Специализированный index для spatial data
- Allows для efficient queries:
  - `ST_DWithin()` - поиск в радиусе
  - `ST_Intersects()` - пересечение
  - `ST_Contains()` - содержание
- **Critical** для производительности spatial queries

---

## Используется сервисами

### geo-service
**Port:** 8082

**Операции:**
- `SELECT` - GetAll offices (WHERE is_active = TRUE)
- `SELECT` - GetByID
- `SELECT` - GetByCity
- `SELECT` - find_nearest_offices() функция

**Назначение:** Public read-only API для клиентов (Telegram Mini App)

---

### office-service
**Port:** 8090

**Операции:**
- `SELECT` - GetAll offices (including inactive)
- `INSERT` - Create office
- `UPDATE` - Update office (partial updates)
- `DELETE` - Soft delete (SET is_active = FALSE)

**Назначение:** CRUD operations для CRM менеджеров (owner/prime/supervisor only)

---

## Shared Database

**Important:** geo_db **shared** между двумя сервисами:
- `geo-service` (backend-services) - read-only для клиентов
- `office-service` (crm-backend-services) - full CRUD для CRM

**Benefits:**
- Single source of truth для офисов
- Нет дублирования данных
- Consistent геоданные

---

## Примеры использования

### Найти ближайшие офисы
```sql
-- Найти 5 ближайших офисов в радиусе 20 км от точки
SELECT * FROM geo.find_nearest_offices(
  13.7563,  -- Bangkok latitude
  100.5018, -- Bangkok longitude
  20,       -- max 20 km
  5         -- limit 5 results
);

-- Returns:
-- office_id | office_name | office_type | country | city | address | distance_km
-- uuid1     | Bangkok Cen | cag         | Thailand| BKK  | 123...  | 2.5
-- uuid2     | Sukhumvit   | partner     | Thailand| BKK  | 456...  | 5.8
```

### Создать офис (office-service)
```sql
INSERT INTO geo.offices (
  office_name,
  office_type_id,
  country,
  city,
  address,
  phone_number,
  latitude,
  longitude,
  working_hours
)
VALUES (
  'Bangkok Central',
  (SELECT type_id FROM geo.office_types WHERE type_code = 'cag'),
  'Thailand',
  'Bangkok',
  '123 Sukhumvit Road',
  '+66123456789',
  13.7563,
  100.5018,
  '{"monday": {"open": "09:00", "close": "18:00"}}'::jsonb
);

-- Триггер автоматически создаст location GEOMETRY(Point)
```

### Получить активные офисы в городе
```sql
SELECT
  o.office_id,
  o.office_name,
  ot.type_code,
  o.address,
  o.latitude,
  o.longitude,
  o.phone_number
FROM geo.offices o
JOIN geo.office_types ot ON o.office_type_id = ot.type_id
WHERE o.city = 'Bangkok'
  AND o.is_active = TRUE
ORDER BY o.office_name;
```

### Обновить координаты (location пересчитается автоматически)
```sql
UPDATE geo.offices
SET latitude = 13.7600,
    longitude = 100.5100
WHERE office_id = 'uuid';

-- Триггер update_office_location автоматически обновит location GEOMETRY
```

### Проверка расстояния между офисами
```sql
SELECT
  o1.office_name as office1,
  o2.office_name as office2,
  ROUND(
    ST_Distance(o1.location::geography, o2.location::geography) / 1000,
    2
  ) as distance_km
FROM geo.offices o1
CROSS JOIN geo.offices o2
WHERE o1.office_id < o2.office_id  -- Avoid duplicates and self-comparison
  AND o1.city = 'Bangkok'
  AND o2.city = 'Bangkok'
ORDER BY distance_km;
```

---

## Docker

### Image
```dockerfile
FROM postgres:16-alpine
```

### Extensions Required
- postgis (требует компиляции C extensions)
- uuid-ossp (стандартный)

### Build
```bash
docker build -t cag-geo-db databases/geo/
```

### Run
```bash
docker-compose up cag-geo-db
```

---

## Performance Considerations

### GIST Index
- **Critical** для spatial queries
- Without GIST: O(n) scan всех офисов
- With GIST: O(log n) spatial lookup

### ST_DWithin Pre-filtering
- Фильтрует офисы ДО вычисления distance
- Использует GIST index
- Значительно быстрее чем `ORDER BY ST_Distance() LIMIT N`

### Geography Cast
- `::geography` конвертация для sphere distance
- Точнее чем flat geometry
- Медленнее, но acceptable для небольших датасетов (офисов)

---

## Security Notes

- ✅ CHECK constraints для validation координат
- ✅ Regex validation для phone numbers
- ✅ FK RESTRICT на office_types (защита integrity)
- ✅ Soft delete через is_active
- ✅ UNIQUE type_code для office_types
- ✅ Schema isolation (geo namespace)

---

## Spatial Query Examples

### Офисы в радиусе 10 км
```sql
SELECT
  office_name,
  ROUND(
    ST_Distance(
      location::geography,
      ST_SetSRID(ST_MakePoint(100.5018, 13.7563), 4326)::geography
    ) / 1000,
    2
  ) as distance_km
FROM geo.offices
WHERE ST_DWithin(
  location::geography,
  ST_SetSRID(ST_MakePoint(100.5018, 13.7563), 4326)::geography,
  10000  -- 10 km in meters
)
AND is_active = TRUE
ORDER BY distance_km;
```

### Офисы в прямоугольной области (bounding box)
```sql
SELECT *
FROM geo.offices
WHERE ST_Within(
  location,
  ST_MakeEnvelope(
    100.0, 13.0,  -- min lon, min lat
    101.0, 14.0,  -- max lon, max lat
    4326
  )
)
AND is_active = TRUE;
```

---

## Migration Notes

База данных stable, основная структура не менялась после initial migrations.

Добавления в будущем могут включать:
- Поддержку polygons для delivery zones
- Routing integration с OSM
- Geocoding integration
