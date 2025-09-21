-- Add Google Maps integration fields to offices table
SET search_path TO geo, public;

-- Add columns for Google Maps integration
ALTER TABLE offices
ADD COLUMN IF NOT EXISTS google_place_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS google_maps_url TEXT,
ADD COLUMN IF NOT EXISTS google_rating DECIMAL(2,1) CHECK (google_rating >= 1 AND google_rating <= 5),
ADD COLUMN IF NOT EXISTS google_user_total INTEGER CHECK (google_user_total >= 0);

-- Create index for Google Place ID
CREATE INDEX IF NOT EXISTS idx_offices_google_place_id ON offices(google_place_id);

-- Add comments
COMMENT ON COLUMN offices.google_place_id IS 'Google Places API place_id for offices that exist in Google Maps';
COMMENT ON COLUMN offices.google_maps_url IS 'Direct URL to the office in Google Maps';
COMMENT ON COLUMN offices.google_rating IS 'Google Maps rating (1-5 stars)';
COMMENT ON COLUMN offices.google_user_total IS 'Total number of Google reviews';

-- Update some sample data with Google Place IDs (примеры для тестирования)
UPDATE offices
SET
    google_place_id = 'ChIJs6rkVAQvBTER',
    google_maps_url = 'https://maps.google.com/place/example',
    google_rating = 4.5,
    google_user_total = 123
WHERE office_name = 'Cash&Go Phuket Beach';