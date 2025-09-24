-- Create offices table
CREATE TABLE IF NOT EXISTS offices (
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

    -- Foreign key
    CONSTRAINT fk_office_type FOREIGN KEY (office_type_id)
        REFERENCES office_types(type_id) ON DELETE RESTRICT
);