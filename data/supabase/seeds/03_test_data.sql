-- Test data - sample readings and alerts
-- Only load when testing
-- Uses new schema: readings with ts instead of timestamp, no unit column

-- Insert readings using new schema (ts instead of timestamp, no unit column)
INSERT INTO public.readings (sensor_id, ts, value, metadata) VALUES
    ('770e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '1 hour', 22.5, '{"quality": "good", "battery": 100}'::jsonb),
    ('770e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '2 hours', 22.3, '{"quality": "good", "battery": 100}'::jsonb),
    ('770e8400-e29b-41d4-a716-446655440001', NOW() - INTERVAL '3 hours', 22.7, '{"quality": "good", "battery": 100}'::jsonb),
    ('770e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '1 hour', 65.2, '{"quality": "good", "battery": 100}'::jsonb),
    ('770e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '2 hours', 64.8, '{"quality": "good", "battery": 100}'::jsonb),
    ('770e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '3 hours', 66.1, '{"quality": "good", "battery": 100}'::jsonb);

-- Insert alerts using new schema (device_units instead of devices)
-- Note: device_id now references device_units.id
-- Alerts table doesn't have a unique constraint, so we insert without ON CONFLICT
INSERT INTO public.alerts (device_id, sensor_id, type, triggered_at, message, severity, metadata) VALUES
    ('660e8400-e29b-41d4-a716-446655440001', '770e8400-e29b-41d4-a716-446655440001', 'threshold_exceeded', NOW() - INTERVAL '2 hours', 'Temperature approaching upper limit', 'medium', '{"threshold": 25.0, "current_value": 24.5, "unit": "celsius"}'::jsonb);

SELECT 'Test data loaded' as status;