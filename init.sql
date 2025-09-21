-- PostgreSQL initialization script for geo database
-- Only offices and office_types tables are needed

-- Create database and schema
CREATE SCHEMA IF NOT EXISTS geo;

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- Set schema
SET search_path TO geo, public;

-- Create office_types table
CREATE TABLE IF NOT EXISTS office_types (
    type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type_code VARCHAR(50) UNIQUE NOT NULL,
    type_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

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

-- Create spatial index for geographic queries
CREATE INDEX idx_offices_location ON offices USING GIST(location);

-- Create regular indexes
CREATE INDEX idx_offices_country ON offices(country);
CREATE INDEX idx_offices_city ON offices(city);
CREATE INDEX idx_offices_office_type_id ON offices(office_type_id);
CREATE INDEX idx_offices_active ON offices(is_active);
CREATE INDEX idx_offices_country_city ON offices(country, city);

-- Create function to automatically update location from lat/lng
CREATE OR REPLACE FUNCTION update_location_from_coordinates()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update location automatically
CREATE TRIGGER update_office_location
    BEFORE INSERT OR UPDATE OF latitude, longitude ON offices
    FOR EACH ROW
    EXECUTE FUNCTION update_location_from_coordinates();

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
CREATE TRIGGER update_offices_updated_at
    BEFORE UPDATE ON offices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to find nearest offices
CREATE OR REPLACE FUNCTION find_nearest_offices(
    user_lat DECIMAL,
    user_lon DECIMAL,
    max_distance_km DECIMAL DEFAULT 50,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    office_id UUID,
    office_name TEXT,
    office_type office_types.type_code%TYPE,
    country VARCHAR(100),
    city VARCHAR(100),
    address TEXT,
    distance_km DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        o.office_id,
        o.office_name,
        ot.type_code AS office_type,
        o.country,
        o.city,
        o.address,
        ROUND(ST_Distance(
            o.location::geography,
            ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)::geography
        ) / 1000, 2) AS distance_km
    FROM offices o
    JOIN office_types ot ON o.office_type_id = ot.type_id
    WHERE
        o.is_active = true
        AND ST_DWithin(
            o.location::geography,
            ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)::geography,
            max_distance_km * 1000
        )
    ORDER BY distance_km
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Insert initial office types
INSERT INTO office_types (type_code, type_name, description) VALUES
    ('cag', 'Cash & Go', 'Official Cash & Go office'),
    ('partner', 'Partner', 'Partner exchange office')
ON CONFLICT (type_code) DO NOTHING;

-- Insert sample offices for testing
DO $$
DECLARE
    cag_type_id UUID;
    partner_type_id UUID;
BEGIN
    SELECT type_id INTO cag_type_id FROM office_types WHERE type_code = 'cag';
    SELECT type_id INTO partner_type_id FROM office_types WHERE type_code = 'partner';

    INSERT INTO offices (
        office_name, office_type_id, country, city, address,
        contact_info, phone_number, latitude, longitude,
        working_hours
    ) VALUES
    -- Bangkok offices
    (
        'Cash&Go Bangkok Central',
        cag_type_id,
        'Thailand',
        'Bangkok',
        '123 Sukhumvit Road, Khlong Toei, Bangkok 10110',
        'John Manager',
        '+66 2 123 4567',
        13.736717,
        100.560128,
        '{"monday": "09:00-18:00", "tuesday": "09:00-18:00", "wednesday": "09:00-18:00", "thursday": "09:00-18:00", "friday": "09:00-18:00", "saturday": "10:00-16:00"}'::jsonb
    ),
    (
        'Partner Exchange Siam Square',
        partner_type_id,
        'Thailand',
        'Bangkok',
        '456 Rama I Road, Pathum Wan, Bangkok 10330',
        'Jane Partner',
        '+66 2 234 5678',
        13.745577,
        100.534021,
        '{"monday": "08:30-19:00", "tuesday": "08:30-19:00", "wednesday": "08:30-19:00", "thursday": "08:30-19:00", "friday": "08:30-19:00", "saturday": "09:00-17:00", "sunday": "10:00-15:00"}'::jsonb
    ),
    (
        'Cash&Go Chatuchak',
        cag_type_id,
        'Thailand',
        'Bangkok',
        '789 Phahonyothin Road, Chatuchak, Bangkok 10900',
        'Mike Office',
        '+66 2 345 6789',
        13.799965,
        100.550357,
        '{"monday": "09:00-18:00", "tuesday": "09:00-18:00", "wednesday": "09:00-18:00", "thursday": "09:00-18:00", "friday": "09:00-18:00", "saturday": "10:00-16:00"}'::jsonb
    ),
    -- Phuket offices
    (
        'Cash&Go Phuket Patong',
        cag_type_id,
        'Thailand',
        'Phuket',
        '111 Rat-U-Thit 200 Pee Road, Patong, Kathu, Phuket 83150',
        'Sarah Beach',
        '+66 76 123 456',
        7.896195,
        98.296478,
        '{"monday": "09:00-20:00", "tuesday": "09:00-20:00", "wednesday": "09:00-20:00", "thursday": "09:00-20:00", "friday": "09:00-20:00", "saturday": "09:00-20:00", "sunday": "10:00-18:00"}'::jsonb
    ),
    (
        'Partner Exchange Phuket Town',
        partner_type_id,
        'Thailand',
        'Phuket',
        '222 Phuket Road, Talat Yai, Mueang Phuket, Phuket 83000',
        'Tom Island',
        '+66 76 234 567',
        7.884479,
        98.385353,
        '{"monday": "08:00-18:00", "tuesday": "08:00-18:00", "wednesday": "08:00-18:00", "thursday": "08:00-18:00", "friday": "08:00-18:00", "saturday": "09:00-16:00"}'::jsonb
    ),
    -- Chiang Mai offices
    (
        'Cash&Go Chiang Mai Old City',
        cag_type_id,
        'Thailand',
        'Chiang Mai',
        '333 Ratchadamnoen Road, Si Phum, Mueang Chiang Mai, Chiang Mai 50200',
        'Lisa North',
        '+66 53 123 456',
        18.787747,
        98.993128,
        '{"monday": "09:00-18:00", "tuesday": "09:00-18:00", "wednesday": "09:00-18:00", "thursday": "09:00-18:00", "friday": "09:00-18:00", "saturday": "10:00-16:00"}'::jsonb
    )
    ON CONFLICT DO NOTHING;
END $$;

-- Comments for documentation
COMMENT ON TABLE offices IS 'Stores information about Cash&Go offices and partner offices';
COMMENT ON COLUMN offices.office_id IS 'Unique identifier for the office';
COMMENT ON COLUMN offices.office_name IS 'Name of the office';
COMMENT ON COLUMN offices.office_type_id IS 'Reference to office type (cag, partner, etc.)';
COMMENT ON COLUMN offices.country IS 'Country where the office is located';
COMMENT ON COLUMN offices.city IS 'City where the office is located';
COMMENT ON COLUMN offices.address IS 'Full address of the office';
COMMENT ON COLUMN offices.contact_info IS 'Contact person name';
COMMENT ON COLUMN offices.tg_info IS 'Telegram user ID for contact';
COMMENT ON COLUMN offices.phone_number IS 'Contact phone number';
COMMENT ON COLUMN offices.location IS 'PostGIS geometry point for geographic queries';
COMMENT ON COLUMN offices.working_hours IS 'JSON object with working hours by day';
COMMENT ON FUNCTION find_nearest_offices IS 'Find offices within specified distance from user location';