-- Insert initial office types
-- Using UUID v5 for deterministic UUIDs (stable across database recreations)
INSERT INTO office_types (type_id, type_code, type_name, color, description) VALUES
    (uuid_generate_v5(uuid_ns_oid(), 'cag'), 'cag', 'Cash & Go', '#1e40af', 'Official Cash & Go office'),
    (uuid_generate_v5(uuid_ns_oid(), 'partner'), 'partner', 'Partner', '#059669', 'Partner exchange office')
ON CONFLICT (type_id) DO UPDATE SET
    type_code = EXCLUDED.type_code,
    type_name = EXCLUDED.type_name,
    color = EXCLUDED.color,
    description = EXCLUDED.description;