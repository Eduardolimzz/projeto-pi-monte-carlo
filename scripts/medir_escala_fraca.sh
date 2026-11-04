#!/usr/bin/env bash
#
# medir_escala_fraca.sh — escalabilidade fraca da versao OpenMP
# Programacao Paralela (CCO085) · IESB 2026/2
#
# O trabalho por thread fica fixo (N0 pontos) e o N total cresce com as threads:
# N = N0 * threads. Se a versao escalasse perfeitamente, o tempo seria o mesmo
# para qualquer numero de threads.
# Protocolo: 6 execucoes por configuracao, a 1a e aquecimento (descartada), e o
# tempo e o que o PROPRIO programa imprime.
#
# Uso:   ./scripts/medir_escala_fraca.sh
# Saida: resultados/resultado_escala_fraca.csv

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

N0="${N0:-100000000}"
THREADS=(${THREADS:-1 2 4 8 16 20})
REPETICOES="${REPETICOES:-6}"
AQUECIMENTOS=1

BIN_OMP="openmp/pi_omp"
CSV="resultados/resultado_escala_fraca.csv"
NUCLEOS="$(nproc)"

mkdir -p resultados

echo ">> compilando"
make omp

regex='pi=([0-9.]+)[[:space:]]+dentro=([0-9]+)[[:space:]]+tempo=([0-9.]+)'

echo "N0,threads,N,repeticao,pi,dentro,tempo_s" > "$CSV"

for t in "${THREADS[@]}"; do
    if (( t > NUCLEOS )); then
        echo ">> threads=$t ignorado (a maquina tem so $NUCLEOS nucleos logicos)"
        continue
    fi

    n=$(( N0 * t ))
    echo ">> threads=$t  N=$n"

    for (( execucao = 1; execucao <= REPETICOES; execucao++ )); do
        saida="$("./$BIN_OMP" "$n" "$t")"

        if [[ ! "$saida" =~ $regex ]]; then
            echo "erro: nao consegui interpretar a saida do programa:" >&2
            echo "  $saida" >&2
            exit 1
        fi

        if (( execucao <= AQUECIMENTOS )); then
            echo "   [aquecimento, descartado] $saida"
            continue
        fi

        repeticao=$(( execucao - AQUECIMENTOS ))
        echo "   [rep $repeticao] $saida"
        echo "$N0,$t,$n,$repeticao,${BASH_REMATCH[1]},${BASH_REMATCH[2]},${BASH_REMATCH[3]}" >> "$CSV"
    done
done

echo ">> pronto: $CSV"
