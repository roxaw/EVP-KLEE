import re
import sys

if len(sys.argv) != 2:
    print("Usage: python3 generate_stubs.py klee_log.txt")
    sys.exit(1)

logfile = sys.argv[1]
functions = set()
variables = set()

with open(logfile) as f:
    for line in f:
        m_func = re.search(r"undefined reference to function: (\w+)", line)
        m_var  = re.search(r"undefined reference to variable: (\w+)", line)
        if m_func:
            functions.add(m_func.group(1))
        if m_var:
            variables.add(m_var.group(1))

# Generate stubs.c
with open("stubs.c", "w") as out:
    out.write("// Auto-generated stubs for KLEE unresolved externals\n")
    out.write("#include <stddef.h>\n")
    out.write("#include <stdio.h>\n")
    out.write("#include <stdlib.h>\n")
    out.write("#include <locale.h>\n")
    out.write("#include <wchar.h>\n")
    out.write("#include <pthread.h>\n\n")

    for func in sorted(functions):
        if func.startswith("__"):  # low-level glibc internals
            out.write(f"void *{func}(void) {{ return 0; }}\n")
        elif func in ["getenv", "nl_langinfo", "localeconv"]:
            out.write(f"char *{func}(const char *s) {{ static char buf[2]=\"C\"; return buf; }}\n")
        elif func in ["strlen", "strcmp", "strncmp", "strchr", "strrchr"]:
            out.write(f"int {func}(const char *a, const char *b) {{ return 0; }}\n")
        elif func in ["fopen"]:
            out.write("FILE *fopen(const char *path, const char *mode) { return NULL; }\n")
        elif func in ["fprintf", "printf", "fputs", "fputs_unlocked", "fputc_unlocked"]:
            out.write(f"int {func}(...) {{ return 0; }}\n")
        elif func in ["qsort"]:
            out.write("void qsort(void *base, size_t nmemb, size_t size,\n"
                      "          int (*compar)(const void *, const void *)) { }\n")
        elif func.startswith("pthread_"):
            out.write(f"int {func}(...) {{ return 0; }}\n")
        else:
            out.write(f"int {func}(...) {{ return 0; }}\n")

    for var in sorted(variables):
        if var in ["stdin", "stdout", "stderr"]:
            out.write(f"FILE *{var};\n")
        elif var in ["optarg"]:
            out.write("char *optarg;\n")
        elif var in ["optind"]:
            out.write("int optind;\n")
        else:
            out.write(f"int {var};\n")

print("✅ Generated stubs.c with", len(functions), "functions and", len(variables), "variables.")
