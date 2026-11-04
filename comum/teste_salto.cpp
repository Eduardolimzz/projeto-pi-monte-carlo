/* Teste do salto do xorshift: saltar(k) tem que dar o mesmo estado
 * que chamar xorshift k vezes, partindo da semente do baseline.
 *
 * Compilar: g++ -O2 -Wall -o teste_salto teste_salto.cpp
 * Executar: ./teste_salto
 */
#include <cstdio>
#include "xorshift.h"

int main()
{
    TabelaSalto t;
    montar_tabela_salto(t);

    const uint64_t semente = 88172645463325252ULL;
    const uint64_t passos[] = {0, 1, 2, 3, 13, 64, 1000, 65537, 1234567, 100000007};
    int falhas = 0;

    for (uint64_t k : passos)
    {
        uint64_t esperado = semente;
        for (uint64_t i = 0; i < k; i++)
            xorshift(esperado);

        uint64_t obtido = saltar(t, semente, k);
        bool ok = (obtido == esperado);
        printf("k=%-10llu %s\n", (unsigned long long)k, ok ? "ok" : "FALHOU");
        if (!ok)
            falhas++;
    }

    uint64_t a = saltar(t, saltar(t, semente, 123456), 654321);
    bool composicao = (a == saltar(t, semente, 123456 + 654321));
    printf("saltar(a) depois saltar(b) == saltar(a+b): %s\n", composicao ? "ok" : "FALHOU");
    if (!composicao)
        falhas++;

    printf(falhas == 0 ? "TUDO OK\n" : "HOUVE FALHAS\n");
    return falhas != 0;
}
