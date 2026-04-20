-- Create ml_inferences table
CREATE TABLE ml_inferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    result JSONB NOT NULL, -- ML model output (predictions, classifications, etc.)
    confidence DECIMAL(5,4), -- Confidence score 0.0000 to 1.0000
    image_url TEXT, -- URL to the image that was analyzed
    model_version VARCHAR(100), -- Track which ML model version was used
    processing_time_ms INTEGER, -- How long the inference took
    metadata JSONB, -- Additional ML context
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for ML queries
CREATE INDEX idx_ml_inferences_device_timestamp ON ml_inferences(device_id, timestamp DESC);
CREATE INDEX idx_ml_inferences_timestamp ON ml_inferences(timestamp DESC);
CREATE INDEX idx_ml_inferences_confidence ON ml_inferences(confidence);
CREATE INDEX idx_ml_inferences_model_version ON ml_inferences(model_version);

-- Create a function to update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers for updated_at columns
CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sensors_updated_at BEFORE UPDATE ON sensors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
