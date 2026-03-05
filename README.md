# geo_db — Geographic Office Database

## Overview

`geo_db` is the spatial database for the CAG Ecosystem, storing all information about currency exchange offices (both official Cash&Go offices and partner offices). It uses the PostGIS extension for efficient geographic proximity queries, enabling clients to find the nearest exchange office from their current location.

The database serves two primary roles:

1. **Office Catalog**: Persistent storage for all office metadata — name, address, contact details, working hours, Google Maps integration.
2. **Geospatial Queries**: Efficient radius-based office lookup using PostGIS geometry types and spatial indexes, returning results ordered by real-world distance in kilometers.

---

## Services That Use This DB

| Service | Access Pattern |
|---|---|
| `geo-service` (port 8082) | Primary owner — full read/write, uses all tables and functions |
| `office-service` (port 8090) | Read/write — also connects to geo_db for office management |
| `transaction-service` (port 8084) | Read-only (via currency_cache) — office UUIDs stored in invoices as foreign keys without enforced FK |
| `crm-requests-service` (port 8086) | Read-only references — office IDs stored in invoices |

---

## PostgreSQL Extensions

| Extension | Version | Purpose |
|---|---|---|
| `uuid-ossp` | — | UUID generation functions (`uuid_generate_v4`, `uuid_generate_v5`) |
| `postgis` | 3.4 (postgis/postgis:16-3.4-alpine) | Spatial data types, geometry operations, distance calculations |

---

## Tables

### `office_types`

Lookup table for office categories.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `type_id` | UUID | PK, DEFAULT uuid_generate_v4() | Unique identifier |
| `type_code` | VARCHAR(50) | UNIQUE NOT NULL | Short code, e.g. `cag`, `partner` |
| `type_name` | VARCHAR(100) | NOT NULL | Human-readable name, e.g. `Cash & Go` |
| `description` | TEXT | — | Optional description |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Creation timestamp |

**Seed data** (migration 009): Two deterministic types using UUID v5:
- `cag` — Official Cash&Go offices
- `partner` — Partner exchange offices

---

### `offices`

The main table storing all exchange office records with full geographic data.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `office_id` | UUID | PK, DEFAULT uuid_generate_v4() | Unique identifier |
| `office_name` | TEXT | NOT NULL | Display name of the office |
| `office_type_id` | UUID | NOT NULL, FK → office_types(type_id) ON DELETE RESTRICT | Office category reference |
| `country` | VARCHAR(100) | NOT NULL | Country name |
| `city` | VARCHAR(100) | NOT NULL | City name |
| `address` | TEXT | NOT NULL | Full street address |
| `contact_info` | TEXT | — | Contact person name |
| `tg_info` | BIGINT | CHECK (> 0 OR NULL) | Telegram user ID for the contact person |
| `phone_number` | VARCHAR(50) | CHECK (matches phone regex OR NULL) | Contact phone |
| `location` | GEOMETRY(Point, 4326) | — | PostGIS point geometry (auto-populated from lat/lon by trigger) |
| `latitude` | DECIMAL(10,8) | CHECK (−90 to 90) | Latitude in decimal degrees |
| `longitude` | DECIMAL(11,8) | CHECK (−180 to 180) | Longitude in decimal degrees |
| `google_place_id` | VARCHAR(255) | — | Google Places API place ID |
| `google_maps_url` | TEXT | — | Direct Google Maps URL |
| `google_rating` | DECIMAL(2,1) | CHECK (0–5 OR NULL) | Google rating |
| `google_user_total` | INTEGER | CHECK (≥ 0 OR NULL) | Number of Google reviews |
| `working_hours` | JSONB | — | Working hours by day, e.g. `{"monday": "09:00-18:00", "saturday": "10:00-16:00"}` |
| `is_active` | BOOLEAN | DEFAULT true | Whether office is currently operational |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() | Last update (maintained by trigger) |

**CHECK constraints:**
- `valid_latitude`: latitude between −90 and 90
- `valid_longitude`: longitude between −180 and 180
- `valid_phone`: phone number matches `^[+]?[0-9\s\-\(\)]+$` or is NULL
- `valid_tg_info`: tg_info > 0 or NULL
- `valid_google_rating`: google_rating between 0 and 5 or NULL
- `valid_google_user_total`: google_user_total >= 0 or NULL

