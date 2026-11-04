/*
 * Compilar: g++ -O2 -o montecarlo_pi_analise montecarlo_pi_analise.cpp
 * Executar: ./montecarlo_pi_analise 50000000
 *
 *Vou dividir o código em 3 partes, início, meio e fim dentro da main. 
 *Após a divisão, coloquei medido de tempo em cada parte para achar onde o tempo era mais gasto.
 *Pelo resultado da conta do tempo, o processador perdeu mais tempo na parte do loop, ou seja, a parte do meio.
 *
 */

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <ctime>
#include <chrono> // tempo com maior precisão
#include <sys/stat.h> // Para criação da pasta resultados
#include <sys/types.h>

static double agora() {
    timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

static inline uint64_t xorshift(uint64_t& s) {
    s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s;
}

// Garante que o caminho completo das pastas exista
void criar_diretorio_se_nao_existir(const char* caminho) {
#if defined(_WIN32)
    mkdir(caminho);
#else
    mkdir(caminho, 0777);
#endif
}

int main(int argc, char** argv) {
    //*Parte 1 - Inicialização
    auto start_teste1 = std::chrono::high_resolution_clock::now();
        long n = (argc > 1) ? atol(argv[1]) : 50000000L;
        uint64_t s = 88172645463325252ULL;   
        long dentro = 0;
    auto end_teste1 = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_teste1 = end_teste1 - start_teste1;

    //*Parte 2 - Hostpot por ser um loop
    auto start_teste2 = std::chrono::high_resolution_clock::now();
        double t0 = agora();
        for (long i = 0; i < n; i++) {
            double x = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
            double y = (xorshift(s) >> 11) * (1.0 / 9007199254740992.0);
            if (x*x + y*y <= 1.0) dentro++;
        }
    auto end_teste2 = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_teste2 = end_teste2 - start_teste2;

    //*Parte 3 - Finalização
    auto start_teste3 = std::chrono::high_resolution_clock::now();
        double pi = 4.0 * (double)dentro / (double)n;
        double t1 = agora();
    auto end_teste3 = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_teste3 = end_teste3 - start_teste3;

    double total_tempo = diff_teste1.count() + diff_teste2.count() + diff_teste3.count();

    printf("--------------Resultado---------------\n");
    printf("Amostra=%ld\n", n);
    printf("Pi=%.6f\n", pi);
    printf("Pontos dentro=%ld\n", dentro);

    printf("Parte 1 (Inicialização) : %.8f s (%.4f%%)\n", diff_teste1.count(), (diff_teste1.count() / total_tempo) * 100.0);
    printf("Parte 2 (Hotspot)       : %.8f s (%.4f%%)\n", diff_teste2.count(), (diff_teste2.count() / total_tempo) * 100.0);
    printf("Parte 3 (Finalização)   : %.8f s (%.4f%%)\n", diff_teste3.count(), (diff_teste3.count() / total_tempo) * 100.0);
    printf("Tempo Total Medido      : %.8f s\n", total_tempo);
    printf("Tempo: %.8f s\n", t1 - t0);

    // --- ESCRITA NO CSV NO CAMINHO ABSOLUTO SOLICITADO ---
    criar_diretorio_se_nao_existir("/lab/projeto-pi-monte-carlo");
    criar_diretorio_se_nao_existir("/lab/projeto-pi-monte-carlo/resultados");

    const char* caminho_csv = "/lab/projeto-pi-monte-carlo/resultados/resultado_perfilamento_baseline.csv";
    
    FILE* f = fopen(caminho_csv, "r");
    bool arquivo_existe = (f != NULL);
    if (f) fclose(f);

    f = fopen(caminho_csv, "a");
    if (f != NULL) {
        if (!arquivo_existe) {
            fprintf(f, "n,pi,dentro,tempo_p1_s,pct_p1,tempo_p2_s,pct_p2,tempo_p3_s,pct_p3,tempo_total_s\n");
        }

        fprintf(f, "%ld,%.6f,%ld,%.8f,%.4f,%.8f,%.4f,%.8f,%.4f,%.8f\n",
                n, pi, dentro,
                diff_teste1.count(), (diff_teste1.count() / total_tempo) * 100.0,
                diff_teste2.count(), (diff_teste2.count() / total_tempo) * 100.0,
                diff_teste3.count(), (diff_teste3.count() / total_tempo) * 100.0,
                total_tempo);

        fclose(f);
        printf("\n[✓] Dados gravados em: %s\n", caminho_csv);
    } else {
        printf("\n[!] Erro ao abrir/criar o arquivo em %s\n", caminho_csv);
    }

    return 0;
}