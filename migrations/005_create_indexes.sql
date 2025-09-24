-- Create spatial index for geographic queries
CREATE INDEX idx_offices_location ON offices USING GIST(location);

-- Create regular indexes
CREATE INDEX idx_offices_country ON offices(country);
CREATE INDEX idx_offices_city ON offices(city);
CREATE INDEX idx_offices_office_type_id ON offices(office_type_id);
CREATE INDEX idx_offices_active ON offices(is_active);
CREATE INDEX idx_offices_country_city ON offices(country, city);