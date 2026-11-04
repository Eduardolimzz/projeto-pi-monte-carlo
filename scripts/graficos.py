#!/usr/bin/env python3
"""Gera os graficos do projeto a partir dos CSVs de resultados/.

Uso:   python scripts/graficos.py
Saida: resultados/graficos/*.png
"""
import csv
import os
import statistics
from collections import defaultdict

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import ScalarFormatter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTADOS = os.path.join(RAIZ, "resultados")
SAIDA = os.path.join(RESULTADOS, "graficos")

# fracao paralelizavel estimada no perfilamento do baseline (resultados/estimativa_baseline)
P_AMDAHL = 0.999998

CORES = {"static": "#1f77b4", "dynamic": "#ff7f0e", "guided": "#2ca02c"}
CORES_N = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728"]


def ler(nome):
    with open(os.path.join(RESULTADOS, nome), newline="") as f:
        return list(csv.DictReader(f))


def eixo_threads(ax, threads):
    ax.set_xscale("log", base=2)
    ax.set_xticks(threads)
    ax.xaxis.set_major_formatter(ScalarFormatter())
    ax.minorticks_off()
    ax.set_xlabel("threads")
    ax.grid(True, alpha=0.3)


def salvar(fig, nome):
    os.makedirs(SAIDA, exist_ok=True)
    caminho = os.path.join(SAIDA, f"{nome}.png")
    fig.tight_layout()
    fig.savefig(caminho, dpi=150)
    plt.close(fig)
    print("gerado:", os.path.relpath(caminho, RAIZ))


def graficos_speedup():
    tempos = defaultdict(list)
    for r in ler("resultado_openmp.csv"):
        tempos[(int(r["N"]), r["versao"], int(r["threads"]))].append(float(r["tempo_s"]))

    tamanhos = sorted({k[0] for k in tempos})
    threads = sorted({k[2] for k in tempos if k[1] == "omp"})
    mediana = {k: statistics.median(v) for k, v in tempos.items()}

    # tempo
    fig, ax = plt.subplots(figsize=(7, 4.5))
    for i, n in enumerate(tamanhos):
        med = [mediana[(n, "omp", t)] for t in threads]
        menor = [med[j] - min(tempos[(n, "omp", t)]) for j, t in enumerate(threads)]
        maior = [max(tempos[(n, "omp", t)]) - med[j] for j, t in enumerate(threads)]
        ax.errorbar(threads, med, yerr=[menor, maior], marker="o", capsize=3,
                    color=CORES_N[i], label=f"N = {n:.0e}")
        ax.axhline(mediana[(n, "seq", 1)], color=CORES_N[i], linestyle=":", alpha=0.7)
    ax.set_yscale("log")
    ax.set_ylabel("tempo (s)")
    ax.set_title("Tempo de execucao do OpenMP\npontilhado = baseline sequencial")
    eixo_threads(ax, threads)
    ax.legend()
    salvar(fig, "tempo")

    # speedup
    fig, ax = plt.subplots(figsize=(7, 4.5))
    for i, n in enumerate(tamanhos):
        base = mediana[(n, "seq", 1)]
        ax.plot(threads, [base / mediana[(n, "omp", t)] for t in threads], marker="o",
                color=CORES_N[i], label=f"N = {n:.0e}")
    ax.plot(threads, threads, "k--", label="ideal (S = threads)")
    ax.plot(threads, [1 / ((1 - P_AMDAHL) + P_AMDAHL / t) for t in threads], "k:",
            label=f"Amdahl (P = {P_AMDAHL})")
    ax.set_ylabel("speedup")
    ax.set_title("Speedup do OpenMP")
    eixo_threads(ax, threads)
    ax.legend()
    salvar(fig, "speedup")

    # eficiencia
    fig, ax = plt.subplots(figsize=(7, 4.5))
    for i, n in enumerate(tamanhos):
        base = mediana[(n, "seq", 1)]
        ax.plot(threads, [100 * base / mediana[(n, "omp", t)] / t for t in threads], marker="o",
                color=CORES_N[i], label=f"N = {n:.0e}")
    ax.axhline(100, color="k", linestyle="--")
    ax.set_ylabel("eficiencia (%)")
    ax.set_ylim(0, 110)
    ax.set_title("Eficiencia do OpenMP")
    eixo_threads(ax, threads)
    ax.legend()
    salvar(fig, "eficiencia")


def grafico_schedule():
    tempos = defaultdict(list)
    for r in ler("resultado_schedule.csv"):
        tempos[(int(r["threads"]), r["politica"], int(r["chunk"]))].append(float(r["tempo_s"]))

    threads = sorted({k[0] for k in tempos})
    configs = []
    for k in tempos:
        if (k[1], k[2]) not in configs:
            configs.append((k[1], k[2]))

    fig, eixos = plt.subplots(1, len(threads), figsize=(5.5 * len(threads), 4.5), squeeze=False)
    for ax, t in zip(eixos[0], threads):
        med = [statistics.median(tempos[(t, p, c)]) for p, c in configs]
        menor = [m - min(tempos[(t, p, c)]) for m, (p, c) in zip(med, configs)]
        maior = [max(tempos[(t, p, c)]) - m for m, (p, c) in zip(med, configs)]
        ax.bar(range(len(configs)), med, yerr=[menor, maior], capsize=3,
               color=[CORES[p] for p, _ in configs])
        ax.set_xticks(range(len(configs)))
        ax.set_xticklabels([f"{p}\nchunk {c}" for p, c in configs], fontsize=8)
        ax.set_ylabel("tempo (s)")
        ax.set_title(f"{t} threads")
        ax.grid(True, axis="y", alpha=0.3)
    fig.suptitle("Politicas de escalonamento - mediana e min/max; chunk em blocos de 65536")
    salvar(fig, "schedule")


def grafico_escala_fraca():
    tempos = defaultdict(list)
    n0 = None
    for r in ler("resultado_escala_fraca.csv"):
        tempos[int(r["threads"])].append(float(r["tempo_s"]))
        n0 = int(r["N0"])

    threads = sorted(tempos)
    med = [statistics.median(tempos[t]) for t in threads]
    menor = [m - min(tempos[t]) for m, t in zip(med, threads)]
    maior = [max(tempos[t]) - m for m, t in zip(med, threads)]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.5))
    ax1.errorbar(threads, med, yerr=[menor, maior], marker="o", capsize=3, color=CORES_N[0])
    ax1.axhline(med[0], color="k", linestyle="--", label="ideal (tempo constante)")
    ax1.set_ylabel("tempo (s)")
    ax1.set_ylim(0, max(med) * 1.3)
    ax1.set_title(f"Tempo com N = {n0:.0e} x threads")
    eixo_threads(ax1, threads)
    ax1.legend()

    ax2.plot(threads, [100 * med[0] / m for m in med], marker="o", color=CORES_N[0])
    ax2.axhline(100, color="k", linestyle="--")
    ax2.set_ylabel("eficiencia fraca (%)  =  T(1) / T(p)")
    ax2.set_ylim(0, 110)
    ax2.set_title("Eficiencia da escalabilidade fraca")
    eixo_threads(ax2, threads)

    fig.suptitle("Escalabilidade fraca do OpenMP")
    salvar(fig, "escala_fraca")


def main():
    graficos_speedup()
    grafico_schedule()
    grafico_escala_fraca()


if __name__ == "__main__":
    main()
