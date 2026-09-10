# Makefile do Projeto Academico — Estimativa de pi por Monte Carlo
# Programacao Paralela (CCO085) · IESB 2026/2
#
# Alvos futuros para openmp/ e mpi/ serao adicionados aqui.

CXX      = g++
CXXFLAGS = -O2 -Wall

SEQ_SRC = sequencial/02_montecarlo_pi.cpp
SEQ_BIN = sequencial/pi_seq

.PHONY: all seq clean

all: seq

seq: $(SEQ_BIN)

$(SEQ_BIN): $(SEQ_SRC)
	$(CXX) $(CXXFLAGS) -o $@ $<

clean:
	rm -f $(SEQ_BIN)
