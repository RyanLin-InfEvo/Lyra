// Prevent header file from being read multiple times
#ifndef LYRA_C_API_H
#define LYRA_C_API_H

// Make this header file visible to C++
#ifdef __cplusplus
extern "C" {
#endif

// Initialize database
__attribute__((visibility("default"))) int lyra_init(const char *storage_root);

// Dispatch JSON request to Lyra, return JSON response
__attribute__((visibility("default"))) char *
lyra_dispatch(const char *json_request);

// Clean up string in memory
__attribute__((visibility("default"))) void lyra_free_string(char *str);

#ifdef __cplusplus
}
#endif

#endif // LYRA_C_API_H
