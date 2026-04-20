-- Enable Row Level Security on all tables
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensors ENABLE ROW LEVEL SECURITY;
ALTER TABLE readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ml_inferences ENABLE ROW LEVEL SECURITY;

-- Create policies for devices (users can read all, admins can modify)
CREATE POLICY "Users can view devices" ON devices
    FOR SELECT USING (true);

CREATE POLICY "Admins can modify devices" ON devices
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Create policies for sensors (users can read all, admins can modify)
CREATE POLICY "Users can view sensors" ON sensors
    FOR SELECT USING (true);

CREATE POLICY "Admins can modify sensors" ON sensors
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Create policies for readings (users can read all, IoT devices can insert)
CREATE POLICY "Users can view readings" ON readings
    FOR SELECT USING (true);

CREATE POLICY "IoT devices can insert readings" ON readings
    FOR INSERT WITH CHECK (true); -- You might want to add device authentication here

-- Create policies for users (users can view all, admins can modify)
CREATE POLICY "Users can view users" ON users
    FOR SELECT USING (true);

CREATE POLICY "Admins can modify users" ON users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Create policies for alerts (users can view all, admins can modify)
CREATE POLICY "Users can view alerts" ON alerts
    FOR SELECT USING (true);

CREATE POLICY "Admins can modify alerts" ON alerts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Create policies for ml_inferences (users can view all, IoT devices can insert)
CREATE POLICY "Users can view ml_inferences" ON ml_inferences
    FOR SELECT USING (true);

CREATE POLICY "IoT devices can insert ml_inferences" ON ml_inferences
    FOR INSERT WITH CHECK (true); -- You might want to add device authentication here
