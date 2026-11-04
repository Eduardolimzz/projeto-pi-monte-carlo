cat << 'EOF' > /lab/projeto-pi-monte-carlo/resultados/README.md
# 📊 Perfilamento Sequencial e Baseline (Marco 1)

**Responsável:** Alessandro (Baseline & Profiling)  
**Ambiente:** Ubuntu 24.04 LTS (Docker Container) | Compilador: `g++ 13.x` com opcional `-O2`  
**Caminho dos Resultados:** `/lab/projeto-pi-monte-carlo/resultados/`

---

## 📌 1. Visão Geral

Esta etapa analisa o desempenho da implementação sequencial da estimativa de Pi por **Monte Carlo** utilizando o gerador de números pseudoaleatórios `xorshift64`. O objetivo é identificar onde o código gasta mais tempo (*hotspot*), definir o tempo de referência (baseline) e calcular o limite teórico de aceleração pela **Lei de Amdahl**.

---

## 🛠️ 2. Estrutura e Compilação

### Código Fonte
O código sequencial instrumentado para medição por trechos está em `montecarlo_pi_analise.cpp`. A execução é dividida em 3 etapas:
1. **Parte 1 (Inicialização):** Leitura de argumentos via CLI e definição da semente `uint64_t`.
2. **Parte 2 (Hotspot):** Laço principal que gera os pontos aleatórios (x, y) e verifica quantos caem dentro do círculo ($x^2 + y^2 \le 1.0$).
3. **Parte 3 (Finalização):** Cálculo final do Pi através da fórmula: `Pi = 4 * (pontos dentro / total de amostras)`.

### Comandos de Execução

```bash
# Compilação com otimização -O2
g++ -O2 -o montecarlo_pi_analise montecarlo_pi_analise.cpp

# Execução individual (Exemplo: 50 milhões de amostras)
./montecarlo_pi_analise 50000000