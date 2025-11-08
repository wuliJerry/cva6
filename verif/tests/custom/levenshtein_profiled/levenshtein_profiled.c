/* CVA6 Profiled Levenshtein Benchmark
 *
 * Based on BEEBS levenshtein benchmark
 * Modified to include function profiling using CVA6's function_profiler.sv
 *
 * Profiling mechanism:
 * - Measures cycles spent in levenshtein_distance function
 * - Writes profiling data to memory at 0x80002000
 * - function_profiler.sv monitors these writes and logs results
 */

#include <stdint.h>
#include <string.h>

// Profiling data structure - monitored by function_profiler.sv at 0x80002000
typedef struct {
    uint64_t call_count;              // +0x00
    uint64_t total_cycles;            // +0x08
    uint64_t total_program_cycles;    // +0x10
    uint64_t avg_cycles_per_call;     // +0x18
    uint64_t percentage_of_total;     // +0x20 (optional, can be calculated)
} profiling_data_t;

// Profiling data structure - allocated in .data section
// Address will be determined by linker (typically around 0x80003b68+)
volatile profiling_data_t profiling_data __attribute__((section(".data"))) __attribute__((aligned(8)));

// CSR access functions
static inline uint64_t read_mcycle(void) {
    uint64_t val;
    asm volatile ("csrr %0, 0xB00" : "=r"(val));
    return val;
}

static inline uint64_t read_minstret(void) {
    uint64_t val;
    asm volatile ("csrr %0, 0xB02" : "=r"(val));
    return val;
}

// Helper function
static int min(int x, int y) {
    return x < y ? x : y;
}

// Fixed-size distance matrix (max string length 15)
// Initialize to force into .data section (not .bss) so it gets loaded
#define MAX_LEN 16
static int d[MAX_LEN][MAX_LEN] = {{0}};

// Main benchmark function - this is what we profile
int levenshtein_distance(const char *s, const char *t) {
    int i, j;
    int sl = strlen(s);
    int tl = strlen(t);

    // Bounds check
    if (sl >= MAX_LEN || tl >= MAX_LEN) {
        return -1;  // Error: string too long
    }

    for (i = 0; i <= sl; i++)
        d[i][0] = i;

    for (j = 0; j <= tl; j++)
        d[0][j] = j;

    for (j = 1; j <= tl; j++) {
        for (i = 1; i <= sl; i++) {
            if (s[i - 1] == t[j - 1]) {
                d[i][j] = d[i - 1][j - 1];
            }
            else {
                d[i][j] = min(d[i - 1][j] + 1,  /* deletion */
                              min(d[i][j - 1] + 1,  /* insertion */
                                  d[i - 1][j - 1] + 1));    /* substitution */
            }
        }
    }
    return d[sl][tl];
}

// Test strings
const char *strings[] = {"srrjngre", "asfcjnsdkj", "string", "msd", "strings"};

// Number of iterations (reduced from BEEBS default 4096 for faster simulation)
#define NUM_ITERATIONS 100

int main(void) {
    int i, j, iter;
    volatile unsigned sum = 0;
    uint64_t start_cycle, end_cycle, func_start, func_end;
    uint64_t total_func_cycles = 0;
    uint64_t call_count = 0;

    // Initialize profiling data
    profiling_data.call_count = 0;
    profiling_data.total_cycles = 0;
    profiling_data.total_program_cycles = 0;
    profiling_data.avg_cycles_per_call = 0;
    profiling_data.percentage_of_total = 0;

    // Start overall timing
    start_cycle = read_mcycle();

    // Run benchmark with profiling
    for (iter = 0; iter < NUM_ITERATIONS; iter++) {
        for (i = 0; i < 5; ++i) {
            for (j = 0; j < 5; ++j) {
                // Profile individual function call
                func_start = read_mcycle();
                sum += levenshtein_distance(strings[i], strings[j]);
                func_end = read_mcycle();

                // Accumulate profiling data
                total_func_cycles += (func_end - func_start);
                call_count++;
            }
        }
    }

    // End overall timing
    end_cycle = read_mcycle();

    // Calculate and store profiling results
    // These writes can be monitored by function_profiler.sv at the actual data address
    profiling_data.call_count = call_count;
    profiling_data.total_cycles = total_func_cycles;
    profiling_data.total_program_cycles = end_cycle - start_cycle;

    if (call_count > 0) {
        profiling_data.avg_cycles_per_call = total_func_cycles / call_count;
    }

    if (profiling_data.total_program_cycles > 0) {
        profiling_data.percentage_of_total =
            (total_func_cycles * 100) / profiling_data.total_program_cycles;
    }

    // Verify result (expected: 122 per iteration, so 122 * NUM_ITERATIONS)
    uint64_t expected = 122 * NUM_ITERATIONS;
    if (sum != expected) {
        return 1; // Test failed
    }

    return 0; // Test passed
}

// strlen is provided by syscalls.c, no need to redefine
