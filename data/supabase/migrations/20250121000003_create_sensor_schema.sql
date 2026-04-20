-- Migration: Sensor Schema
-- Description: Creates extensible sensor types, sensors, and readings tables
-- Supports: Flexible sensor model that scales with device capabilities

-- ============================================================================
-- CLEANUP: Drop old schema if it exists
-- ============================================================================
-- Remove old readings table and sensors table from legacy migrations
-- These are replaced by the new normalized schema
-- Also drop views that depend on the old schema

DROP VIEW IF EXISTS public.device_status CASCADE;
DROP VIEW IF EXISTS public.recent_readings CASCADE;
DROP VIEW IF EXISTS public.active_alerts CASCADE;

-- Drop old readings and sensors tables (CASCADE will handle dependent objects)
DROP TABLE IF EXISTS public.readings CASCADE;
DROP TABLE IF EXISTS public.sensors CASCADE;

-- ============================================================================
-- SENSOR TYPES
-- ============================================================================
-- Catalog of sensor types with their units and metadata
-- Defines what types of sensors are available (e.g., soil_moisture, temp_c, humidity)

CREATE TABLE public.sensor_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text UNIQUE NOT NULL,           -- e.g., 'soil_moisture', 'temp_c', 'humidity', 'light_lux'
  name text NOT NULL,                 -- human-readable name (e.g., 'Soil Moisture', 'Temperature')
  unit text,                          -- e.g., '%', '°C', 'RH%', 'lux'
  description text,
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.sensor_types IS 'Catalog of sensor types: defines available sensor types and their units';
COMMENT ON COLUMN public.sensor_types.key IS 'Unique identifier for sensor type (e.g., soil_moisture, temp_c)';
COMMENT ON COLUMN public.sensor_types.name IS 'Human-readable name for the sensor type';
COMMENT ON COLUMN public.sensor_types.unit IS 'Unit of measurement (e.g., %, °C, RH%, lux)';

-- ============================================================================
-- SENSORS
-- ============================================================================
-- Individual sensors attached to devices
-- Links device units to sensor types with optional labeling and metadata

CREATE TABLE public.sensors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid REFERENCES public.device_units(id) ON DELETE CASCADE,
  type_id uuid REFERENCES public.sensor_types(id),
  label text,                         -- user-friendly label (e.g., "Soil A", "Ambient Temp")
  metadata jsonb DEFAULT '{}',        -- calibration data, location, etc.
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.sensors IS 'Individual sensors attached to devices';
COMMENT ON COLUMN public.sensors.device_id IS 'Device this sensor is attached to';
COMMENT ON COLUMN public.sensors.type_id IS 'Type of sensor (references sensor_types)';
COMMENT ON COLUMN public.sensors.label IS 'User-friendly label for the sensor (e.g., "Soil A", "Ambient Temp")';
COMMENT ON COLUMN public.sensors.metadata IS 'Sensor metadata: calibration data, location, configuration, etc.';

-- Indexes for sensor queries
CREATE INDEX idx_sensors_device_id ON public.sensors(device_id);
CREATE INDEX idx_sensors_type_id ON public.sensors(type_id);

-- ============================================================================
-- READINGS
-- ============================================================================
-- Time-series sensor readings
-- Optimized for high-frequency time-series data from sensors

CREATE TABLE public.readings (
  id bigserial PRIMARY KEY,
  sensor_id uuid REFERENCES public.sensors(id) ON DELETE CASCADE,
  ts timestamptz NOT NULL,
  value double precision NOT NULL,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.readings IS 'Time-series sensor readings: stores measurements from sensors';
COMMENT ON COLUMN public.readings.sensor_id IS 'Sensor that generated this reading';
COMMENT ON COLUMN public.readings.ts IS 'Timestamp when reading was taken';
COMMENT ON COLUMN public.readings.value IS 'Numeric value of the reading';
COMMENT ON COLUMN public.readings.metadata IS 'Additional reading metadata: quality flags, calibration info, etc.';

-- Indexes for time-series queries (optimized for time-range queries)
CREATE INDEX idx_readings_sensor_ts_desc ON public.readings(sensor_id, ts DESC);
CREATE INDEX idx_readings_ts_desc ON public.readings(ts DESC);
CREATE INDEX idx_readings_sensor_id ON public.readings(sensor_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.update_updated_at_column() IS 'Automatically updates updated_at timestamp on row update';

-- Trigger to update sensors.updated_at
CREATE TRIGGER update_sensors_updated_at
  BEFORE UPDATE ON public.sensors
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Insert default sensor types
INSERT INTO public.sensor_types (key, name, unit, description) VALUES
  ('soil_moisture', 'Soil Moisture', '%', 'Soil moisture percentage'),
  ('temp_c', 'Temperature', '°C', 'Temperature in Celsius'),
  ('temp_f', 'Temperature', '°F', 'Temperature in Fahrenheit'),
  ('humidity', 'Humidity', 'RH%', 'Relative humidity percentage'),
  ('light_lux', 'Light Intensity', 'lux', 'Light intensity in lux'),
  ('ph', 'pH', 'pH', 'pH level'),
  ('ec', 'Electrical Conductivity', 'mS/cm', 'Electrical conductivity'),
  ('co2', 'CO2', 'ppm', 'Carbon dioxide concentration'),
  ('pressure', 'Pressure', 'hPa', 'Atmospheric pressure')
ON CONFLICT (key) DO NOTHING;

