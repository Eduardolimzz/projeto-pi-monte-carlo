#!/usr/bin/env bash
#
# validar.sh — confere se as versoes OpenMP e MPI chegam ao baseline
# Programacao Paralela (CCO085) · IESB 2026/2
#
# Para cada N, compara a contagem exata de pontos dentro do circulo com o
# baseline, variando threads/politicas OpenMP e numeros de processos MPI.
#
# Uso: ./scripts/validar.sh
# Saida: OK/FALHOU por N e codigo de saida diferente de 0 se algo falhar.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

TAMANHOS=(${TAMANHOS:-1 1000 65537 1000003 50000000 100000000})
THREADS=(${THREADS:-1 2 4 7 8 16 20})
PROCESSOS=(${PROCESSOS:-1 2 4 7 8 12 16 20})
ESCALONAMENTOS=("static" "dynamic 1" "dynamic 8" "guided")
MPIEXEC="${MPIEXEC:-mpirun}"
MPIEXEC_ARGS=(${MPIEXEC_ARGS:---use-hwthread-cpus})
NUCLEOS="$(nproc)"

BIN_SEQ="baseline/pi_seq"
BIN_OMP="openmp/pi_omp"
BIN_MPI="mpi/pi_mpi"

make seq omp mpi

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
        echo "OK OpenMP  N=$n  dentro=$ref"
    fi

    falhas_n=0
    for p in "${PROCESSOS[@]}"; do
        if (( p > NUCLEOS )); then
            echo "MPI       N=$n processos=$p ignorado (a maquina tem $NUCLEOS nucleos logicos)"
            continue
        fi

        obtido="$(dentro_de "$("$MPIEXEC" "${MPIEXEC_ARGS[@]}" -np "$p" "./$BIN_MPI" "$n")")"
        testes=$(( testes + 1 ))
        if [[ "$obtido" != "$ref" ]]; then
            echo "FALHOU MPI  N=$n processos=$p  baseline=$ref mpi=$obtido"
            falhas=$(( falhas + 1 ))
            falhas_n=$(( falhas_n + 1 ))
        fi
    done

    if (( falhas_n == 0 )); then
        echo "OK MPI      N=$n  dentro=$ref"
    fi
done

echo
echo "testes=$testes  falhas=$falhas"
if (( falhas > 0 )); then
    exit 1
fi
