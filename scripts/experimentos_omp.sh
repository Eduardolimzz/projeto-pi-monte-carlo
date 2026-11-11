#!/usr/bin/env bash
#
# experimentos_omp.sh — reproduz os experimentos de apoio da analise do OpenMP
# Programacao Paralela (CCO085) · IESB 2026/2
#
# 1) custo de proteger o contador com reduction, atomic ou critical;
# 2) diagnostico por thread: espera no fim do laco com static e dynamic.
# Cada configuracao roda 3 vezes (sem descartar aquecimento: o objetivo e a
# comparacao entre configuracoes, nao um tempo de referencia).
#
# Uso:   ./scripts/experimentos_omp.sh
# Saida: no terminal e em resultados/experimentos_omp.txt

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

N_SINC="${N_SINC:-20000000}"
N_DIAG="${N_DIAG:-1000000000}"
REPETICOES="${REPETICOES:-3}"
NUCLEOS="$(nproc)"
SAIDA="resultados/experimentos_omp.txt"

make seq exp

mkdir -p resultados

{
    echo "# Experimentos de apoio — OpenMP"
    echo "# gerado por scripts/experimentos_omp.sh em $(date -Is)"
    echo "# nproc: $NUCLEOS"
    echo
    echo "## baseline sequencial, N=$N_SINC"
    "./baseline/pi_seq" "$N_SINC"
    echo
    echo "## reduction x atomic x critical, N=$N_SINC"
    for t in 1 8 20; do
        if (( t > NUCLEOS )); then
            echo "threads=$t ignorado (a maquina tem so $NUCLEOS nucleos logicos)"
            continue
        fi
        for modo in reduction atomic critical; do
            for (( r = 1; r <= REPETICOES; r++ )); do
                "./openmp/experimentos/comparar_sincronizacao" "$N_SINC" "$t" "$modo"
            done
        done
        echo
    done
    echo "## espera no fim do laco, N=$N_DIAG"
    for t in 20 8; do
        if (( t > NUCLEOS )); then
            echo "threads=$t ignorado (a maquina tem so $NUCLEOS nucleos logicos)"
            continue
        fi
        for cfg in "static 0" "dynamic 8"; do
            for (( r = 1; r <= REPETICOES; r++ )); do
                # $cfg sem aspas de proposito: "dynamic 8" vira dois argumentos
                "./openmp/experimentos/diagnostico_threads" "$N_DIAG" "$t" $cfg
            done
        done
    done
} 2>&1 | tee "$SAIDA"

echo ">> pronto: $SAIDA"
