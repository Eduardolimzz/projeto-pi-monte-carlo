/* Experimento: custo de proteger o contador "dentro" com reduction, atomic ou critical
 * IESB 2026/2 — CCO085 — Frente OpenMP
 *
 * Usa o mesmo laço por blocos da versao OpenMP. As tres formas dao o mesmo
 * "dentro" (o do baseline); muda so o tempo.
 *
 * Compilar: make exp
 * Executar: ./openmp/experimentos/comparar_sincronizacao 20000000 8 atomic
 *           (N, threads, reduction|atomic|critical)
 */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <omp.h>
#include "xorshift.h"

static const long BLOCO = 65536;

int main(int argc, char **argv)
{
    if (argc < 4)
    {
        fprintf(stderr, "uso: %s N threads reduction|atomic|critical\n", argv[0]);
        return 1;
    }

    long n = atol(argv[1]);
    omp_set_num_threads(atoi(argv[2]));
    const char *modo = argv[3];
    if (strcmp(modo, "reduction") != 0 && strcmp(modo, "atomic") != 0 && strcmp(modo, "critical") != 0)
    {
        fprintf(stderr, "modo invalido: %s (use reduction, atomic ou critical)\n", modo);
        return 1;
    }

    const uint64_t semente = 88172645463325252ULL;
    long blocos = (n + BLOCO - 1) / BLOCO;
    long dentro = 0;
    TabelaSalto tabela;
    montar_tabela_salto(tabela);

    double t0 = omp_get_wtime();

    if (strcmp(modo, "reduction") == 0)
    {
        #pragma omp parallel for schedule(static) reduction(+:dentro)
        for (long b = 0; b < blocos; b++)
        {
            long inicio = b * BLOCO;
            long fim = (inicio + BLOCO < n) ? inicio + BLOCO : n;
            uint64_t s = saltar(tabela, semente, 2 * (uint64_t)inicio);
            for (long i = inicio; i < fim; i++)
            {
                double x = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
                double y = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
                if (x * x + y * y <= 1.0)
                    dentro++;
            }
        }
    }
    else if (strcmp(modo, "atomic") == 0)
    {
        #pragma omp parallel for schedule(static)
        for (long b = 0; b < blocos; b++)
        {
            long inicio = b * BLOCO;
            long fim = (inicio + BLOCO < n) ? inicio + BLOCO : n;
            uint64_t s = saltar(tabela, semente, 2 * (uint64_t)inicio);
            for (long i = inicio; i < fim; i++)
            {
                double x = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
                double y = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
                if (x * x + y * y <= 1.0)
                {
                    #pragma omp atomic
                    dentro++;
                }
            }
        }
    }
    else
    {
        #pragma omp parallel for schedule(static)
        for (long b = 0; b < blocos; b++)
        {
            long inicio = b * BLOCO;
            long fim = (inicio + BLOCO < n) ? inicio + BLOCO : n;
            uint64_t s = saltar(tabela, semente, 2 * (uint64_t)inicio);
            for (long i = inicio; i < fim; i++)
            {
                double x = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
                double y = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
                if (x * x + y * y <= 1.0)
                {
                    #pragma omp critical
                    dentro++;
                }
            }
        }
    }

    printf("%-9s n=%ld  threads=%s  dentro=%ld  tempo=%.3f s\n",
        modo, n, argv[2], dentro, omp_get_wtime() - t0);
    return 0;
}