**Foreign keys:**
- `fk_office_type` → `office_types(type_id)` ON DELETE RESTRICT

**Indexes:**

| Index | Type | Columns | Condition |
|---|---|---|---|
| `idx_offices_location` | GIST (spatial) | `location` | — |
| `idx_offices_country` | BTREE | `country` | — |
| `idx_offices_city` | BTREE | `city` | — |
| `idx_offices_office_type_id` | BTREE | `office_type_id` | — |
| `idx_offices_active` | BTREE | `is_active` | — |
| `idx_offices_country_city` | BTREE | `(country, city)` | — |
| `idx_offices_google_place_id` | BTREE | `google_place_id` | WHERE NOT NULL |

---

## Functions and Triggers

### `update_location_from_coordinates()` — Trigger Function

**Returns:** TRIGGER

**Description:** Automatically computes the PostGIS `GEOMETRY(Point, 4326)` column from `latitude` and `longitude` using `ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)`. Runs BEFORE INSERT OR UPDATE OF latitude, longitude on the `offices` table.

This ensures the spatial index column `location` is always synchronized with the human-readable decimal degree columns. Only runs if both latitude and longitude are non-null.

**Trigger:** `update_office_location` — BEFORE INSERT OR UPDATE OF latitude, longitude ON offices, FOR EACH ROW.

---

### `update_updated_at_column()` — Trigger Function

**Returns:** TRIGGER

**Description:** Sets `NEW.updated_at = CURRENT_TIMESTAMP` on every row update. Generic timestamp maintenance function.

**Trigger:** `update_offices_updated_at` — BEFORE UPDATE ON offices, FOR EACH ROW.

---

### `find_nearest_offices(user_lat, user_lon, max_distance_km, limit_count)` — Query Function

**Parameters:**
- `user_lat DECIMAL` — User's latitude
- `user_lon DECIMAL` — User's longitude
- `max_distance_km DECIMAL DEFAULT 50` — Maximum search radius in kilometers
- `limit_count INTEGER DEFAULT 10` — Maximum number of results

**Returns:** TABLE with columns: `office_id`, `office_name`, `office_type` (type_code), `country`, `city`, `address`, `contact_info`, `tg_info`, `phone_number`, `latitude`, `longitude`, `working_hours`, `google_place_id`, `google_maps_url`, `google_rating`, `google_user_total`, `is_active`, `created_at`, `updated_at`, `distance_km`

**Description:** The primary search function used by the Mini App "Find nearest office" feature. Performs a spatial radius query using `ST_DWithin` on geography types (which automatically handles Earth curvature), then joins to `office_types` for the type code, and computes the distance in kilometers as a rounded NUMERIC value. Results are ordered by distance ascending and filtered to `is_active = true` only.

The function uses the geography type cast (`::geography`) rather than geometry for accurate real-world distance calculations.

**Called by:** `geo-service` and `office-service` — the primary office search endpoint.

---

## Seed Data

Migration 010 inserts 6 sample offices across Thailand:
- **Bangkok**: Cash&Go Bangkok Central, Partner Exchange Siam Square, Cash&Go Chatuchak
- **Phuket**: Cash&Go Phuket Patong, Partner Exchange Phuket Town
- **Chiang Mai**: Cash&Go Chiang Mai Old City

All offices use UUID v5 for deterministic IDs stable across database recreations.

---

## Migration History

| Migration | Description |
|---|---|
| 001 | Enable `uuid-ossp` and `postgis` extensions |
| 002 | Set `search_path TO public` |
| 003 | Create `office_types` table |
| 004 | Create `offices` table with all columns and constraints |
| 005 | Create indexes including PostGIS spatial GIST index |
| 006 | Create `update_location_from_coordinates()` function and trigger |
| 007 | Create `update_updated_at_column()` function and trigger |
| 008 | Create `find_nearest_offices()` search function |
| 009 | Insert seed office types (`cag`, `partner`) with deterministic UUIDs |
| 010 | Insert 6 sample offices across Bangkok, Phuket, Chiang Mai |
| 011 | Add `COMMENT ON` documentation for tables and columns |
