#!/usr/bin/env bash
#
# medir_omp.sh — mede o baseline sequencial e a versao OpenMP na mesma maquina
# Programacao Paralela (CCO085) · IESB 2026/2
#
# Protocolo (o mesmo do baseline):
#   - N = 1e8, 5e8 e 1e9;
#   - 6 execucoes por configuracao, sendo a 1a aquecimento (descartada);
#   - o tempo e o que o PROPRIO programa imprime, nunca medicao externa.
#
# Uso:   MAQUINA=alanna ./scripts/medir_omp.sh
# Saida: resultados/resultado_openmp_<MAQUINA>.csv e resultados/maquina_<MAQUINA>.txt

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

MAQUINA="${MAQUINA:-local}"
THREADS=(${THREADS:-1 2 4 8 16 20})
TAMANHOS=(${TAMANHOS:-100000000 500000000 1000000000})
REPETICOES="${REPETICOES:-6}"
AQUECIMENTOS=1

BIN_SEQ="baseline/pi_seq"
BIN_OMP="openmp/pi_omp"
CSV="resultados/resultado_openmp_${MAQUINA}.csv"
INFO="resultados/maquina_${MAQUINA}.txt"
NUCLEOS="$(nproc)"

mkdir -p resultados

echo ">> compilando"
make seq omp

echo ">> coletando dados da maquina em $INFO"
{
    echo "# Ambiente de medicao ($MAQUINA)"
    echo "# gerado por scripts/medir_omp.sh em $(date -Is)"
    echo
    echo "## CPU (lscpu)"
    lscpu
    echo
    echo "nproc: $NUCLEOS"
    echo
    echo "## Memoria (free -h)"
    free -h
    echo
    echo "## Sistema (uname -a)"
    uname -a
    echo
    echo "## Compilador (g++ --version)"
    g++ --version
    echo
    echo "## Comandos de compilacao (make)"
    make -B -n seq omp
} > "$INFO"

regex='pi=([0-9.]+)[[:space:]]+dentro=([0-9]+)[[:space:]]+tempo=([0-9.]+)'

medir() {
    local versao="$1" bin="$2" n="$3" threads="$4"
    local args=("$n")
    if [[ "$versao" == "omp" ]]; then
        args+=("$threads")
    fi

    for (( execucao = 1; execucao <= REPETICOES; execucao++ )); do
        local saida
        saida="$("./$bin" "${args[@]}")"

        if [[ ! "$saida" =~ $regex ]]; then
            echo "erro: nao consegui interpretar a saida do programa:" >&2
            echo "  $saida" >&2
            exit 1
        fi

        if (( execucao <= AQUECIMENTOS )); then
            echo "   [aquecimento, descartado] $saida"
            continue
        fi

        local repeticao=$(( execucao - AQUECIMENTOS ))
        echo "   [rep $repeticao] $saida"
        echo "$versao,$n,$threads,$repeticao,${BASH_REMATCH[1]},${BASH_REMATCH[2]},${BASH_REMATCH[3]}" >> "$CSV"
    done
}

echo "versao,N,threads,repeticao,pi,dentro,tempo_s" > "$CSV"

for n in "${TAMANHOS[@]}"; do
    echo ">> N=$n  versao=seq"
    medir seq "$BIN_SEQ" "$n" 1

    for t in "${THREADS[@]}"; do
        if (( t > NUCLEOS )); then
            echo ">> N=$n  threads=$t ignorado (a maquina tem so $NUCLEOS nucleos logicos)"
            continue
        fi
        echo ">> N=$n  versao=omp  threads=$t"
        medir omp "$BIN_OMP" "$n" "$t"
    done
done

echo ">> pronto: $CSV e $INFO"
