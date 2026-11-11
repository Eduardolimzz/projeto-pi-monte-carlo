/* Experimento: o que cada thread faz durante o laço
 * IESB 2026/2 — CCO085 — Frente OpenMP
 *
 * Roda o mesmo laço por blocos da versao OpenMP e anota, por thread, quantos
 * blocos processou, quanto tempo ficou ocupada e quando terminou. A "espera no
 * fim" e quanto, em media, as threads ficam paradas esperando a mais lenta.
 *
 * Compilar: make exp
 * Executar: ./openmp/experimentos/diagnostico_threads 1000000000 20 dynamic 8
 *           (N, threads, static|dynamic|guided, chunk em blocos; 5o argumento
 *           qualquer imprime o detalhe de cada thread)
 */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <vector>
#include <omp.h>
#include "xorshift.h"

static const long BLOCO = 65536;

struct alignas(64) Marca
{
    long blocos = 0;
    double ocupado = 0;
    double fim = 0;
};

int main(int argc, char **argv)
{
    if (argc < 5)
    {
        fprintf(stderr, "uso: %s N threads static|dynamic|guided chunk [detalhe]\n", argv[0]);
        return 1;
    }

    long n = atol(argv[1]);
    int threads = atoi(argv[2]);
    const char *nome = argv[3];
    int chunk = atoi(argv[4]);
    bool detalhe = argc > 5;

    omp_sched_t tipo = omp_sched_static;
    if (strcmp(nome, "dynamic") == 0)
        tipo = omp_sched_dynamic;
    else if (strcmp(nome, "guided") == 0)
        tipo = omp_sched_guided;
    else if (strcmp(nome, "static") != 0)
    {
        fprintf(stderr, "escalonamento invalido: %s (use static, dynamic ou guided)\n", nome);
        return 1;
    }
    omp_set_num_threads(threads);
    omp_set_schedule(tipo, chunk);

    const uint64_t semente = 88172645463325252ULL;
    long blocos = (n + BLOCO - 1) / BLOCO;
    long dentro = 0;
    std::vector<Marca> marca(threads);
    TabelaSalto tabela;
    montar_tabela_salto(tabela);

    double t0 = omp_get_wtime();

    #pragma omp parallel for schedule(runtime) reduction(+:dentro)
    for (long b = 0; b < blocos; b++)
    {
        double a = omp_get_wtime();
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
        double z = omp_get_wtime();
        Marca &m = marca[omp_get_thread_num()];
        m.blocos++;
        m.ocupado += z - a;
        m.fim = z - t0;
    }

    double total = omp_get_wtime() - t0;
    double soma_fim = 0, max_fim = 0, min_fim = 1e30;
    long bmin = blocos, bmax = 0;
    for (int t = 0; t < threads; t++)
    {
        soma_fim += marca[t].fim;
        if (marca[t].fim > max_fim)
            max_fim = marca[t].fim;
        if (marca[t].fim < min_fim)
            min_fim = marca[t].fim;
        if (marca[t].blocos < bmin)
            bmin = marca[t].blocos;
        if (marca[t].blocos > bmax)
            bmax = marca[t].blocos;
        if (detalhe)
            printf("  thread %2d: blocos=%5ld  ocupado=%6.3f s  terminou em %6.3f s\n",
                t, marca[t].blocos, marca[t].ocupado, marca[t].fim);
    }
    double media_fim = soma_fim / threads;

    printf("%-7s chunk=%-2d threads=%2d  total=%.3f s  fim: min=%.3f media=%.3f max=%.3f  "
           "espera media no fim=%4.1f%%  blocos/thread: min=%ld max=%ld  dentro=%ld\n",
        nome, chunk, threads, total, min_fim, media_fim, max_fim,
        100.0 * (max_fim - media_fim) / max_fim, bmin, bmax, dentro);
    return 0;
}
