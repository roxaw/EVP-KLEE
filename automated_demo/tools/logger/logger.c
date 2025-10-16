//logger for Step 2: Instrumentation Pass (BranchLoggerPass.cpp) 3.5 file analysis


#include <stdio.h>
#include <stdlib.h>   // for getenv

void __vase_log_var(int locId, int branchTaken, const char *varName, int val) {
    // No console noise: keep this disabled to avoid breaking program output
    // printf("LOG: loc=%d branch=%d %s=%d\n", locId, branchTaken, varName, val);

    // Allow overriding the log path at runtime; default to vase_value_log.txt
    const char *logpath = getenv("VASE_LOG");
    if (!logpath || !*logpath) {
        logpath = "vase_value_log.txt";
    }

    FILE *log = fopen(logpath, "a");   // append mode so multiple runs accumulate
    if (!log) {
        perror("fopen VASE_LOG");
        return;
    }

    // One line per observation; stable format used by Step 2
    // Example: loc:123:branch:1    argc:4
    fprintf(log, "loc:%d:branch:%d\t%s:%d\n", locId, branchTaken, varName, val);

    // fclose flushes; explicit fflush not needed here
    fclose(log);
}

