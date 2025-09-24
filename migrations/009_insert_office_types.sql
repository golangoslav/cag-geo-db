-- Insert initial office types
INSERT INTO office_types (type_code, type_name, description) VALUES
    ('cag', 'Cash & Go', 'Official Cash & Go office'),
    ('partner', 'Partner', 'Partner exchange office')
ON CONFLICT (type_code) DO NOTHING;