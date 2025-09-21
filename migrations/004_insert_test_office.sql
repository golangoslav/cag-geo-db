-- Insert test office data for Cash & Go Phuket
SET search_path TO geo, public;

-- Get the CAG type ID
DO $$
DECLARE
    cag_type_id UUID;
BEGIN
    SELECT type_id INTO cag_type_id FROM office_types WHERE type_code = 'cag';

    -- Insert the test office
    INSERT INTO offices (
        office_name,
        office_type_id,
        country,
        city,
        address,
        phone_number,
        latitude,
        longitude,
        working_hours,
        is_active
    ) VALUES (
        'Cash & Go - currency exchange / обмен валют',
        cag_type_id,
        'Таиланд',
        'Phuket',
        '5/27A Fisherman Way, Moo 5 Wiset Rd, Rawai, Muang, Muang, Phuket, 83130',
        '+66958763588',
        7.815182484889534,
        98.33962461410937,
        '{
            "mon": "09:00-19:00",
            "tue": "09:00-19:00",
            "wed": "09:00-19:00",
            "thu": "09:00-19:00",
            "fri": "09:00-19:00",
            "sat": "10:00-18:00",
            "sun": "10:00-18:00"
        }'::jsonb,
        true
    );

    RAISE NOTICE 'Test office inserted successfully';
END $$;