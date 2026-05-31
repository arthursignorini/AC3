#!/usr/bin/env bash
# =============================================================================
# Simulação — Cache Controller
# Uso: ./sim/run_sim.sh   (executar a partir da raiz do projeto)
# =============================================================================
set -euo pipefail

# Resolve raiz do projeto independente do diretório de execução
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL_DIR="$PROJECT_ROOT/rtl"
TB_DIR="$PROJECT_ROOT/tb"
SIM_DIR="$PROJECT_ROOT/sim"

mkdir -p "$SIM_DIR"
cd "$PROJECT_ROOT"   # garante que o dumpfile "sim/cache_sim.vcd" resolve certo

echo "=== Compilando com Icarus Verilog ==="
iverilog -g2012 \
    -o "$SIM_DIR/cache_sim" \
    "$RTL_DIR/main_memory.sv" \
    "$RTL_DIR/cache_controller.sv" \
    "$TB_DIR/tb_cache_controller.sv"

echo "=== Executando simulação ==="
vvp "$SIM_DIR/cache_sim" | tee "$SIM_DIR/sim_log.txt"

echo ""
echo "=== Arquivos gerados ==="
echo "  Log     : $SIM_DIR/sim_log.txt"
echo "  Waveform: $SIM_DIR/cache_sim.vcd"
echo ""
echo "Para visualizar waveforms:"
echo "  gtkwave $SIM_DIR/cache_sim.vcd &"
