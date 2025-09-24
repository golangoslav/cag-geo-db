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