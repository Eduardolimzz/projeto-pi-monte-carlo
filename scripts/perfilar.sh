#!/usr/bin/env bash
#
# perfilar.sh — perfilamento do baseline sequencial (estimativa de pi, Monte Carlo)
# Programacao Paralela (CCO085) · IESB 2026/2
#
# O que faz, para N = 1e9:
#   a) mede o tempo TOTAL do processo com /usr/bin/time -v e compara com o
#      tempo do LACO que o proprio programa imprime (clock_gettime);
#   b) tenta distribuicao por funcao com perf; se o perf nao puder abrir
#      eventos (kernel.perf_event_paranoid restritivo), cai para gprof;
#      se nenhum dos dois funcionar, avisa e sai com erro — nao inventa numero;
#   c) 1 aquecimento + 5 repeticoes, usando a media das repeticoes.
#
# O codigo de referencia e o Makefile NAO sao alterados: o binario instrumentado
# para gprof e compilado com outro nome, dentro de um diretorio temporario.
#
# Saidas:
#   resultados/perfil.txt  — relatorio bruto (time -v, perf/gprof, medias)
#   resultados/perfil.csv  — trecho,tempo_s,percentual
#   resultados/amdahl.csv  — p,speedup_amdahl,eficiencia_amdahl

set -euo pipefail

# Locale C em todo o script: no pt_BR o separador decimal e virgula, e tanto o
# printf do bash quanto o awk e o EPOCHREALTIME passam a produzir/recusar
# numeros com ponto. Sem isto as contas silenciosamente zeram ou falham.
export LC_ALL=C

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

FONTE="sequencial/02_montecarlo_pi.cpp"
BIN="sequencial/pi_seq"
DIR_SAIDA="resultados"
PERFIL_TXT="$DIR_SAIDA/perfil.txt"
PERFIL_CSV="$DIR_SAIDA/perfil.csv"
AMDAHL_CSV="$DIR_SAIDA/amdahl.csv"

N=1000000000
REPETICOES=5
PROCESSADORES=(1 2 4 6 8 12 16)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DIR_SAIDA"

echo ">> compilando o baseline (make)"
make
if [[ ! -x "$BIN" ]]; then
    echo "erro: binario $BIN nao encontrado apos o make" >&2
    exit 1
fi

# converte "h:mm:ss(.ss)" ou "m:ss(.ss)" em segundos
segundos_de() {
    LC_ALL=C awk -v t="$1" 'BEGIN{
        n = split(t, p, ":")
        s = 0
        for (i = 1; i <= n; i++) s = s * 60 + p[i]
        printf "%.6f", s
    }'
}

# ------------------------------------------------- (a) total x laco, N e reps
# Duas passadas, porque as ferramentas tem resolucoes diferentes:
#   A1: /usr/bin/time -v  -> user/sys/RSS e o wall clock DELE, que so tem
#       centissegundos (formato "m:ss.cc"). Como o overhead fora do laco e da
#       ordem de poucos ms, essa resolucao nao consegue separar laco de total
#       (chega a dar total < laco, o que produziria f > 1).
#   A2: relogio do proprio shell (EPOCHREALTIME, microssegundos) em volta do
#       processo -> total de alta resolucao, usado para calcular f.
echo ">> medindo tempo total x tempo do laco (N=$N, 1 aquecimento + $REPETICOES repeticoes)"

MEDIDAS="$TMP/medidas.txt"   # laco total_hr
: > "$MEDIDAS"

saida_prog="$TMP/prog.txt"

