# Cache Controller — Trabalho Prático 1

Implementação de um **Controlador de Cache** em SystemVerilog, conforme especificação do livro *Computer Organization and Design: The Hardware/Software Interface — RISC-V Edition*, Capítulo 5, Seção 5.12.

## Configuração da Cache

| Parâmetro           | Valor                  |
|---------------------|------------------------|
| Capacidade          | 1 KB                   |
| Número de blocos    | 64                     |
| Tamanho do bloco    | 16 bytes (4 palavras)  |
| Organização         | Direct-Mapped          |
| Política de escrita | Write-Back             |
| Miss de escrita     | Write-Allocate         |
| Largura do endereço | 32 bits                |
| Largura da palavra  | 32 bits                |

### Decomposição do endereço (32 bits)

```
[31 ........... 10][9 ........ 4][3 .. 0]
       TAG (22b)     INDEX (6b)  OFFSET (4b)
```

---

## Estrutura do Repositório

```
cache_controller/
├── rtl/
│   ├── cache_controller.sv   # Controlador de cache (DUT)
│   └── main_memory.sv        # Modelo de memória para simulação
├── tb/
│   └── tb_cache_controller.sv  # Testbench completo (24 testes)
├── sim/
│   ├── run_sim.sh            # Script de simulação (Icarus Verilog)
│   └── cache_sim.vcd         # Waveform gerado (após simulação)
└── README.md
```

---

## Dependências

| Ferramenta       | Versão mínima | Instalação (Ubuntu/Debian)          |
|------------------|---------------|-------------------------------------|
| Icarus Verilog   | 10.x          | `sudo apt install iverilog`         |
| GTKWave          | 3.x           | `sudo apt install gtkwave`          |

> **Alternativas suportadas:** ModelSim, Questa, Verilator, XSIM (Vivado).  
> O código não usa construções proprietárias; qualquer simulador SystemVerilog 2012 funciona.

---

## Compilação e Simulação

### Usando o script automatizado (recomendado)

```bash
# Clone o repositório
git clone <url-do-repositorio>
cd cache_controller

# Dê permissão de execução ao script
chmod +x sim/run_sim.sh

# Execute a simulação
./sim/run_sim.sh
```

O script compila os arquivos e executa o testbench. A saída esperada é:

```
==========================================================
  TESTBENCH — Controlador de Cache
  1KB, 64 blocos, direct-mapped, write-back, write-alloc
==========================================================

--- Suite 1: Read Path ---
[PASS] 1.1 Read Miss retorna dado correto da memória
[PASS] 1.2 Read Hit retorna mesmo valor
...
==========================================================
  RESULTADO FINAL
  Total : 24  |  Passou : 24  |  Falhou : 0
  *** TODOS OS TESTES PASSARAM ***
==========================================================
```

### Compilação manual

```bash
# Criar diretório de saída
mkdir -p sim

# Compilar
iverilog -g2012 \
    -o sim/cache_sim \
    rtl/main_memory.sv \
    rtl/cache_controller.sv \
    tb/tb_cache_controller.sv

# Executar
vvp sim/cache_sim
```

### Visualizar Waveform

```bash
gtkwave sim/cache_sim.vcd &
```

Sinais sugeridos para inspecionar:
- `clk`, `rst_n`
- `cpu_req`, `cpu_we`, `cpu_addr`, `cpu_wdata`, `cpu_rdata`, `cpu_ack`, `cpu_stall`
- `mem_req`, `mem_we`, `mem_addr`, `mem_wdata`, `mem_rdata`, `mem_ack`
- `dut.state` (FSM)
- `dut.hit`, `dut.burst_cnt`

---

## Descrição dos Módulos

### `cache_controller.sv`

FSM de 4 estados que gerencia todos os fluxos de leitura e escrita:

```
IDLE → COMPARE_TAG → (hit)  → IDLE
                   → (miss, bloco limpo) → ALLOCATE → COMPARE_TAG
                   → (miss, bloco dirty) → WRITE_BACK → ALLOCATE → COMPARE_TAG
```

### `main_memory.sv`

Modelo comportamental de memória com latência configurável (padrão: 2 ciclos).  
Inicializada com valores determinísticos: `mem[i] = i*4 + 1`.

---

## Cobertura de Testes

| Suite | Cenário                                              | Testes |
|-------|------------------------------------------------------|--------|
| 1     | Read Path (hit, miss, valid/tag bits)               | 5      |
| 2     | Write Path (hit, miss, dirty, write-back policy)    | 4      |
| 3     | Substituição e Write-Back (conflito, cache cheia)   | 4      |
| 4     | Consistência (R→W→R, repetição, conflito de índice) | 3      |
| 5     | Casos limite (addr=0, addr_max, reset)              | 5      |
| 6     | Handshake CPU (stall, ack)                          | 3      |
| **Total** |                                                 | **24** |
