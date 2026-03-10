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
COMMENT ON TABLE office_types IS 'Configurable office types with display colors';
COMMENT ON COLUMN office_types.type_code IS 'Unique short code for the type (e.g. cag, partner)';
COMMENT ON COLUMN office_types.type_name IS 'Human-readable display name';
COMMENT ON COLUMN office_types.color IS 'HEX color for map markers and badges (e.g. #1e40af)';
COMMENT ON FUNCTION find_nearest_offices IS 'Find offices within specified distance from user location';