echo "   -- passada A2: total em alta resolucao (EPOCHREALTIME)"
for (( execucao = 0; execucao <= REPETICOES; execucao++ )); do
    inicio="$EPOCHREALTIME"
    "./$BIN" "$N" > "$saida_prog"
    fim="$EPOCHREALTIME"

    linha="$(cat "$saida_prog")"
    if [[ ! "$linha" =~ tempo=([0-9.]+) ]]; then
        echo "erro: nao consegui ler o tempo impresso pelo programa:" >&2
        echo "  $linha" >&2
        exit 1
    fi
    laco="${BASH_REMATCH[1]}"
    total="$(awk -v a="$inicio" -v b="$fim" 'BEGIN{printf "%.6f", b-a}')"

    if (( execucao == 0 )); then
        echo "      [aquecimento, descartado] laco=${laco}s total=${total}s"
        continue
    fi

    echo "      [rep $execucao] laco=${laco}s total=${total}s"
    echo "$laco $total" >> "$MEDIDAS"
done

MEDIDAS_TIME="$TMP/medidas_time.txt"   # elapsed user sys rss_kb
: > "$MEDIDAS_TIME"

echo "   -- passada A1: /usr/bin/time -v"
for (( execucao = 1; execucao <= REPETICOES; execucao++ )); do
    saida_time="$TMP/time_$execucao.txt"
    /usr/bin/time -v -o "$saida_time" "./$BIN" "$N" > "$saida_prog"

    bruto_total="$(grep -oP 'Elapsed \(wall clock\) time.*?:\s*\K[0-9:.]+' "$saida_time" || true)"
    if [[ -z "$bruto_total" ]]; then
        echo "erro: nao consegui ler o tempo total em $saida_time" >&2
        exit 1
    fi
    elapsed="$(segundos_de "$bruto_total")"
    usuario="$(grep -oP 'User time \(seconds\):\s*\K[0-9.]+' "$saida_time")"
    sistema="$(grep -oP 'System time \(seconds\):\s*\K[0-9.]+' "$saida_time")"
    rss="$(grep -oP 'Maximum resident set size \(kbytes\):\s*\K[0-9]+' "$saida_time")"

    echo "      [rep $execucao] elapsed=${elapsed}s user=${usuario}s sys=${sistema}s rss=${rss}kB"
    echo "$elapsed $usuario $sistema $rss" >> "$MEDIDAS_TIME"
done

# medias
read -r LACO_MEDIO TOTAL_MEDIO F <<< "$(
    awk '{l+=$1; t+=$2; n++}
    END{printf "%.6f %.6f %.8f", l/n, t/n, (l/n)/(t/n)}' "$MEDIDAS"
)"
read -r ELAPSED_MEDIO USER_MEDIO SYS_MEDIO RSS_MEDIO <<< "$(
    awk '{e+=$1; u+=$2; s+=$3; r+=$4; n++}
    END{printf "%.6f %.6f %.6f %.0f", e/n, u/n, s/n, r/n}' "$MEDIDAS_TIME"
)"

OVERHEAD="$(awk -v t="$TOTAL_MEDIO" -v l="$LACO_MEDIO" 'BEGIN{printf "%.6f", t-l}')"

# f >= 1 significaria que a medicao nao conseguiu enxergar nada fora do laco;
# nesse caso Amdahl daria divisao por zero ou speedup negativo. Melhor parar.
if awk -v f="$F" 'BEGIN{exit !(f >= 1)}'; then
    echo "erro: f=$F >= 1 — a medicao do total nao resolveu o custo fora do laco." >&2
    echo "      Nao da para calcular Amdahl com este dado; nada foi arredondado." >&2
    exit 1
fi

echo ">> laco medio=${LACO_MEDIO}s  total medio=${TOTAL_MEDIO}s  fora do laco=${OVERHEAD}s  f=${F}"

# ------------------------------------------------------ (b) perf, senao gprof
echo ">> distribuicao por funcao"
FERRAMENTA=""
PERF_SAIDA="$TMP/perf.txt"
GPROF_SAIDA="$TMP/gprof.txt"
PERF_ERRO=""

