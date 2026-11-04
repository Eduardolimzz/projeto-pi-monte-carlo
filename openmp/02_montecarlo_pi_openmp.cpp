/* Versao OpenMP — Estimativa de pi por Monte Carlo
 * IESB 2026/2 — CCO085 — Frente OpenMP
 *
 * Compilar: g++ -O2 -fopenmp -o 02_montecarlo_pi_openmp 02_montecarlo_pi_openmp.cpp
 * Executar: ./02_montecarlo_pi_openmp 50000000 4                   (n=50M, 4 threads, static)
 *           ./02_montecarlo_pi_openmp 50000000 4 dynamic 100000    (escalonamento e chunk)
 */
#include <cstdio>
#include <cstdlib>
#include <cstring>
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

static bool ler_escalonamento(const char *nome, omp_sched_t &tipo)
{
    if (strcmp(nome, "static") == 0)
        tipo = omp_sched_static;
    else if (strcmp(nome, "dynamic") == 0)
        tipo = omp_sched_dynamic;
    else if (strcmp(nome, "guided") == 0)
        tipo = omp_sched_guided;
    else
        return false;
    return true;
}

int main(int argc, char **argv)
{
    long n = (argc > 1) ? atol(argv[1]) : 50000000L;
    if (argc > 2)
        omp_set_num_threads(atoi(argv[2]));

    const char *nome_sched = (argc > 3) ? argv[3] : "static";
    int chunk = (argc > 4) ? atoi(argv[4]) : 0;
    omp_sched_t tipo;
    if (!ler_escalonamento(nome_sched, tipo))
    {
        fprintf(stderr, "escalonamento invalido: %s (use static, dynamic ou guided)\n", nome_sched);
        return 1;
    }
    omp_set_schedule(tipo, chunk);

    const uint64_t semente_base = 88172645463325252ULL;
    long dentro = 0;

    double t0 = agora();

    #pragma omp parallel
    {
        int tid = omp_get_thread_num();
        uint64_t s = semente_base ^ (0x9E3779B97F4A7C15ULL * (uint64_t)(tid + 1));

        #pragma omp for schedule(runtime) reduction(+:dentro)
        for (long i = 0; i < n; i++)
        {
            double x = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
            double y = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
            if (x * x + y * y <= 1.0)
                dentro++;
        }
    }

    double pi = 4.0 * (double)dentro / (double)n;
    double t1 = agora();

    printf("n=%ld  threads=%d  schedule=%s  chunk=%d  pi=%.6f  dentro=%ld  tempo=%.6f s\n",
        n, omp_get_max_threads(), nome_sched, chunk, pi, dentro, t1 - t0);
    return 0;
}
