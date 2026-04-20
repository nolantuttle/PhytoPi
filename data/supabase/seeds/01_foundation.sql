-- Foundation data - always needed
-- Basic system setup (products, sensor types, etc.)
-- Note: Users are created through Supabase Auth, which automatically creates user_profiles via trigger

-- Create sample products for development
INSERT INTO public.products (id, sku, name, features) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'PHYTOPI-MK1', 'PhytoPi Mark 1', '{"sensors": ["temp_c", "humidity", "light_lux", "soil_moisture"], "version": "1.0"}'::jsonb),
    ('550e8400-e29b-41d4-a716-446655440002', 'PHYTOPI-MK2', 'PhytoPi Mark 2', '{"sensors": ["temp_c", "humidity", "light_lux", "soil_moisture", "ph", "ec"], "version": "2.0"}'::jsonb)
ON CONFLICT (sku) DO NOTHING;

SELECT 'Foundation data loaded' as status;
