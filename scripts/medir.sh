#!/usr/bin/env bash
#
# medir.sh — mede o baseline sequencial da estimativa de pi por Monte Carlo
# Programacao Paralela (CCO085) · IESB 2026/2
#
# Protocolo (conforme sequencial/README_professor.md):
#   - tamanhos N = 1e8, 5e8 e 1e9 passados como argv[1] do binario;
#   - 6 execucoes por tamanho, sendo a 1a aquecimento de cache (descartada);
#   - o tempo registrado e o que o PROPRIO programa imprime (clock_gettime
#     em torno do laco), nunca uma medicao externa com date/time.
#
# Saidas: resultados/baseline.csv e resultados/maquina.txt

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

BIN="sequencial/pi_seq"
DIR_SAIDA="resultados"
CSV="$DIR_SAIDA/baseline.csv"
MAQUINA="$DIR_SAIDA/maquina.txt"

TAMANHOS=(100000000 500000000 1000000000)
REPETICOES=6          # a 1a e aquecimento
AQUECIMENTOS=1

mkdir -p "$DIR_SAIDA"

echo ">> compilando"
make

if [[ ! -x "$BIN" ]]; then
    echo "erro: binario $BIN nao encontrado apos o make" >&2
    exit 1
fi

# ---------------------------------------------------------------- maquina.txt
echo ">> coletando dados da maquina em $MAQUINA"
{
    echo "# Ambiente de medicao do baseline"
    echo "# gerado por scripts/medir.sh em $(date -Is)"
    echo

    echo "## CPU (lscpu)"
    if command -v lscpu >/dev/null 2>&1; then
        lscpu
    else
        echo "lscpu indisponivel; conteudo de /proc/cpuinfo:"
        cat /proc/cpuinfo
    fi
    echo
    echo "nproc: $(nproc)"
    echo

    echo "## Memoria (free -h)"
    if command -v free >/dev/null 2>&1; then
        free -h
    else
        echo "free indisponivel; conteudo de /proc/meminfo:"
        cat /proc/meminfo
    fi
    echo

    echo "## Sistema (uname -a)"
    uname -a
    echo
    echo "## Distribuicao (/etc/os-release)"
    if [[ -r /etc/os-release ]]; then
        cat /etc/os-release
    else
        echo "/etc/os-release indisponivel"
    fi
    echo

    echo "## Compilador (g++ --version)"
    g++ --version
    echo
    echo "## Flags de compilacao usadas pelo Makefile"
    make -B -n seq 2>/dev/null || true
} > "$MAQUINA"

# ------------------------------------------------------------------ medicoes
echo ">> medindo (${#TAMANHOS[@]} tamanhos x $REPETICOES execucoes)"
echo "N,repeticao,pi,dentro,tempo_s" > "$CSV"

for n in "${TAMANHOS[@]}"; do
    echo "-- N=$n"
    for (( execucao = 1; execucao <= REPETICOES; execucao++ )); do
        saida="$("./$BIN" "$n")"

        regex='pi=([0-9.]+)[[:space:]]+dentro=([0-9]+)[[:space:]]+tempo=([0-9.]+)'
        if [[ ! "$saida" =~ $regex ]]; then
            echo "erro: nao consegui interpretar a saida do programa:" >&2
            echo "  $saida" >&2
            exit 1
        fi
        pi="${BASH_REMATCH[1]}"
        dentro="${BASH_REMATCH[2]}"
        tempo="${BASH_REMATCH[3]}"

        if (( execucao <= AQUECIMENTOS )); then
            echo "   [aquecimento, descartado] $saida"
            continue
        fi

        repeticao=$(( execucao - AQUECIMENTOS ))
        echo "   [rep $repeticao] $saida"
        echo "$n,$repeticao,$pi,$dentro,$tempo" >> "$CSV"
    done
done

echo ">> pronto: $CSV e $MAQUINA"