if command -v perf >/dev/null 2>&1; then
    if perf record -q -o "$TMP/perf.data" "./$BIN" 1000000 > /dev/null 2> "$TMP/perf_erro.txt"; then
        perf report -i "$TMP/perf.data" --stdio 2>/dev/null > "$PERF_SAIDA" || true
        if [[ -s "$PERF_SAIDA" ]]; then
            FERRAMENTA="perf"
            echo "   usando perf"
            perf record -q -o "$TMP/perf.data" "./$BIN" "$N" > /dev/null 2>&1
            perf report -i "$TMP/perf.data" --stdio 2>/dev/null > "$PERF_SAIDA"
        fi
    else
        PERF_ERRO="$(tail -3 "$TMP/perf_erro.txt" 2>/dev/null || true)"
        echo "   perf indisponivel (nao conseguiu abrir eventos); tentando gprof"
    fi
else
    PERF_ERRO="perf nao instalado"
    echo "   perf nao instalado; tentando gprof"
fi

if [[ -z "$FERRAMENTA" ]] && command -v gprof >/dev/null 2>&1; then
    echo "   compilando binario instrumentado (-pg -g) em $TMP"
    g++ -O2 -Wall -pg -g -o "$TMP/pi_pg" "$FONTE"
    (
        cd "$TMP"
        ./pi_pg "$N" > pg_prog.txt
        gprof -b ./pi_pg gmon.out > "$GPROF_SAIDA"
    )
    if [[ -s "$GPROF_SAIDA" ]]; then
        FERRAMENTA="gprof"
        echo "   usando gprof"
    fi
fi

if [[ -z "$FERRAMENTA" ]]; then
    echo "erro: nem perf nem gprof funcionaram nesta maquina." >&2
    echo "      perf: ${PERF_ERRO:-falhou}" >&2
    echo "      gprof: nao produziu saida." >&2
    echo "      Nenhum perfil por funcao foi gerado (nada foi estimado no lugar)." >&2
    exit 1
fi

# ----------------------------------------------------------------- perfil.csv
echo ">> escrevendo $PERFIL_CSV"
{
    echo "trecho,tempo_s,percentual"
    LC_ALL=C awk -v l="$LACO_MEDIO" -v o="$OVERHEAD" -v t="$TOTAL_MEDIO" 'BEGIN{
        printf "laco_montecarlo,%.6f,%.4f\n", l, 100*l/t
        printf "fora_do_laco,%.6f,%.4f\n", o, 100*o/t
        printf "total_processo,%.6f,%.4f\n", t, 100
    }'
} > "$PERFIL_CSV"

# ----------------------------------------------------------------- amdahl.csv
echo ">> escrevendo $AMDAHL_CSV (f=$F)"
{
    echo "p,speedup_amdahl,eficiencia_amdahl"
    for p in "${PROCESSADORES[@]}"; do
        LC_ALL=C awk -v f="$F" -v p="$p" 'BEGIN{
            s = 1 / ((1 - f) + f/p)
            printf "%d,%.6f,%.6f\n", p, s, s/p
        }'
    done
    LC_ALL=C awk -v f="$F" 'BEGIN{ printf "inf,%.6f,0.000000\n", 1/(1-f) }'
} > "$AMDAHL_CSV"

