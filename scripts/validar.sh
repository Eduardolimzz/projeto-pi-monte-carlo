#!/usr/bin/env bash
#
# validar.sh — confere se a versao OpenMP chega ao mesmo resultado do baseline
# Programacao Paralela (CCO085) · IESB 2026/2
#
# Para cada N, roda o baseline e depois o OpenMP com varios numeros de threads
# e politicas de escalonamento. O valor conferido e o "dentro" (a contagem exata
# de pontos dentro do circulo), que tem que ser identico ao do baseline.
#
# Uso: ./scripts/validar.sh
# Saida: OK/FALHOU por N e codigo de saida diferente de 0 se algo falhar.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

TAMANHOS=(${TAMANHOS:-1 1000 65537 1000003 50000000 100000000})
THREADS=(${THREADS:-1 2 4 7 8 16 20})
ESCALONAMENTOS=("static" "dynamic 1" "dynamic 8" "guided")

BIN_SEQ="baseline/pi_seq"
BIN_OMP="openmp/pi_omp"

make seq omp

regex='dentro=([0-9]+)'

dentro_de() {
    if [[ ! "$1" =~ $regex ]]; then
        echo "erro: nao consegui interpretar a saida do programa: $1" >&2
        exit 1
    fi
    echo "${BASH_REMATCH[1]}"
}

testes=0
falhas=0

for n in "${TAMANHOS[@]}"; do
    ref="$(dentro_de "$("./$BIN_SEQ" "$n")")"
    falhas_n=0

    for t in "${THREADS[@]}"; do
        for esc in "${ESCALONAMENTOS[@]}"; do
            # $esc sem aspas de proposito: "dynamic 8" vira dois argumentos
            obtido="$(dentro_de "$("./$BIN_OMP" "$n" "$t" $esc)")"
            testes=$(( testes + 1 ))
            if [[ "$obtido" != "$ref" ]]; then
                echo "FALHOU  N=$n threads=$t escalonamento=[$esc]  baseline=$ref openmp=$obtido"
                falhas=$(( falhas + 1 ))
                falhas_n=$(( falhas_n + 1 ))
            fi
        done
    done

    if (( falhas_n == 0 )); then
        echo "OK      N=$n  dentro=$ref"
    fi
done

echo
echo "testes=$testes  falhas=$falhas"
if (( falhas > 0 )); then
    exit 1
fi
