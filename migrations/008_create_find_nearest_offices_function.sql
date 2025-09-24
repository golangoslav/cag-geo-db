-- Function to find nearest offices
CREATE OR REPLACE FUNCTION find_nearest_offices(
    user_lat DECIMAL,
    user_lon DECIMAL,
    max_distance_km DECIMAL DEFAULT 50,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    office_id UUID,
    office_name TEXT,
    office_type office_types.type_code%TYPE,
    country VARCHAR(100),
    city VARCHAR(100),
    address TEXT,
    distance_km DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        o.office_id,
        o.office_name,
        ot.type_code AS office_type,
        o.country,
        o.city,
        o.address,
        ROUND(ST_Distance(
            o.location::geography,
            ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)::geography
        ) / 1000, 2) AS distance_km
    FROM offices o
    JOIN office_types ot ON o.office_type_id = ot.type_id
    WHERE
        o.is_active = true
        AND ST_DWithin(
            o.location::geography,
            ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)::geography,
            max_distance_km * 1000
        )
    ORDER BY distance_km
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;