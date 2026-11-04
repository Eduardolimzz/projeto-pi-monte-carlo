#!/usr/bin/env bash
# Mede o baseline sequencial e a versao MPI na mesma maquina.
# Por configuracao, descarta uma execucao de aquecimento e grava cinco medidas.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

TAMANHOS=(${TAMANHOS:-100000000 500000000 1000000000})
PROCESSOS=(${PROCESSOS:-1 2 4 8 12 16 20})
REPETICOES="${REPETICOES:-6}"
AQUECIMENTOS=1
MPIEXEC="${MPIEXEC:-mpirun}"
MPIEXEC_ARGS=(${MPIEXEC_ARGS:---use-hwthread-cpus})
BIN_SEQ="baseline/pi_seq"
BIN_MPI="mpi/pi_mpi"
CSV="resultados/resultado_mpi.csv"
INFO="resultados/maquina_mpi.txt"
NUCLEOS="$(nproc)"

mkdir -p resultados

echo ">> compilando"
make seq mpi

echo ">> coletando dados da maquina em $INFO"
{
    echo "# Ambiente de medicao MPI"
    echo "# gerado por scripts/medir_mpi.sh em $(date -Is)"
    echo
    echo "## CPU (lscpu)"
    lscpu
    echo
    echo "nproc: $NUCLEOS"
    echo "MPI launcher: $MPIEXEC ${MPIEXEC_ARGS[*]}"
    echo
    echo "## Memoria (free -h)"
    free -h
    echo
    echo "## Sistema (uname -srm)"
    uname -srm
    echo
    echo "## Compilador MPI (mpic++ --showme:version)"
    mpic++ --showme:version
    echo
    echo "## Compilacao"
    make -B -n seq mpi
} > "$INFO"

regex_seq='n=([0-9]+)[[:space:]]+pi=([0-9.]+)[[:space:]]+dentro=([0-9]+)[[:space:]]+tempo=([0-9.]+)[[:space:]]s'
regex_mpi='n=([0-9]+)[[:space:]]+processos=([0-9]+)[[:space:]]+pi=([0-9.]+)[[:space:]]+dentro=([0-9]+)[[:space:]]+tempo=([0-9.]+)[[:space:]]s[[:space:]]+mpi_reduce=([0-9.]+)[[:space:]]s'

medir_sequencial() {
    local n="$1"
    local execucao saida pi dentro tempo repeticao
    REFERENCIA=""

    for ((execucao = 1; execucao <= REPETICOES; execucao++)); do
        saida="$("./$BIN_SEQ" "$n")"
        if [[ ! "$saida" =~ $regex_seq ]]; then
            echo "erro: nao consegui interpretar a saida sequencial: $saida" >&2
            exit 1
        fi
        pi="${BASH_REMATCH[2]}"
        dentro="${BASH_REMATCH[3]}"
        tempo="${BASH_REMATCH[4]}"

        if [[ -z "$REFERENCIA" ]]; then
            REFERENCIA="$dentro"
        elif [[ "$dentro" != "$REFERENCIA" ]]; then
            echo "erro: o baseline variou para N=$n ($REFERENCIA versus $dentro)" >&2
            exit 1
        fi

        if ((execucao <= AQUECIMENTOS)); then
            echo "   [seq aquecimento, descartado] $saida"
            continue
        fi

        repeticao=$((execucao - AQUECIMENTOS))
        echo "   [seq rep $repeticao] $saida"
        echo "seq,$n,1,$repeticao,$pi,$dentro,$tempo,0" >> "$CSV"
    done
}

medir_mpi() {
    local n="$1" processos="$2"
    local execucao saida pi dentro tempo reducao repeticao

    for ((execucao = 1; execucao <= REPETICOES; execucao++)); do
        saida="$("$MPIEXEC" "${MPIEXEC_ARGS[@]}" -np "$processos" "./$BIN_MPI" "$n")"
        if [[ ! "$saida" =~ $regex_mpi ]]; then
            echo "erro: nao consegui interpretar a saida MPI: $saida" >&2
            exit 1
        fi
        pi="${BASH_REMATCH[3]}"
        dentro="${BASH_REMATCH[4]}"
        tempo="${BASH_REMATCH[5]}"
        reducao="${BASH_REMATCH[6]}"

        if [[ "$dentro" != "$REFERENCIA" ]]; then
            echo "erro: resultado diferente do baseline para N=$n processos=$processos (baseline=$REFERENCIA mpi=$dentro)" >&2
            exit 1
        fi

        if ((execucao <= AQUECIMENTOS)); then
            echo "   [MPI aquecimento, descartado] $saida"
            continue
        fi

        repeticao=$((execucao - AQUECIMENTOS))
        echo "   [MPI rep $repeticao] $saida"
        echo "mpi,$n,$processos,$repeticao,$pi,$dentro,$tempo,$reducao" >> "$CSV"
    done
}

echo "versao,N,processos,repeticao,pi,dentro,tempo_s,mpi_reduce_s" > "$CSV"

for n in "${TAMANHOS[@]}"; do
    echo ">> N=$n  versao=seq"
    medir_sequencial "$n"

    for p in "${PROCESSOS[@]}"; do
        if ((p > NUCLEOS)); then
            echo ">> N=$n processos=$p ignorado (a maquina tem $NUCLEOS nucleos logicos)"
            continue
        fi
        echo ">> N=$n  versao=mpi  processos=$p"
        medir_mpi "$n" "$p"
    done
done

echo ">> pronto: $CSV e $INFO"
