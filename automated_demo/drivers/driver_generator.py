#!/usr/bin/env python3

def generate_apr_driver():
    return """
#include <apr.h>
#include <apr_pools.h>
#include <apr_strings.h>
#include <apr_hash.h>

int main() {
    apr_initialize();
    apr_pool_t *pool;
    apr_pool_create(&pool, NULL);
    
    // Test string operations
    for (int i = 0; i < 100; i++) {
        char *result = apr_psprintf(pool, "Test %d", i);
        apr_hash_t *ht = apr_hash_make(pool);
        apr_hash_set(ht, "key", APR_HASH_KEY_STRING, result);
    }
    
    apr_pool_destroy(pool);
    apr_terminate();
    return 0;
}
"""

def generate_sqlite_driver():
    return """
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
"""

if __name__ == "__main__":
    # Generate all drivers
    with open("drivers/apr_driver.c", "w") as f:
        f.write(generate_apr_driver())
    
    with open("drivers/sqlite_driver.c", "w") as f:
        f.write(generate_sqlite_driver())
