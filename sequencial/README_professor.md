# Códigos Sequenciais de Referência — Projeto Acadêmico IESB

**Programação Paralela (CCO085) · IESB 2026/2 · Prof. Rodrigo Gonçalves Pinto**

Cada arquivo é a **implementação sequencial de referência (baseline)** de um dos
dez problemas do Projeto Acadêmico. Seu trio recebe um problema; parta deste
código para produzir as versões OpenMP e MPI.

## Regras de uso

1. **Não altere a lógica de cálculo nem a entrada.** O baseline define o resultado
   correto. Suas versões paralelas devem produzir o **mesmo checksum / resultado**
   para a mesma entrada — é assim que você comprova que não quebrou a corretude ao
   paralelizar.
2. A entrada é **determinística** (semente fixa): rodar duas vezes dá o mesmo
   resultado. Isso é proposital, para que suas medições sejam comparáveis.
3. Cada programa imprime um **valor de validação** (checksum, "ordenado=SIM",
   chave encontrada, etc.) e o **tempo**. Use o valor para validar; use o tempo
   como seu baseline de speedup.

## Compilar e rodar

```bash
g++ -O2 -o programa NN_nome.cpp
./programa [parametros]
```

Cada arquivo traz, no cabeçalho, a linha de compilação e um exemplo de execução.

## Lista dos problemas

| Nº | Arquivo | Problema | Aspecto de paralelismo |
|----|---------|----------|------------------------|
| 01 | 01_matmul.cpp | Multiplicação de matrizes densas | Efeito de cache e ordem de laços |
| 02 | 02_montecarlo_pi.cpp | Estimativa de π (Monte Carlo) | Paralelismo quase perfeito; RNG por thread |
| 03 | 03_mandelbrot.cpp | Conjunto de Mandelbrot | Desbalanceamento de carga; schedule dynamic |
| 04 | 04_convolucao.cpp | Filtro de convolução 2D (blur) | Decomposição de domínio; bordas/halo |
| 05 | 05_calor2d.cpp | Equação do calor 2D | Stencil iterativo; halo exchange em MPI |
| 06 | 06_nbody.cpp | Simulação de N corpos | Custo O(N²); comunicação global |
| 07 | 07_mergesort.cpp | Ordenação (mergesort) | Divisão e conquista; OpenMP tasks |
| 08 | 08_kmers.cpp | Contagem de k-mers | Redução sobre histograma; particionamento |
| 09 | 09_forcabruta.cpp | Busca exaustiva (força bruta) | Mestre-escravo; término antecipado |
| 10 | 10_kmeans.cpp | Agrupamento k-means | Fases paralelas; sincronização global |

## Medir o baseline corretamente

- Compile **sempre com `-O2`**. Sem otimização, os tempos não têm sentido.
- Rode **três vezes** e use a mediana; descarte a primeira (aquecimento de cache).
- Registre a máquina usada (número de núcleos: `nproc`).
- O speedup se calcula contra **este tempo sequencial**, não contra a versão
  paralela rodando com 1 thread.
