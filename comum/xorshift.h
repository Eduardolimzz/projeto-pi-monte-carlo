/* xorshift64 do baseline + salto na sequencia
 * IESB 2026/2 — CCO085
 *
 * Codigo compartilhado entre as versoes OpenMP e MPI.
 * O xorshift so usa XOR e deslocamentos de bits, entao e uma transformacao linear
 * sobre os 64 bits do estado: andar k passos equivale a aplicar a matriz M^k.
 */
#pragma once
#include <cstdint>

static inline uint64_t xorshift(uint64_t &s)
{
    s ^= s << 13;
    s ^= s >> 7;
    s ^= s << 17;
    return s;
}

// pot[j] guarda a matriz M^(2^j); pot[j][b] e a imagem do bit b
struct TabelaSalto
{
    uint64_t pot[64][64];
};

static inline uint64_t aplicar(const uint64_t (&coluna)[64], uint64_t v)
{
    uint64_t r = 0;
    for (int b = 0; b < 64; b++)
        if ((v >> b) & 1)
            r ^= coluna[b];
    return r;
}

static inline void montar_tabela_salto(TabelaSalto &t)
{
    for (int b = 0; b < 64; b++)
    {
        uint64_t e = 1ULL << b;
        xorshift(e);
        t.pot[0][b] = e;
    }
    for (int j = 1; j < 64; j++)
        for (int b = 0; b < 64; b++)
            t.pot[j][b] = aplicar(t.pot[j - 1], t.pot[j - 1][b]);
}

// devolve o estado depois de k chamadas de xorshift a partir de s
static inline uint64_t saltar(const TabelaSalto &t, uint64_t s, uint64_t k)
{
    for (int j = 0; j < 64; j++)
        if ((k >> j) & 1)
            s = aplicar(t.pot[j], s);
    return s;
}
