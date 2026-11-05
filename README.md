# Estimativa de π por Monte Carlo

Projeto da disciplina **Programação Paralela (CCO085)**, IESB, semestre 2026/2.
O objetivo é estimar π por Monte Carlo e comparar a versão sequencial de
referência com implementações em OpenMP e MPI, medindo desempenho e
escalabilidade.

A divisão das responsabilidades principais está em [AUTORES.md](AUTORES.md).

## Como funciona

Cada amostra gera um ponto `(x, y)` no quadrado unitário. O programa conta os
pontos que satisfazem `x² + y² <= 1`; a estimativa é `π ≈ 4 × dentro / N`, onde
`N` é o número de amostras.

O baseline usa `xorshift` com uma semente fixa. As versões paralelas preservam a
mesma sequência pseudoaleatória do baseline para que a contagem `dentro` possa
ser comparada exatamente. O código compartilhado do gerador e do salto na
sequência está em `comum/xorshift.h`.

## Estrutura

- `baseline/`: implementação sequencial de referência e perfilamento.
- `openmp/`: versão paralela em memória compartilhada.
- `mpi/`: versão paralela por processos MPI.
- `comum/`: gerador `xorshift` e funções para saltar posições na sequência.
- `scripts/`: validação, medições e geração dos gráficos.
- `resultados/`: dados CSV, informações dos ambientes de medição e gráficos.

## Requisitos

Os comandos abaixo pressupõem Linux, GNU Make, `g++` com suporte a OpenMP,
`mpic++`/`mpirun` (OpenMPI), Bash e Python 3. Em Ubuntu ou Debian, as ferramentas
de compilação e MPI podem ser instaladas com:

```bash
sudo apt update
sudo apt install build-essential make openmpi-bin libopenmpi-dev python3 python3-venv
```

Para gerar os gráficos, `scripts/graficos.py` também precisa do Matplotlib. Um
ambiente virtual mantém essa dependência isolada:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install matplotlib
```

## Compilar

Na raiz do repositório, `make` compila as três versões; ele não executa os
programas:

```bash
make          # sequencial, OpenMP e MPI
make seq      # somente baseline sequencial
make omp      # somente OpenMP
make mpi      # somente MPI
make clean    # remove os executáveis compilados
```

O alvo `mpi` usa `mpic++`. O alvo `omp` usa `g++ -fopenmp`.

## Executar

O primeiro argumento do programa é o total de amostras. Se ele for omitido, os
programas usam 50 milhões.

```bash
./baseline/pi_seq 50000000
./openmp/pi_omp 50000000 4
./openmp/pi_omp 50000000 4 dynamic 8
mpirun -np 4 ./mpi/pi_mpi 50000000
```

Na chamada OpenMP, o segundo argumento seleciona o número de threads; os
argumentos opcionais seguintes escolhem a política (`static`, `dynamic` ou
`guided`) e o tamanho do chunk. No MPI, `-np 4` inicia quatro processos. Cada
processo calcula um intervalo das amostras e `MPI_Reduce` soma as contagens no
processo de rank zero.

As três versões imprimem `N`, a estimativa de π, a contagem de pontos dentro e o
tempo medido. A versão MPI também informa o número de processos e o tempo
observado em `MPI_Reduce`.

## Validar os resultados

O script compara a contagem exata `dentro` das versões OpenMP e MPI com a do
baseline em vários tamanhos de entrada, threads, políticas de escalonamento e
números de processos:

```bash
./scripts/validar.sh
```

Ele compila as versões necessárias. Para uma validação rápida, é possível
reduzir os tamanhos e as configurações:

```bash
TAMANHOS="1 1000 65537 1000003" THREADS="1 2 4" PROCESSOS="1 2 4 7" ./scripts/validar.sh
```

O script ignora números de processos maiores que a quantidade de CPUs lógicas
disponível. Em ambientes OpenMPI, `MPIEXEC_ARGS` pode ser usado para passar
opções adicionais ao `mpirun`.

## Medir desempenho

Os scripts descartam uma execução de aquecimento e, por padrão, guardam cinco
repetições de cada configuração. As variáveis mostradas podem ser sobrescritas
para limitar uma execução, por exemplo `TAMANHOS="1000000" REPETICOES=2`.

```bash
./scripts/medir_omp.sh
./scripts/medir_mpi.sh
./scripts/medir_schedule.sh
./scripts/medir_escala_fraca.sh
./scripts/medir_escala_fraca_mpi.sh
```

`medir_omp.sh` e `medir_mpi.sh` medem o baseline e a versão paralela na mesma
máquina para comparar os tempos. Os scripts de escalabilidade forte mantêm `N`
fixo e variam threads ou processos. Os de escalabilidade fraca mantêm fixo o
trabalho por thread/processo e aumentam `N` junto com o paralelismo.

Os scripts de medição reescrevem o CSV de saída correspondente. As informações
do hardware e do compilador ficam em `resultados/maquina.txt` e
`resultados/maquina_mpi.txt`. Os tempos dependem da máquina e do ambiente; antes
de comparar OpenMP e MPI diretamente, verifique se as medições foram feitas no
mesmo ambiente.

## Gerar gráficos

Com o ambiente virtual ativado e Matplotlib instalado:

```bash
python scripts/graficos.py
```

O script lê os CSVs em `resultados/` e grava imagens em `resultados/graficos/`.
Ele gera gráficos de tempo, speedup, eficiência, políticas de escalonamento,
escalabilidade fraca e tempo observado na redução MPI.

O speedup é calculado como `T_sequencial / T_paralelo`; a eficiência é o speedup
dividido pelo número de threads ou processos. As linhas de Amdahl usam a fração
paralelizável estimada no perfilamento do baseline.
