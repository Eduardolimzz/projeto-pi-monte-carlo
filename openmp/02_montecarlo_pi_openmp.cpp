/* Versao OpenMP — Estimativa de pi por Monte Carlo
 * IESB 2026/2 — CCO085 — Frente OpenMP
 *
 * Compilar: g++ -O2 -fopenmp -I../comum -o 02_montecarlo_pi_openmp 02_montecarlo_pi_openmp.cpp
 * Executar: ./02_montecarlo_pi_openmp 50000000 4                (n=50M, 4 threads, static)
 *           ./02_montecarlo_pi_openmp 50000000 4 dynamic 8      (escalonamento e chunk, em blocos)
 */

/* Decisoes de projeto e discussao dos resultados
 *
 * Padrao: laco paralelo sobre blocos de 65536 iteracoes. As iteracoes sao
 * independentes e iguais, entao sections e tasks nao se aplicam.
 *
 * Resultado exato: cada bloco salta o xorshift ate o seu ponto de partida
 * (comum/xorshift.h). O "dentro" fica igual ao do baseline para qualquer
 * numero de threads e escalonamento (scripts/validar.sh).
 *
 * Condicao de corrida: "dentro" usa reduction(+:dentro). Cada thread soma numa
 * copia privada e o OpenMP combina no fim. critical e atomic dao o mesmo
 * resultado, mas sincronizam a cada incremento: com N=20M e 8 threads levaram
 * 6,09 s e 0,81 s, contra 0,049 s do reduction (sequencial: 0,23 s).
 * Dados em resultados/experimentos_omp.txt.
 *
 * Escalonamento: schedule(runtime), static por padrao. Com 8 threads static,
 * dynamic e guided empatam. Com 20 threads as threads ficam com velocidades
 * diferentes: no static as mais rapidas esperam em media de 11 a 24% do tempo
 * pelas mais lentas (dynamic: ate 1,5%), em 10 repeticoes de
 * openmp/experimentos/diagnostico_threads.cpp. O ganho em tempo total do
 * dynamic variou de 2% a 31% entre repeticoes.
 *
 * Speedup (N=1e9, i7-13700H): 7,5x com 8 threads, 13,5x com 16 e 12,2x com 20
 * (resultados/resultado_openmp.csv). Amdahl com P=0,999998 preve cerca de 20x
 * com 20 threads, entao a fracao sequencial nao explica a diferenca. Causa
 * medida: desbalanceamento entre threads. Hipotese nao comprovada:
 * hyper-threading e nucleos de eficiencia. Sem medir, por raciocinio: nao ha
 * false sharing (nada compartilhado e escrito no laco) nem limite de banda de
 * memoria (o laco nao acessa vetores).
 */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <ctime>
#include <omp.h>
#include "xorshift.h"

static const long BLOCO = 65536;

static double agora()
{
    timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
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

    const uint64_t semente = 88172645463325252ULL;
    long dentro = 0;
    long blocos = (n + BLOCO - 1) / BLOCO;

    double t0 = agora();

    TabelaSalto tabela;
    montar_tabela_salto(tabela);

    #pragma omp parallel for schedule(runtime) reduction(+:dentro)
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

    double pi = 4.0 * (double)dentro / (double)n;
    double t1 = agora();

    printf("n=%ld  threads=%d  schedule=%s  chunk=%d  pi=%.6f  dentro=%ld  tempo=%.6f s\n",
        n, omp_get_max_threads(), nome_sched, chunk, pi, dentro, t1 - t0);
    return 0;
}
