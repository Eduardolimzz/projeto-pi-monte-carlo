/* Versao OpenMP — Estimativa de pi por Monte Carlo
 * IESB 2026/2 — CCO085 — Frente OpenMP
 *
 * Compilar: g++ -O2 -fopenmp -o 02_montecarlo_pi_openmp 02_montecarlo_pi_openmp.cpp
 * Executar: ./02_montecarlo_pi_openmp 50000000 4      (n=50M, 4 threads)
 */
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <ctime>
#include <omp.h>

static double agora()
{
    timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

static inline uint64_t xorshift(uint64_t &s)
{
    s ^= s << 13;
    s ^= s >> 7;
    s ^= s << 17;
    return s;
}

int main(int argc, char **argv)
{
    long n = (argc > 1) ? atol(argv[1]) : 50000000L;
    if (argc > 2)
        omp_set_num_threads(atoi(argv[2]));

    uint64_t s = 88172645463325252ULL;
    long dentro = 0;

    double t0 = agora();

    #pragma omp parallel for
    for (long i = 0; i < n; i++)
    {
        double x = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
        double y = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
        if (x * x + y * y <= 1.0)
            dentro++;
    }

    double pi = 4.0 * (double)dentro / (double)n;
    double t1 = agora();

    printf("n=%ld  threads=%d  pi=%.6f  dentro=%ld  tempo=%.6f s\n",
        n, omp_get_max_threads(), pi, dentro, t1 - t0);
    return 0;
}
