-- Development data - sample devices and sensors
-- Only load when developing/testing
-- Uses new schema: device_units, sensor_types, sensors with type_id

-- Create a product for development (using different UUID to avoid conflicts)
INSERT INTO public.products (id, sku, name, features) VALUES
    ('550e8400-e29b-41d4-a716-446655440010', 'PHYTOPI-DEV-001', 'PhytoPi Development Unit', '{"sensors": ["temp_c", "humidity", "light_lux", "soil_moisture"]}'::jsonb)
ON CONFLICT (sku) DO NOTHING;

-- Create a device unit (using the dev product ID)
INSERT INTO public.device_units (id, product_id, serial_number, pairing_code, provisioned, factory_data, name, location, status, registered_at) VALUES
    ('660e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440010', 'PPI-DEV-001', 'dev-pair-001', true, '{"location": "Development Lab"}'::jsonb, 'Dev Device 1', 'Development Lab', 'active', NOW())
ON CONFLICT (serial_number) DO NOTHING;

-- Create sensors using sensor_type keys (sensor_types are inserted in migration)
-- Using individual INSERTs with subqueries to get type_id from sensor_types
INSERT INTO public.sensors (id, device_id, type_id, label, metadata)
SELECT 
    '770e8400-e29b-41d4-a716-446655440001'::uuid,
    '660e8400-e29b-41d4-a716-446655440001'::uuid,
    (SELECT id FROM public.sensor_types WHERE key = 'temp_c'),
    'Temperature Sensor',
    '{"offset": 0.0, "scale": 1.0}'::jsonb
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.sensors (id, device_id, type_id, label, metadata)
SELECT 
    '770e8400-e29b-41d4-a716-446655440002'::uuid,
    '660e8400-e29b-41d4-a716-446655440001'::uuid,
    (SELECT id FROM public.sensor_types WHERE key = 'humidity'),
    'Humidity Sensor',
    '{"offset": 0.0, "scale": 1.0}'::jsonb
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.sensors (id, device_id, type_id, label, metadata)
SELECT 
    '770e8400-e29b-41d4-a716-446655440003'::uuid,
    '660e8400-e29b-41d4-a716-446655440001'::uuid,
    (SELECT id FROM public.sensor_types WHERE key = 'light_lux'),
    'Light Sensor',
    '{"offset": 0.0, "scale": 1.0}'::jsonb
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.sensors (id, device_id, type_id, label, metadata)
SELECT 
    '770e8400-e29b-41d4-a716-446655440004'::uuid,
    '660e8400-e29b-41d4-a716-446655440001'::uuid,
    (SELECT id FROM public.sensor_types WHERE key = 'soil_moisture'),
    'Soil Moisture Sensor',
    '{"offset": 0.0, "scale": 1.0}'::jsonb
ON CONFLICT (id) DO NOTHING;

SELECT 'Development data loaded' as status;