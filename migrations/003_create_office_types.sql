-- Create office_types table and update offices table
SET search_path TO geo, public;

-- Create office_types table
CREATE TABLE IF NOT EXISTS office_types (
    type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type_code VARCHAR(50) UNIQUE NOT NULL,
    type_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial office types
INSERT INTO office_types (type_code, type_name, description) VALUES
    ('cag', 'Cash & Go', 'Official Cash & Go office'),
    ('partner', 'Partner', 'Partner exchange office');

-- Store the type IDs for reference
DO $$
DECLARE
    cag_type_id UUID;
    partner_type_id UUID;
BEGIN
    SELECT type_id INTO cag_type_id FROM office_types WHERE type_code = 'cag';
    SELECT type_id INTO partner_type_id FROM office_types WHERE type_code = 'partner';

    -- Add new column for office_type_id
    ALTER TABLE offices ADD COLUMN IF NOT EXISTS office_type_id UUID;

    -- Update existing data with proper type IDs
    UPDATE offices
    SET office_type_id = CASE
        WHEN office_type = 'cag' THEN cag_type_id
        WHEN office_type = 'partner' THEN partner_type_id
    END;

    -- Make office_type_id NOT NULL after populating data
    ALTER TABLE offices ALTER COLUMN office_type_id SET NOT NULL;

    -- Add foreign key constraint
    ALTER TABLE offices
    ADD CONSTRAINT fk_office_type
    FOREIGN KEY (office_type_id)
    REFERENCES office_types(type_id)
    ON DELETE RESTRICT;

    -- Create index
    CREATE INDEX IF NOT EXISTS idx_offices_office_type_id ON offices(office_type_id);
END $$;

-- Drop the old office_type column (enum)
ALTER TABLE offices DROP COLUMN IF EXISTS office_type;

-- Add comment
COMMENT ON COLUMN offices.office_type_id IS 'Reference to office type (cag, partner, etc.)';