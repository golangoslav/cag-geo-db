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