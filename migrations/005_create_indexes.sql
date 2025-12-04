-- Create spatial index for geographic queries
CREATE INDEX idx_offices_location ON offices USING GIST(location);

-- Create regular indexes
CREATE INDEX idx_offices_country ON offices(country);
CREATE INDEX idx_offices_city ON offices(city);
CREATE INDEX idx_offices_office_type_id ON offices(office_type_id);
CREATE INDEX idx_offices_active ON offices(is_active);
CREATE INDEX idx_offices_country_city ON offices(country, city);

-- Google Maps integration index (for looking up by Google Place ID)
CREATE INDEX idx_offices_google_place_id ON offices(google_place_id) WHERE google_place_id IS NOT NULL;