# ----------------------------------------------------------------- perfil.txt
echo ">> escrevendo $PERFIL_TXT"
{
    echo "=========================================================="
    echo " Perfilamento do baseline sequencial — pi por Monte Carlo"
    echo " gerado por scripts/perfilar.sh em $(date -Is)"
    echo "=========================================================="
    echo
    echo "Fonte .................. $FONTE (nao modificado)"
    echo "Binario medido ......... $BIN (flags do Makefile)"
    echo "N ...................... $N"
    echo "Repeticoes ............. 1 aquecimento + $REPETICOES medidas (media)"
    echo "Ferramenta por funcao .. $FERRAMENTA"
    echo
    echo "---------- (a) tempo total do processo x tempo do laco ----------"
    echo
    printf "%-26s %12s\n" "trecho" "media (s)"
    printf "%-26s %12.6f\n" "laco Monte Carlo" "$LACO_MEDIO"
    printf "%-26s %12.6f\n" "fora do laco" "$OVERHEAD"
    printf "%-26s %12.6f\n" "total do processo" "$TOTAL_MEDIO"
    echo
    printf "%-26s %12.6f\n" "elapsed (time -v)" "$ELAPSED_MEDIO"
    printf "%-26s %12.6f\n" "user time (time -v)" "$USER_MEDIO"
    printf "%-26s %12.6f\n" "system time (time -v)" "$SYS_MEDIO"
    printf "%-26s %12s\n"   "max RSS kB (time -v)" "$RSS_MEDIO"
    echo
    echo "f = tempo_do_laco / tempo_total = $F"
    echo
    echo "O tempo do laco e o que o programa imprime: clock_gettime(CLOCK_MONOTONIC)"
    echo "aberto antes do for e fechado depois do calculo de pi. Fica de fora a"
    echo "leitura de argv, a inicializacao da semente, o printf e todo o custo de"
    echo "processo (exec, ligacao dinamica, init/fini da libc, saida)."
    echo
    echo "NOTA SOBRE A RESOLUCAO: o wall clock do /usr/bin/time -v tem apenas"
    echo "centissegundos (formato m:ss.cc). Como o custo fora do laco e da ordem"
    echo "de milissegundos, esse campo chega a sair MENOR que o tempo do laco, o"
    echo "que daria f > 1. Por isso o total usado no calculo de f vem de uma"
    echo "segunda passada, com o relogio do shell (EPOCHREALTIME, microssegundos)"
    echo "em volta do processo. Esse total inclui o fork/exec do shell, entao"
    echo "superestima levemente o custo fora do laco — ou seja, subestima f, que"
    echo "e o lado conservador para Amdahl."
    echo
    echo "medidas individuais A2 (laco total_alta_resolucao):"
    cat "$MEDIDAS"
    echo
    echo "medidas individuais A1 (elapsed user sys rss_kB):"
    cat "$MEDIDAS_TIME"
    echo
    echo "---------- /usr/bin/time -v (ultima repeticao) ----------"
    echo
    cat "$TMP/time_$REPETICOES.txt"
    echo
    echo "---------- (b) distribuicao por funcao ($FERRAMENTA) ----------"
    echo
    if [[ "$FERRAMENTA" == "perf" ]]; then
        cat "$PERF_SAIDA"
    else
        if [[ -n "$PERF_ERRO" ]]; then
            echo "perf nao pode ser usado nesta maquina:"
            echo "$PERF_ERRO"
            echo "(kernel.perf_event_paranoid = $(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo 'n/d'))"
            echo
        fi
        echo "Binario instrumentado: g++ -O2 -Wall -pg -g (nome pi_pg, em diretorio temporario)"
        echo
        cat "$GPROF_SAIDA"
        echo
        echo "AVISO: com -O2 a funcao xorshift() e 'static inline' e some dentro de"
        echo "main(), e o laco nao e uma funcao propria. Por isso o gprof concentra"
        echo "praticamente todo o tempo em main(): a granularidade por funcao nao"
        echo "separa o laco do resto. A separacao confiavel entre laco e overhead e"
        echo "a do item (a), por relogio."
    fi
    echo
    echo "---------- (c) Amdahl ----------"
    echo
    echo "S(p) = 1 / ((1-f) + f/p),  E(p) = S(p)/p,  com f = $F"
    echo
    printf "%6s %14s %14s\n" "p" "speedup" "eficiencia"
    LC_ALL=C awk -F, 'NR>1{printf "%6s %14.4f %14.4f\n", $1, $2, $3}' "$AMDAHL_CSV"
} > "$PERFIL_TXT"

echo ">> pronto: $PERFIL_TXT, $PERFIL_CSV, $AMDAHL_CSV"
