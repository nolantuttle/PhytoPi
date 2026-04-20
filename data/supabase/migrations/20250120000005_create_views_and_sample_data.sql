-- Create a view for device status with sensor count
CREATE VIEW device_status AS
SELECT 
    d.id,
    d.name,
    d.type,
    d.location,
    d.status,
    d.registered_at,
    COUNT(s.id) as sensor_count,
    MAX(r.timestamp) as last_reading_at
FROM devices d
LEFT JOIN sensors s ON d.id = s.device_id
LEFT JOIN readings r ON s.id = r.sensor_id
GROUP BY d.id, d.name, d.type, d.location, d.status, d.registered_at;

-- Create a view for recent sensor readings
CREATE VIEW recent_readings AS
SELECT 
    r.id,
    r.sensor_id,
    s.type as sensor_type,
    d.name as device_name,
    d.location,
    r.timestamp,
    r.value,
    r.unit
FROM readings r
JOIN sensors s ON r.sensor_id = s.id
JOIN devices d ON s.device_id = d.id
WHERE r.timestamp >= NOW() - INTERVAL '24 hours'
ORDER BY r.timestamp DESC;

-- Create a view for active alerts
CREATE VIEW active_alerts AS
SELECT 
    a.id,
    a.type,
    a.severity,
    a.message,
    a.triggered_at,
    d.name as device_name,
    d.location,
    s.type as sensor_type
FROM alerts a
JOIN devices d ON a.device_id = d.id
LEFT JOIN sensors s ON a.sensor_id = s.id
WHERE a.resolved_at IS NULL
ORDER BY a.triggered_at DESC;


