#include <stdio.h>
const char *classify(double v) {
    if (v >= 90.0) return "FAIL";
    else if (v >= 75.0) return "WARN";
    else return "PASS";
}

int main() {
    double disk, mem;
    if (scanf("%lf %lf", &disk, &mem) != 2) {
        fprintf(stderr, "Input tidak valid. Butuh 2 angka (disk mem).\n");
        return 3;
    }

    const char *s_disk = classify(disk);
    const char *s_mem = classify(mem);

    printf("DISK %.0f %s\n", disk, s_disk);
    printf("MEM %.0f %s\n", mem, s_mem);

    if (s_disk[0] == 'F' || s_mem[0] == 'F') return 2;
    else if (s_disk[0] == 'W' || s_mem[0] == 'W') return 1;
    else return 0;
}