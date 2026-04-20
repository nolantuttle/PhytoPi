#include "../lib/gpio.h"
#include "../lib/sql.h"
#include <string.h>
#include <stdlib.h>

/*
 * Execute an SQL statement on the given database.
 * Returns SQLITE_OK on success, or an SQLite error code on failure.
 */
int sql_execute(sqlite3 *db, const char *sql)
{
    char *err_msg = 0;
    int rc = sqlite3_exec(db, sql, 0, 0, &err_msg);

    if (rc != SQLITE_OK)
    {
        fprintf(stderr, "SQL error: %s\n", err_msg);
        sqlite3_free(err_msg);
        return rc;
    }

    return SQLITE_OK;
}

/*
 * Execute an SQL insert statement with parameters on the given database.
 * Returns SQLITE_OK on success, or an SQLite error code on failure.
 */
int sql_execute_insert(sqlite3 *db, const char *sql, int data, int data2, int timestamp)
{
    sqlite3_stmt *stmt;                                    // Declare a statement pointer
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL); // Prepare the SQL statement
    if (rc != SQLITE_OK)
    {
        fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
        return rc;
    }

    // Bind the parameters to the prepared statement
    sqlite3_bind_int(stmt, 1, data);
    if (data2 != 0) // Only bind the second data if it's not zero (for dht11)
    {
        sqlite3_bind_int(stmt, 2, data2);
        sqlite3_bind_int(stmt, 3, timestamp); // 3-parameter query: data, data2, timestamp
    }
    else
    {
        sqlite3_bind_int(stmt, 2, timestamp); // 2-parameter query: data, timestamp
    }

    rc = sqlite3_step(stmt); // Execute the prepared statement

    if (rc != SQLITE_DONE && rc != SQLITE_OK)
    {
        fprintf(stderr, "Execution failed: %s\n", sqlite3_errmsg(db));
        sqlite3_finalize(stmt); // Finalize the statement to release resources
        return rc;
    }

    sqlite3_finalize(stmt); // Finalize the statement to release resources
    return SQLITE_OK;
}

sqlite3 *db_init(const char *db_file)
{
    sqlite3 *db;
    int rc = sqlite3_open(db_file, &db);
    if (rc)
    {
        fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
        return NULL;
    }

    sql_execute(db, "CREATE TABLE IF NOT EXISTS temp_hum_data (id INTEGER PRIMARY KEY, humidity INTEGER, temperature INTEGER, timestamp INTEGER, synced INTEGER DEFAULT 0);");
    sql_execute(db, "CREATE TABLE IF NOT EXISTS soil_moisture_data (id INTEGER PRIMARY KEY, humidity INTEGER, timestamp INTEGER, synced INTEGER DEFAULT 0);");
    sql_execute(db, "CREATE TABLE IF NOT EXISTS water_level_data (id INTEGER PRIMARY KEY, has_water BOOLEAN, timestamp INTEGER, synced INTEGER DEFAULT 0);");
    sql_execute(db, "CREATE TABLE IF NOT EXISTS bme680_data (id INTEGER PRIMARY KEY, temperature REAL, humidity REAL, pressure REAL, gas_resistance REAL, timestamp INTEGER, synced INTEGER DEFAULT 0);");
    sql_execute(db, "CREATE TABLE IF NOT EXISTS water_level_photoelectric (id INTEGER PRIMARY KEY, frequency_hz INTEGER, timestamp INTEGER, synced INTEGER DEFAULT 0);");

    // Migrate existing tables: add synced column if it doesn't exist
    // SQLite doesn't support IF NOT EXISTS for ALTER TABLE, so we check first
    sqlite3_stmt *check_stmt;
    int has_synced = 0;

    // Check temp_hum_data
    if (sqlite3_prepare_v2(db, "PRAGMA table_info(temp_hum_data);", -1, &check_stmt, NULL) == SQLITE_OK)
    {
        while (sqlite3_step(check_stmt) == SQLITE_ROW)
        {
            const char *col_name = (const char *)sqlite3_column_text(check_stmt, 1);
            if (col_name && strcmp(col_name, "synced") == 0)
            {
                has_synced = 1;
                break;
            }
        }
        sqlite3_finalize(check_stmt);
        if (!has_synced)
        {
            sql_execute(db, "ALTER TABLE temp_hum_data ADD COLUMN synced INTEGER DEFAULT 0;");
        }
    }

    // Check soil_moisture_data
    has_synced = 0;
    if (sqlite3_prepare_v2(db, "PRAGMA table_info(soil_moisture_data);", -1, &check_stmt, NULL) == SQLITE_OK)
    {
        while (sqlite3_step(check_stmt) == SQLITE_ROW)
        {
            const char *col_name = (const char *)sqlite3_column_text(check_stmt, 1);
            if (col_name && strcmp(col_name, "synced") == 0)
            {
                has_synced = 1;
                break;
            }
        }
        sqlite3_finalize(check_stmt);
        if (!has_synced)
        {
            sql_execute(db, "ALTER TABLE soil_moisture_data ADD COLUMN synced INTEGER DEFAULT 0;");
        }
    }

    // Check water_level_data
    has_synced = 0;
    if (sqlite3_prepare_v2(db, "PRAGMA table_info(water_level_data);", -1, &check_stmt, NULL) == SQLITE_OK)
    {
        while (sqlite3_step(check_stmt) == SQLITE_ROW)
        {
            const char *col_name = (const char *)sqlite3_column_text(check_stmt, 1);
            if (col_name && strcmp(col_name, "synced") == 0)
            {
                has_synced = 1;
                break;
            }
        }
        sqlite3_finalize(check_stmt);
        if (!has_synced)
        {
            sql_execute(db, "ALTER TABLE water_level_data ADD COLUMN synced INTEGER DEFAULT 0;");
        }
    }

    // Create indexes for faster unsynced queries
    sql_execute(db, "CREATE INDEX IF NOT EXISTS idx_temp_hum_synced ON temp_hum_data(synced);");
    sql_execute(db, "CREATE INDEX IF NOT EXISTS idx_soil_moisture_synced ON soil_moisture_data(synced);");
    sql_execute(db, "CREATE INDEX IF NOT EXISTS idx_water_level_synced ON water_level_data(synced);");
    sql_execute(db, "CREATE INDEX IF NOT EXISTS idx_bme680_synced ON bme680_data(synced);");
    sql_execute(db, "CREATE INDEX IF NOT EXISTS idx_water_photoelectric_synced ON water_level_photoelectric(synced);");

    return db;
}

