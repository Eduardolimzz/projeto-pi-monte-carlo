# Padrão de commits do projeto

Formato: `tipo(escopo): descrição no imperativo`

## Tipos
- `feat`: código novo (versões OpenMP/MPI)
- `fix`: correção de erro
- `perf`: melhoria de desempenho
- `docs`: documentação e relatório
- `build`: Makefile e compilação
- `test`: validação de corretude
- `chore`: organização e configuração
- `refactor`: reorganização sem mudar comportamento

## Escopos
`seq`, `omp`, `mpi`, `scripts`, `resultados`, `readme`, `relatorio`, `make`

## Regras
1. Descrição em português, no imperativo, minúscula, sem ponto final.
2. Um commit por mudança lógica.
3. Sempre `git pull` antes de começar e `git push` ao terminar.

## Exemplos
- `build(make): adiciona alvo da versão sequencial`
- `feat(scripts): cria script de medição do baseline em CSV`
- `docs(relatorio): adiciona tabela de perfilamento`
- `feat(omp): paraleliza laço com reduction(+:acertos)`
- `feat(mpi): distribui pontos com MPI_Bcast e MPI_Reduce`
