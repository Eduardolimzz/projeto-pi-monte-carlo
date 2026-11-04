#!/usr/bin/env bash
#
# medir_schedule.sh — compara as politicas de escalonamento do OpenMP
# Programacao Paralela (CCO085) · IESB 2026/2
#
# Fixa N e o numero de threads e varia a politica (static, dynamic, guided) e o
# chunk. O chunk e contado em BLOCOS de 65536 iteracoes; chunk 0 = padrao da politica.
# Protocolo: 6 execucoes por configuracao, a 1a e aquecimento (descartada), e o
# tempo e o que o PROPRIO programa imprime.
#
# Uso:   MAQUINA=alanna ./scripts/medir_schedule.sh
# Saida: resultados/resultado_schedule_<MAQUINA>.csv

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

MAQUINA="${MAQUINA:-local}"
N="${N:-1000000000}"
THREADS=(${THREADS:-8 20})
REPETICOES="${REPETICOES:-6}"
AQUECIMENTOS=1
CONFIGS=("static 0" "static 1" "dynamic 1" "dynamic 8" "dynamic 64" "guided 0" "guided 8")

BIN_OMP="openmp/pi_omp"
CSV="resultados/resultado_schedule_${MAQUINA}.csv"
NUCLEOS="$(nproc)"

mkdir -p resultados

echo ">> compilando"
make omp

regex='pi=([0-9.]+)[[:space:]]+dentro=([0-9]+)[[:space:]]+tempo=([0-9.]+)'

echo "politica,chunk,N,threads,repeticao,pi,dentro,tempo_s" > "$CSV"

for t in "${THREADS[@]}"; do
    if (( t > NUCLEOS )); then
        echo ">> threads=$t ignorado (a maquina tem so $NUCLEOS nucleos logicos)"
        continue
    fi

    for cfg in "${CONFIGS[@]}"; do
        read -r politica chunk <<< "$cfg"
        echo ">> N=$N  threads=$t  politica=$politica  chunk=$chunk"

        for (( execucao = 1; execucao <= REPETICOES; execucao++ )); do
            saida="$("./$BIN_OMP" "$N" "$t" "$politica" "$chunk")"

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
            echo "$politica,$chunk,$N,$t,$repeticao,${BASH_REMATCH[1]},${BASH_REMATCH[2]},${BASH_REMATCH[3]}" >> "$CSV"
        done
    done
done

echo ">> pronto: $CSV"
