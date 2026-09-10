/* Baseline 02 — Estimativa de pi por Monte Carlo
 * IESB 2026/2 — CCO085 — Prof. Rodrigo Goncalves Pinto
 * Aspecto interessante: paralelismo quase perfeito; cada thread/processo
 * precisa de seu proprio gerador de numeros aleatorios independente.
 *
 * Compilar: g++ -O2 -o 02_montecarlo_pi 02_montecarlo_pi.cpp
 * Executar: ./02_montecarlo_pi 50000000
 */
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <ctime>

static double agora() {
    timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

// gerador simples e reprodutivel (xorshift) — facil de dar uma semente por thread
static inline uint64_t xorshift(uint64_t& s) {
    s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s;
}

int main(int argc, char** argv) {
    long n = (argc > 1) ? atol(argv[1]) : 50000000L;
    uint64_t s = 88172645463325252ULL;   // semente fixa
    long dentro = 0;

    double t0 = agora();
    for (long i = 0; i < n; i++) {
        double x = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
        double y = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
        if (x*x + y*y <= 1.0) dentro++;
    }
    double pi = 4.0 * (double)dentro / (double)n;
    double t1 = agora();

    printf("n=%ld  pi=%.6f  dentro=%ld  tempo=%.6f s\n", n, pi, dentro, t1 - t0);
    return 0;
}