int sql_execute_insert_bme680(sqlite3 *db, double temp, double humidity, double pressure, double gas, int timestamp)
{
    const char *sql = "INSERT INTO bme680_data (temperature, humidity, pressure, gas_resistance, timestamp) VALUES (?, ?, ?, ?, ?);";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) != SQLITE_OK)
        return -1;
    sqlite3_bind_double(stmt, 1, temp);
    sqlite3_bind_double(stmt, 2, humidity);
    sqlite3_bind_double(stmt, 3, pressure);
    sqlite3_bind_double(stmt, 4, gas);
    sqlite3_bind_int(stmt, 5, timestamp);
    int rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    return (rc == SQLITE_DONE) ? SQLITE_OK : rc;
}

int sql_execute_insert_double(sqlite3 *db, const char *sql_str, double data, int timestamp)
{
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db, sql_str, -1, &stmt, NULL) != SQLITE_OK)
        return -1;
    sqlite3_bind_double(stmt, 1, data);
    sqlite3_bind_int(stmt, 2, timestamp);
    int rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    return (rc == SQLITE_DONE) ? SQLITE_OK : rc;
}

/*
 * Get all unsynced readings from all tables
 * Returns 0 on success, -1 on failure
 * Caller must free the readings array
 */
int sql_get_unsynced_readings(sqlite3 *db, sqlite_reading_t **readings, int *count)
{
    if (!db || !readings || !count)
        return -1;

    *count = 0;
    *readings = NULL;

    // First, count total unsynced readings
    const char *count_sql =
        "SELECT COUNT(*) FROM ("
        "  SELECT id FROM temp_hum_data WHERE synced = 0 "
        "  UNION ALL "
        "  SELECT id FROM soil_moisture_data WHERE synced = 0 "
        "  UNION ALL "
        "  SELECT id FROM water_level_data WHERE synced = 0 "
        "  UNION ALL "
        "  SELECT id FROM bme680_data WHERE synced = 0 "
        "  UNION ALL "
        "  SELECT id FROM water_level_photoelectric WHERE synced = 0"
        ");";

    sqlite3_stmt *count_stmt;
    if (sqlite3_prepare_v2(db, count_sql, -1, &count_stmt, NULL) != SQLITE_OK)
    {
        fprintf(stderr, "Failed to prepare count statement: %s\n", sqlite3_errmsg(db));
        return -1;
    }

    if (sqlite3_step(count_stmt) == SQLITE_ROW)
    {
        *count = sqlite3_column_int(count_stmt, 0);
    }
    sqlite3_finalize(count_stmt);

    if (*count == 0)
        return 0;

    // Allocate memory for readings
    *readings = (sqlite_reading_t *)malloc(*count * sizeof(sqlite_reading_t));
    if (!*readings)
    {
        fprintf(stderr, "Failed to allocate memory for readings\n");
        return -1;
    }

    int idx = 0;

    // Get unsynced temp_hum_data
    const char *temp_hum_sql = "SELECT id, humidity, temperature, timestamp FROM temp_hum_data WHERE synced = 0 ORDER BY timestamp LIMIT 100;";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db, temp_hum_sql, -1, &stmt, NULL) == SQLITE_OK)
    {
        while (sqlite3_step(stmt) == SQLITE_ROW && idx < *count)
        {
            (*readings)[idx].id = sqlite3_column_int(stmt, 0);
            (*readings)[idx].value1 = sqlite3_column_int(stmt, 1);
            (*readings)[idx].value2 = sqlite3_column_int(stmt, 2);
            (*readings)[idx].value3 = 0;
            (*readings)[idx].value4 = 0;
            (*readings)[idx].timestamp = sqlite3_column_int64(stmt, 3);
            strcpy((*readings)[idx].table_name, "temp_hum_data");
            idx++;
        }
        sqlite3_finalize(stmt);
    }

    // Get unsynced soil_moisture_data
    const char *soil_sql = "SELECT id, humidity, timestamp FROM soil_moisture_data WHERE synced = 0 ORDER BY timestamp LIMIT 100;";
    if (sqlite3_prepare_v2(db, soil_sql, -1, &stmt, NULL) == SQLITE_OK)
    {
        while (sqlite3_step(stmt) == SQLITE_ROW && idx < *count)
        {
            (*readings)[idx].id = sqlite3_column_int(stmt, 0);
            (*readings)[idx].value1 = sqlite3_column_int(stmt, 1);
            (*readings)[idx].value2 = 0;
            (*readings)[idx].value3 = 0;
            (*readings)[idx].value4 = 0;
            (*readings)[idx].timestamp = sqlite3_column_int64(stmt, 2);
            strcpy((*readings)[idx].table_name, "soil_moisture_data");
            idx++;
        }
        sqlite3_finalize(stmt);
    }

    // Get unsynced water_level_data
    const char *water_sql = "SELECT id, has_water, timestamp FROM water_level_data WHERE synced = 0 ORDER BY timestamp LIMIT 100;";
    if (sqlite3_prepare_v2(db, water_sql, -1, &stmt, NULL) == SQLITE_OK)
    {
        while (sqlite3_step(stmt) == SQLITE_ROW && idx < *count)
        {
            (*readings)[idx].id = sqlite3_column_int(stmt, 0);
            (*readings)[idx].value1 = sqlite3_column_int(stmt, 1);
            (*readings)[idx].value2 = 0;
            (*readings)[idx].value3 = 0;
            (*readings)[idx].value4 = 0;
            (*readings)[idx].timestamp = sqlite3_column_int64(stmt, 2);
            strcpy((*readings)[idx].table_name, "water_level_data");
            idx++;
        }
        sqlite3_finalize(stmt);
    }

    // Get unsynced bme680_data (value1=temp, value2=humidity, value3=pressure, value4=gas)
    const char *bme_sql = "SELECT id, temperature, humidity, pressure, gas_resistance, timestamp FROM bme680_data WHERE synced = 0 ORDER BY timestamp LIMIT 100;";
    if (sqlite3_prepare_v2(db, bme_sql, -1, &stmt, NULL) == SQLITE_OK)
    {
        while (sqlite3_step(stmt) == SQLITE_ROW && idx < *count)
        {
            (*readings)[idx].id = sqlite3_column_int(stmt, 0);
            (*readings)[idx].value1 = sqlite3_column_double(stmt, 1);
            (*readings)[idx].value2 = sqlite3_column_double(stmt, 2);
            (*readings)[idx].value3 = sqlite3_column_double(stmt, 3);
            (*readings)[idx].value4 = sqlite3_column_double(stmt, 4);
            (*readings)[idx].timestamp = sqlite3_column_int64(stmt, 5);
            strcpy((*readings)[idx].table_name, "bme680_data");
            idx++;
        }
        sqlite3_finalize(stmt);
    }

    // Get unsynced water_level_photoelectric
    const char *photo_sql = "SELECT id, frequency_hz, timestamp FROM water_level_photoelectric WHERE synced = 0 ORDER BY timestamp LIMIT 100;";
    if (sqlite3_prepare_v2(db, photo_sql, -1, &stmt, NULL) == SQLITE_OK)
    {
        while (sqlite3_step(stmt) == SQLITE_ROW && idx < *count)
        {
            (*readings)[idx].id = sqlite3_column_int(stmt, 0);
            (*readings)[idx].value1 = sqlite3_column_int(stmt, 1);
            (*readings)[idx].value2 = 0;
            (*readings)[idx].value3 = 0;
            (*readings)[idx].value4 = 0;
            (*readings)[idx].timestamp = sqlite3_column_int64(stmt, 2);
            strcpy((*readings)[idx].table_name, "water_level_photoelectric");
            idx++;
        }
        sqlite3_finalize(stmt);
    }

    *count = idx; // Update count to actual number retrieved
    return 0;
}

/*
 * Mark a reading as synced
 * Returns SQLITE_OK on success, error code on failure
 */
int sql_mark_as_synced(sqlite3 *db, const char *table_name, int id)
{
    if (!db || !table_name)
        return -1;

    char sql[256];
    snprintf(sql, sizeof(sql), "UPDATE %s SET synced = 1 WHERE id = ?;", table_name);

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) != SQLITE_OK)
    {
        fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
        return -1;
    }

    sqlite3_bind_int(stmt, 1, id);
    int rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    if (rc != SQLITE_DONE)
    {
        fprintf(stderr, "Failed to mark as synced: %s\n", sqlite3_errmsg(db));
        return rc;
    }

    return SQLITE_OK;
}