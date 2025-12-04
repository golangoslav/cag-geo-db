-- Create offices table
CREATE TABLE offices (
    office_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    office_name TEXT NOT NULL,
    office_type_id UUID NOT NULL,
    country VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    contact_info TEXT,
    tg_info BIGINT,
    phone_number VARCHAR(50),

    -- PostGIS geometry column for storing point coordinates
    location GEOMETRY(Point, 4326),

    -- Also store as separate columns for easier access
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- Google Maps integration
    google_place_id VARCHAR(255),     -- Google Places API place_id
    google_maps_url TEXT,             -- Direct Google Maps URL
    google_rating DECIMAL(2, 1),      -- Rating 0.0-5.0
    google_user_total INTEGER,        -- Number of Google reviews

    -- Additional fields
    working_hours JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT valid_latitude CHECK (latitude >= -90 AND latitude <= 90),
    CONSTRAINT valid_longitude CHECK (longitude >= -180 AND longitude <= 180),
    CONSTRAINT valid_phone CHECK (phone_number ~ '^[+]?[0-9\s\-\(\)]+$' OR phone_number IS NULL),
    CONSTRAINT valid_tg_info CHECK (tg_info > 0 OR tg_info IS NULL),
    CONSTRAINT valid_google_rating CHECK (google_rating IS NULL OR (google_rating >= 0 AND google_rating <= 5)),
    CONSTRAINT valid_google_user_total CHECK (google_user_total IS NULL OR google_user_total >= 0),

    -- Foreign key
    CONSTRAINT fk_office_type FOREIGN KEY (office_type_id)
        REFERENCES office_types(type_id) ON DELETE RESTRICT
);