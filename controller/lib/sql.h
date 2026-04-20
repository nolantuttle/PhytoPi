#ifndef SQL_H
#define SQL_H
#include <sqlite3.h>

/* Reading structure for batch operations */
typedef struct {
    int id;
    double value1;
    double value2;  /* For temp_hum: humidity, temperature. For bme680: temp, humidity */
    double value3;  /* For bme680: pressure */
    double value4;  /* For bme680: gas_resistance */
    int64_t timestamp;
    char table_name[64];  /* Which table this came from */
} sqlite_reading_t;

int sql_execute(sqlite3 *db, const char *sql);
int sql_execute_insert(sqlite3 *db, const char *sql, int data, int data2, int timestamp);
int sql_execute_insert_bme680(sqlite3 *db, double temp, double humidity, double pressure, double gas, int timestamp);
int sql_execute_insert_double(sqlite3 *db, const char *sql, double data, int timestamp);
sqlite3 *db_init(const char *db_file);
int sql_get_unsynced_readings(sqlite3 *db, sqlite_reading_t **readings, int *count);
int sql_mark_as_synced(sqlite3 *db, const char *table_name, int id);

#endif
