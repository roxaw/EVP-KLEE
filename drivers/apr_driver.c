
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
