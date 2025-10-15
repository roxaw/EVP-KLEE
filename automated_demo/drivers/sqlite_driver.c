
#include <sqlite3.h>
#include <stdio.h>

int main() {
    sqlite3 *db;
    sqlite3_open(":memory:", &db);
    
    // Create table and insert data
    sqlite3_exec(db, "CREATE TABLE test (id INT, value TEXT)", 0, 0, 0);
    
    for (int i = 0; i < 50; i++) {
        char query[256];
        sprintf(query, "INSERT INTO test VALUES (%d, 'value_%d')", i, i);
        sqlite3_exec(db, query, 0, 0, 0);
    }
    
    // Query data
    sqlite3_exec(db, "SELECT * FROM test WHERE id < 10", 0, 0, 0);
    
    sqlite3_close(db);
    return 0;
}
