# Makefile do Projeto Academico — Estimativa de pi por Monte Carlo
# Programacao Paralela (CCO085) · IESB 2026/2
#
# Alvo futuro para mpi/ sera adicionado aqui.

CXX      = g++
CXXFLAGS = -O2 -Wall

SEQ_SRC = baseline/02_montecarlo_pi.cpp
SEQ_BIN = baseline/pi_seq

OMP_SRC = openmp/02_montecarlo_pi_openmp.cpp
OMP_BIN = openmp/pi_omp

.PHONY: all seq omp clean

all: seq omp

seq: $(SEQ_BIN)

omp: $(OMP_BIN)

$(SEQ_BIN): $(SEQ_SRC)
	$(CXX) $(CXXFLAGS) -o $@ $<

$(OMP_BIN): $(OMP_SRC)
	$(CXX) $(CXXFLAGS) -fopenmp -o $@ $<

clean:
	rm -f $(SEQ_BIN) $(OMP_BIN)
