-- Insert sample offices for testing
DO $$
DECLARE
    cag_type_id UUID;
    partner_type_id UUID;
BEGIN
    SELECT type_id INTO cag_type_id FROM office_types WHERE type_code = 'cag';
    SELECT type_id INTO partner_type_id FROM office_types WHERE type_code = 'partner';

    INSERT INTO offices (
        office_id, office_name, office_type_id, country, city, address,
        contact_info, phone_number, latitude, longitude,
        working_hours
    ) VALUES
    -- Bangkok offices (using deterministic UUIDs for stable IDs across deploys)
    (
        uuid_generate_v5(uuid_ns_oid(), 'office:cash-and-go-bangkok-central'),
        'Cash&Go Bangkok Central',
        cag_type_id,
        'Thailand',
        'Bangkok',
        '123 Sukhumvit Road, Khlong Toei, Bangkok 10110',
        'John Manager',
        '+66 2 123 4567',
        13.736717,
        100.560128,
        '{"monday": "09:00-18:00", "tuesday": "09:00-18:00", "wednesday": "09:00-18:00", "thursday": "09:00-18:00", "friday": "09:00-18:00", "saturday": "10:00-16:00"}'::jsonb
    ),
    (
        uuid_generate_v5(uuid_ns_oid(), 'office:partner-exchange-siam-square'),
        'Partner Exchange Siam Square',
        partner_type_id,
        'Thailand',
        'Bangkok',
        '456 Rama I Road, Pathum Wan, Bangkok 10330',
        'Jane Partner',
        '+66 2 234 5678',
        13.745577,
        100.534021,
        '{"monday": "08:30-19:00", "tuesday": "08:30-19:00", "wednesday": "08:30-19:00", "thursday": "08:30-19:00", "friday": "08:30-19:00", "saturday": "09:00-17:00", "sunday": "10:00-15:00"}'::jsonb
    ),
    (
        uuid_generate_v5(uuid_ns_oid(), 'office:cash-and-go-chatuchak'),
        'Cash&Go Chatuchak',
        cag_type_id,
        'Thailand',
        'Bangkok',
        '789 Phahonyothin Road, Chatuchak, Bangkok 10900',
        'Mike Office',
        '+66 2 345 6789',
        13.799965,
        100.550357,
        '{"monday": "09:00-18:00", "tuesday": "09:00-18:00", "wednesday": "09:00-18:00", "thursday": "09:00-18:00", "friday": "09:00-18:00", "saturday": "10:00-16:00"}'::jsonb
    ),
    -- Phuket offices
    (
        uuid_generate_v5(uuid_ns_oid(), 'office:cash-and-go-phuket-patong'),
        'Cash&Go Phuket Patong',
        cag_type_id,
        'Thailand',
        'Phuket',
        '111 Rat-U-Thit 200 Pee Road, Patong, Kathu, Phuket 83150',
        'Sarah Beach',
        '+66 76 123 456',
        7.896195,
        98.296478,
        '{"monday": "09:00-20:00", "tuesday": "09:00-20:00", "wednesday": "09:00-20:00", "thursday": "09:00-20:00", "friday": "09:00-20:00", "saturday": "09:00-20:00", "sunday": "10:00-18:00"}'::jsonb
    ),
    (
        uuid_generate_v5(uuid_ns_oid(), 'office:partner-exchange-phuket-town'),
        'Partner Exchange Phuket Town',
        partner_type_id,
        'Thailand',
        'Phuket',
        '222 Phuket Road, Talat Yai, Mueang Phuket, Phuket 83000',
        'Tom Island',
        '+66 76 234 567',
        7.884479,
        98.385353,
        '{"monday": "08:00-18:00", "tuesday": "08:00-18:00", "wednesday": "08:00-18:00", "thursday": "08:00-18:00", "friday": "08:00-18:00", "saturday": "09:00-16:00"}'::jsonb
    ),
    -- Chiang Mai offices
    (
        uuid_generate_v5(uuid_ns_oid(), 'office:cash-and-go-chiang-mai-old-city'),
        'Cash&Go Chiang Mai Old City',
        cag_type_id,
        'Thailand',
        'Chiang Mai',
        '333 Ratchadamnoen Road, Si Phum, Mueang Chiang Mai, Chiang Mai 50200',
        'Lisa North',
        '+66 53 123 456',
        18.787747,
        98.993128,
        '{"monday": "09:00-18:00", "tuesday": "09:00-18:00", "wednesday": "09:00-18:00", "thursday": "09:00-18:00", "friday": "09:00-18:00", "saturday": "10:00-16:00"}'::jsonb
    )
    ON CONFLICT (office_id) DO NOTHING;
END $$;