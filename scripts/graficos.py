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


def eixo_processos(ax, processos):
    ax.set_xscale("log", base=2)
    ax.set_xticks(processos)
    ax.xaxis.set_major_formatter(ScalarFormatter())
    ax.minorticks_off()
    ax.set_xlabel("processos MPI")
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


def graficos_mpi():
    arquivo = os.path.join(RESULTADOS, "resultado_mpi.csv")
    if not os.path.exists(arquivo):
        print("ignorado: resultados/resultado_mpi.csv ainda nao existe")
        return

    tempos = defaultdict(list)
    reducoes = defaultdict(list)
    for r in ler("resultado_mpi.csv"):
        n = int(r["N"])
        p = int(r["processos"])
        tempo = float(r["tempo_s"])
        tempos[(n, r["versao"], p)].append(tempo)
        if r["versao"] == "mpi" and r.get("mpi_reduce_s"):
            reducoes[(n, p)].append(float(r["mpi_reduce_s"]))

    tamanhos = sorted({k[0] for k in tempos})
    processos = sorted({k[2] for k in tempos if k[1] == "mpi"})
    mediana = {k: statistics.median(v) for k, v in tempos.items()}

    fig, ax = plt.subplots(figsize=(7, 4.5))
    for i, n in enumerate(tamanhos):
        med = [mediana[(n, "mpi", p)] for p in processos]
        menor = [med[j] - min(tempos[(n, "mpi", p)]) for j, p in enumerate(processos)]
        maior = [max(tempos[(n, "mpi", p)]) - med[j] for j, p in enumerate(processos)]
        ax.errorbar(processos, med, yerr=[menor, maior], marker="o", capsize=3,
                    color=CORES_N[i], label=f"N = {n:.0e}")
        ax.axhline(mediana[(n, "seq", 1)], color=CORES_N[i], linestyle=":", alpha=0.7)
    ax.set_yscale("log")
    ax.set_ylabel("tempo (s)")
    ax.set_title("Tempo de execucao MPI\npontilhado = baseline sequencial")
    eixo_processos(ax, processos)
    ax.legend()
    salvar(fig, "mpi_tempo")

    fig, ax = plt.subplots(figsize=(7, 4.5))
    for i, n in enumerate(tamanhos):
        base = mediana[(n, "seq", 1)]
        ax.plot(processos, [base / mediana[(n, "mpi", p)] for p in processos], marker="o",
                color=CORES_N[i], label=f"N = {n:.0e}")
    ax.plot(processos, processos, "k--", label="ideal (S = processos)")
    ax.plot(processos, [1 / ((1 - P_AMDAHL) + P_AMDAHL / p) for p in processos], "k:",
            label=f"Amdahl (P = {P_AMDAHL})")
    ax.set_ylabel("speedup")
    ax.set_title("Speedup do MPI")
    eixo_processos(ax, processos)
    ax.legend()
    salvar(fig, "mpi_speedup")

    fig, ax = plt.subplots(figsize=(7, 4.5))
    for i, n in enumerate(tamanhos):
        base = mediana[(n, "seq", 1)]
        ax.plot(processos, [100 * base / mediana[(n, "mpi", p)] / p for p in processos], marker="o",
                color=CORES_N[i], label=f"N = {n:.0e}")
    ax.axhline(100, color="k", linestyle="--")
    ax.set_ylabel("eficiencia (%)")
    ax.set_ylim(0, 110)
    ax.set_title("Eficiencia do MPI")
    eixo_processos(ax, processos)
    ax.legend()
    salvar(fig, "mpi_eficiencia")

    if reducoes:
        fig, ax = plt.subplots(figsize=(7, 4.5))
        for i, n in enumerate(tamanhos):
            chaves = [(n, p) for p in processos if (n, p) in reducoes]
            ps = [p for _, p in chaves]
            med = [statistics.median(reducoes[k]) for k in chaves]
            ax.plot(ps, med, marker="o", color=CORES_N[i], label=f"N = {n:.0e}")
        ax.set_ylabel("tempo maximo em MPI_Reduce (s)")
        ax.set_title("Tempo observado na reducao MPI\n(inclui espera de sincronizacao)")
        eixo_processos(ax, processos)
        ax.legend()
        salvar(fig, "mpi_reducao")


def grafico_escala_fraca_mpi():
    arquivo = os.path.join(RESULTADOS, "resultado_escala_fraca_mpi.csv")
    if not os.path.exists(arquivo):
        print("ignorado: resultados/resultado_escala_fraca_mpi.csv ainda nao existe")
        return

    tempos = defaultdict(list)
    n0 = None
    for r in ler("resultado_escala_fraca_mpi.csv"):
        tempos[int(r["processos"])].append(float(r["tempo_s"]))
        n0 = int(r["N0"])

    processos = sorted(tempos)
    med = [statistics.median(tempos[p]) for p in processos]
    menor = [m - min(tempos[p]) for m, p in zip(med, processos)]
    maior = [max(tempos[p]) - m for m, p in zip(med, processos)]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.5))
    ax1.errorbar(processos, med, yerr=[menor, maior], marker="o", capsize=3, color=CORES_N[0])
    ax1.axhline(med[0], color="k", linestyle="--", label="ideal (tempo constante)")
    ax1.set_ylabel("tempo (s)")
    ax1.set_ylim(0, max(med) * 1.3)
    ax1.set_title(f"Tempo com N = {n0:.0e} x processos")
    eixo_processos(ax1, processos)
    ax1.legend()

    ax2.plot(processos, [100 * med[0] / m for m in med], marker="o", color=CORES_N[0])
    ax2.axhline(100, color="k", linestyle="--")
    ax2.set_ylabel("eficiencia fraca (%) = T(1) / T(p)")
    ax2.set_ylim(0, 110)
    ax2.set_title("Escalabilidade fraca MPI")
    eixo_processos(ax2, processos)

    fig.suptitle("Escalabilidade fraca do MPI")
    salvar(fig, "mpi_escala_fraca")


def main():
    graficos_speedup()
    grafico_schedule()
    grafico_escala_fraca()
    graficos_mpi()
    grafico_escala_fraca_mpi()


if __name__ == "__main__":
    main()
