# projeto-pi-monte-carlo

Projeto da disciplina Programação Paralela (CCO085) – IESB 2026/2. Paralelização da estimativa de π por Monte Carlo em OpenMP e MPI, com perfilamento, baseline e análise de desempenho.

Autores e divisão de frentes: [AUTORES.md](AUTORES.md).

## O que o programa faz

Sorteia `N` pontos `(x, y)` em [0,1)×[0,1) com um gerador xorshift64 de semente fixa e conta quantos caem dentro do quarto de círculo (`x² + y² ≤ 1`). Então `π ≈ 4 · dentro / N`. O código sequencial é o do professor e define o resultado correto: as versões paralelas precisam dar **exatamente o mesmo `dentro`** para qualquer número de threads ou processos (para `N = 50000000`, `dentro = 39267859`).

## Estrutura

```
baseline/    código sequencial de referência e perfilamento (Alessandro)
openmp/      versão OpenMP (Alanna)
mpi/         versão MPI (Eduardo)
comum/       xorshift.h: gerador e salto na sequência, usado por OpenMP e MPI
scripts/     validação, medições (geram CSV) e gráficos
resultados/  CSVs das medições, dados da máquina e gráficos
relatorio/   documentos entregues
```

## Ambiente

O ambiente de referência é o do laboratório (Linux, g++ e OpenMPI), disponível na imagem Docker `iesb/pp-lab:2026.2`. No Windows, rode tudo dentro dela, pela raiz do repositório:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -it --entrypoint bash -v "$(pwd):/work" -w /work iesb/pp-lab:2026.2
```

(`MSYS_NO_PATHCONV=1` só é necessário no Git Bash do Windows.) Os comandos abaixo são para rodar **dentro** dela. Se o diretório for montado do Windows, os scripts podem vir com fim de linha CRLF; o `.gitattributes` do projeto força LF nos `.sh`.

## Compilar

```bash
make          # seq, omp e mpi
make seq      # só o baseline  -> baseline/pi_seq
make omp      # só o OpenMP    -> openmp/pi_omp
make mpi      # só o MPI       -> mpi/pi_mpi
make clean
```

## Executar

```bash
./baseline/pi_seq 50000000
./openmp/pi_omp 50000000 4                  # N, threads
./openmp/pi_omp 50000000 8 dynamic 8        # N, threads, escalonamento (static|dynamic|guided), chunk em blocos de 65536 iterações
mpirun -np 4 ./mpi/pi_mpi 50000000          # N, processos (acima do nº de núcleos: --oversubscribe)
```

Todos imprimem `n=... pi=... dentro=... tempo=... s`.

## Validar (prova de corretude)

```bash
./scripts/validar.sh
```

Para vários `N`, compara o `dentro` do baseline com o do OpenMP (várias threads e escalonamentos) e do MPI (vários números de processos). Deve terminar com `falhas=0`; qualquer diferença aparece como `FALHOU` e o código de saída é diferente de 0.

## Medir e gerar gráficos

Protocolo de todas as medições: 6 execuções por configuração, a 1ª descartada (aquecimento), tempo medido pelo próprio programa com `clock_gettime`/`MPI_Wtime`. Cada script mede o baseline na mesma sessão em que mede a versão paralela, porque o speedup só vale entre medidas da mesma máquina.

| Script | O que mede | Saída em `resultados/` |
|---|---|---|
| `scripts/medir_omp.sh` | baseline e OpenMP, `N` = 1e8, 5e8, 1e9 | `resultado_openmp.csv`, `maquina.txt` |
| `scripts/medir_schedule.sh` | políticas de escalonamento | `resultado_schedule.csv` |
| `scripts/medir_escala_fraca.sh` | escalabilidade fraca do OpenMP | `resultado_escala_fraca.csv` |
| `scripts/medir_mpi.sh` | baseline e MPI | `resultado_mpi.csv`, `maquina_mpi.txt` |
| `scripts/medir_escala_fraca_mpi.sh` | escalabilidade fraca do MPI | `resultado_escala_fraca_mpi.csv` |

```bash
pip install matplotlib
python scripts/graficos.py     # gera resultados/graficos/*.png a partir dos CSVs
```

## Decisão de projeto: resultado idêntico ao baseline

Se cada thread ou processo usasse uma semente própria, o `dentro` ficaria parecido com o do baseline, mas não igual, e mudaria com o número de threads. Como o xorshift é linear sobre os bits do estado, `comum/xorshift.h` calcula onde a sequência do baseline estaria depois de `k` passos sem percorrê-los (matrizes de 64×64 bits elevadas por quadrados). Cada bloco de iterações (OpenMP) ou cada intervalo (MPI) salta direto para o seu ponto de partida, e a soma dos acertos é a mesma de uma execução sequencial. O teste do salto está em `comum/teste_salto.cpp`.

## Resultados

Speedup sobre o baseline medido na mesma máquina, `N = 1e9` (mediana de 5 execuções). Os dois conjuntos foram medidos em **máquinas diferentes** e por isso não são comparáveis entre si.

| OpenMP (i7-13700H, 20 CPUs lógicas) | 2 | 4 | 8 | 16 | 20 |
|---|---|---|---|---|---|
| speedup | 1,98× | 3,88× | 7,54× | 13,53× | 12,18× |

| MPI (i5-10400F, 12 CPUs lógicas) | 2 | 4 | 8 | 12 |
|---|---|---|---|---|
| speedup | 1,44× | 2,86× | 5,71× | 7,66× |

Os gráficos de tempo, speedup, eficiência, escalabilidade fraca e escalonamento estão em `resultados/graficos/`.
