-- Create readings table
CREATE TABLE readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sensor_id UUID NOT NULL REFERENCES sensors(id) ON DELETE CASCADE,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    value DECIMAL(10,4) NOT NULL, -- Supports high precision sensor readings
    unit VARCHAR(20), -- e.g., 'celsius', 'percent', 'lux', 'ph'
    metadata JSONB, -- Additional sensor-specific data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create alerts table
CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    sensor_id UUID REFERENCES sensors(id) ON DELETE SET NULL, -- Can be null for device-level alerts
    type VARCHAR(100) NOT NULL, -- e.g., 'threshold_exceeded', 'device_offline', 'calibration_needed'
    triggered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    message TEXT NOT NULL,
    severity VARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    metadata JSONB, -- Additional alert context
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for time-series queries and alert management
CREATE INDEX idx_readings_sensor_timestamp ON readings(sensor_id, timestamp DESC);
CREATE INDEX idx_readings_timestamp ON readings(timestamp DESC);
CREATE INDEX idx_alerts_device_id ON alerts(device_id);
CREATE INDEX idx_alerts_sensor_id ON alerts(sensor_id);
CREATE INDEX idx_alerts_triggered_at ON alerts(triggered_at DESC);
CREATE INDEX idx_alerts_resolved_at ON alerts(resolved_at);
CREATE INDEX idx_alerts_type ON alerts(type);
