# Autores

Programação Paralela (CCO085) · IESB 2026/2 · Turma CCODM3B (matutino)
Professor: Rodrigo Gonçalves Pinto
Problema nº 2: estimativa de π por Monte Carlo

| Integrante | Matrícula | GitHub | Frente (responsabilidade formal) |
|---|---|---|---|
| Alessandro Ribeiro Moreira | 2412130120 | AlessandRM | Baseline e Perfilamento |
| Alanna Tomaz de Aquino Martins | 2412130055 | alannatomaz | Versão OpenMP (memória compartilhada) |
| Eduardo Lima dos Santos | 2412130074 | Eduardolimzz | Versão MPI (memória distribuída) |

## O que cada um entregou

**Alessandro — Baseline e Perfilamento**
- `baseline/`: código sequencial de referência, versão instrumentada por trecho (`montecarlo_pi_analise.cpp`) e `README_BASELINE.MD`.
- `resultados/resultado_perfilamento_baseline.csv` e `resultados/estimativa_baseline`: tempo por trecho, fração paralelizável e speedup teórico pela Lei de Amdahl.

**Alanna — OpenMP**
- `openmp/02_montecarlo_pi_openmp.cpp`: laço paralelo por blocos, com `reduction(+:dentro)` e escolha do escalonamento por argumento.
- `comum/xorshift.h` e `comum/teste_salto.cpp`: salto no xorshift, que faz o resultado bater exatamente com o baseline (usado também pelo MPI).
- `openmp/experimentos/` e `scripts/experimentos_omp.sh`: custo de `reduction` contra `atomic` e `critical`, e diagnóstico por thread.
- `scripts/validar.sh`, `scripts/medir_omp.sh`, `scripts/medir_schedule.sh`, `scripts/medir_escala_fraca.sh` e `scripts/graficos.py`.
- `resultados/resultado_openmp.csv`, `resultado_schedule.csv`, `resultado_escala_fraca.csv`, `maquina.txt` e os gráficos de OpenMP.

**Eduardo — MPI**
- `mpi/02_montecarlo_pi_mpi.cpp`: decomposição por intervalos contíguos e `MPI_Reduce`.
- `scripts/medir_mpi.sh`, `scripts/medir_escala_fraca_mpi.sh` e a validação do MPI em `scripts/validar.sh`.
- `resultados/resultado_mpi.csv`, `resultado_escala_fraca_mpi.csv`, `maquina_mpi.txt` e os gráficos de MPI.

## Trabalho compartilhado

- O `Makefile` partiu do Eduardo e recebeu o alvo `omp` da Alanna e o alvo `mpi` do Eduardo.
- O repositório está no GitHub do Eduardo; o histórico de commits mostra a contribuição de cada um.
