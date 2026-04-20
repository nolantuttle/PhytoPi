-- Demo data - for presentations and demos
-- Only load when demonstrating
-- Uses new schema: device_units, sensor_types, sensors with type_id

-- Create products for demo devices (using different UUIDs to avoid conflicts)
INSERT INTO public.products (id, sku, name, features) VALUES
    ('550e8400-e29b-41d4-a716-446655440020', 'PHYTOPI-DEMO-001', 'PhytoPi Demo Unit', '{"sensors": ["temp_c", "humidity", "light_lux", "soil_moisture"]}'::jsonb),
    ('550e8400-e29b-41d4-a716-446655440021', 'PHYTOPI-DEMO-002', 'PhytoPi Demo Unit', '{"sensors": ["temp_c", "humidity", "light_lux", "soil_moisture"]}'::jsonb)
ON CONFLICT (sku) DO NOTHING;

-- Create demo device units (with runtime fields)
INSERT INTO public.device_units (id, product_id, serial_number, pairing_code, provisioned, factory_data, name, location, status, registered_at) VALUES
    ('660e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440020', 'PPI-DEMO-001', 'demo-pair-001', true, '{"location": "Demo Room"}'::jsonb, 'Demo Device 1', 'Demo Room', 'active', NOW()),
    ('660e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440021', 'PPI-DEMO-002', 'demo-pair-002', true, '{"location": "Demo Room"}'::jsonb, 'Demo Device 2', 'Demo Room', 'active', NOW())
ON CONFLICT (serial_number) DO NOTHING;

-- Add more demo sensors and data here...

SELECT 'Demo data loaded' as status;