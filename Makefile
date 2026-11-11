# Makefile do Projeto Academico — Estimativa de pi por Monte Carlo
# Programacao Paralela (CCO085) · IESB 2026/2
#
# Compilacao das versoes sequencial, OpenMP e MPI.

CXX      = g++
CXXFLAGS = -O2 -Wall
MPICXX   ?= mpic++

SEQ_SRC = baseline/02_montecarlo_pi.cpp
SEQ_BIN = baseline/pi_seq

OMP_SRC = openmp/02_montecarlo_pi_openmp.cpp
OMP_BIN = openmp/pi_omp

MPI_SRC = mpi/02_montecarlo_pi_mpi.cpp
MPI_BIN = mpi/pi_mpi

EXP_BINS = openmp/experimentos/comparar_sincronizacao openmp/experimentos/diagnostico_threads

.PHONY: all seq omp mpi exp clean

all: seq omp mpi

seq: $(SEQ_BIN)

omp: $(OMP_BIN)

mpi: $(MPI_BIN)

# experimentos de apoio da analise do OpenMP (nao entram no "all")
exp: $(EXP_BINS)

$(SEQ_BIN): $(SEQ_SRC)
	$(CXX) $(CXXFLAGS) -o $@ $<

$(OMP_BIN): $(OMP_SRC) comum/xorshift.h
	$(CXX) $(CXXFLAGS) -fopenmp -Icomum -o $@ $<

$(MPI_BIN): $(MPI_SRC) comum/xorshift.h
	$(MPICXX) $(CXXFLAGS) -Icomum -o $@ $<

openmp/experimentos/%: openmp/experimentos/%.cpp comum/xorshift.h
	$(CXX) $(CXXFLAGS) -fopenmp -Icomum -o $@ $<

clean:
	rm -f $(SEQ_BIN) $(OMP_BIN) $(MPI_BIN) $(EXP_BINS)
