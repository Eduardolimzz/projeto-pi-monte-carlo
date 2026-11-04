/* Versao MPI — Estimativa de pi por Monte Carlo
 * IESB 2026/2 — CCO085 — Frente MPI
 *
 * Cada processo recebe um intervalo contiguo das amostras do baseline. O salto
 * do xorshift posiciona o gerador no inicio do intervalo, mantendo a mesma
 * sequencia de pontos para qualquer quantidade de processos.
 *
 * Compilar: make mpi
 * Executar: mpirun -np 4 ./mpi/pi_mpi 50000000
 */
#include <mpi.h>

#include <cerrno>
#include <climits>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <inttypes.h>

#include "xorshift.h"

static const uint64_t SEMENTE = 88172645463325252ULL;

static bool ler_amostras(int argc, char **argv, uint64_t &n)
{
    if (argc > 2)
        return false;
    if (argc == 1)
    {
        n = 50000000ULL;
        return true;
    }

    if (argv[1][0] == '-')
        return false;

    errno = 0;
    char *fim = nullptr;
    unsigned long long valor = strtoull(argv[1], &fim, 10);
    if (errno == ERANGE || fim == argv[1] || *fim != '\0' || valor == 0 || valor > (unsigned long long)LONG_MAX)
        return false;

    n = (uint64_t)valor;
    return true;
}

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);

    int rank = 0;
    int processos = 1;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &processos);

    uint64_t n = 0;
    if (!ler_amostras(argc, argv, n))
    {
        if (rank == 0)
            fprintf(stderr, "uso: mpirun -np <processos> ./mpi/pi_mpi [amostras > 0]\n");
        MPI_Finalize();
        return 2;
    }

    const uint64_t qtd_processos = (uint64_t)processos;
    const uint64_t rank_u = (uint64_t)rank;
    const uint64_t base = n / qtd_processos;
    const uint64_t resto = n % qtd_processos;

    // Distribui o resto entre os primeiros processos. Os intervalos cobrem
    // [0, n) sem lacunas nem sobreposicao, inclusive quando n nao divide p.
    const uint64_t local_n = base + (rank_u < resto ? 1ULL : 0ULL);
    const uint64_t inicio = rank_u * base + (rank_u < resto ? rank_u : resto);

    uint64_t dentro_local = 0;
    uint64_t dentro_global = 0;
    double tempo_reducao_local = 0.0;
    double tempo_reducao_max = 0.0;
    double tempo_total_local = 0.0;
    double tempo_total_max = 0.0;

    MPI_Barrier(MPI_COMM_WORLD);
    const double t0 = MPI_Wtime();

    TabelaSalto tabela;
    montar_tabela_salto(tabela);
    uint64_t s = saltar(tabela, SEMENTE, 2ULL * inicio);

    for (uint64_t i = 0; i < local_n; i++)
    {
        const double x = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
        const double y = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
        if (x * x + y * y <= 1.0)
            dentro_local++;
    }

    const double t_reducao = MPI_Wtime();
    MPI_Reduce(&dentro_local, &dentro_global, 1, MPI_UINT64_T, MPI_SUM, 0, MPI_COMM_WORLD);
    tempo_reducao_local = MPI_Wtime() - t_reducao;

    tempo_total_local = MPI_Wtime() - t0;
    MPI_Reduce(&tempo_reducao_local, &tempo_reducao_max, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&tempo_total_local, &tempo_total_max, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

    if (rank == 0)
    {
        const double pi = 4.0 * (double)dentro_global / (double)n;
        printf("n=%" PRIu64 "  processos=%d  pi=%.6f  dentro=%" PRIu64
               "  tempo=%.6f s  mpi_reduce=%.6f s\n",
               n, processos, pi, dentro_global, tempo_total_max, tempo_reducao_max);
    }

    MPI_Finalize();
    return 0;
}
