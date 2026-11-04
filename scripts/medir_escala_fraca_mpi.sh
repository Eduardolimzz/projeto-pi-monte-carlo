#!/usr/bin/env bash
# Escalabilidade fraca MPI: N cresce proporcionalmente ao numero de processos.
# Por configuracao, descarta uma execucao de aquecimento e grava cinco medidas.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

N0="${N0:-100000000}"
PROCESSOS=(${PROCESSOS:-1 2 4 8 12 16 20})
REPETICOES="${REPETICOES:-6}"
AQUECIMENTOS=1
MPIEXEC="${MPIEXEC:-mpirun}"
MPIEXEC_ARGS=(${MPIEXEC_ARGS:---use-hwthread-cpus})
BIN_MPI="mpi/pi_mpi"
CSV="resultados/resultado_escala_fraca_mpi.csv"
NUCLEOS="$(nproc)"

mkdir -p resultados
echo ">> compilando"
make mpi

regex_mpi='n=([0-9]+)[[:space:]]+processos=([0-9]+)[[:space:]]+pi=([0-9.]+)[[:space:]]+dentro=([0-9]+)[[:space:]]+tempo=([0-9.]+)[[:space:]]s[[:space:]]+mpi_reduce=([0-9.]+)[[:space:]]s'
echo "N0,processos,N,repeticao,pi,dentro,tempo_s,mpi_reduce_s" > "$CSV"

for p in "${PROCESSOS[@]}"; do
    if ((p > NUCLEOS)); then
        echo ">> processos=$p ignorado (a maquina tem $NUCLEOS nucleos logicos)"
        continue
    fi

    n=$((N0 * p))
    echo ">> processos=$p  N=$n"

    for ((execucao = 1; execucao <= REPETICOES; execucao++)); do
        saida="$("$MPIEXEC" "${MPIEXEC_ARGS[@]}" -np "$p" "./$BIN_MPI" "$n")"
        if [[ ! "$saida" =~ $regex_mpi ]]; then
            echo "erro: nao consegui interpretar a saida MPI: $saida" >&2
            exit 1
        fi

        pi="${BASH_REMATCH[3]}"
        dentro="${BASH_REMATCH[4]}"
        tempo="${BASH_REMATCH[5]}"
        reducao="${BASH_REMATCH[6]}"

        if ((execucao <= AQUECIMENTOS)); then
            echo "   [aquecimento, descartado] $saida"
            continue
        fi

        repeticao=$((execucao - AQUECIMENTOS))
        echo "   [rep $repeticao] $saida"
        echo "$N0,$p,$n,$repeticao,$pi,$dentro,$tempo,$reducao" >> "$CSV"
    done
done

echo ">> pronto: $CSV"
