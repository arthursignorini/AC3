# Trabalho Prático 1 — Controlador de Cache

Implementação de um controlador de cache **direct-mapped** com política **write-back** e **write-allocate** em SystemVerilog, conforme especificado no Capítulo 5, Seção 5.12 do livro *Computer Organization and Design: The Hardware/Software Interface — RISC-V Edition* (Patterson & Hennessy).

> Disciplina: Arquitetura de Computadores

---

## Sumário

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Como Simular](#como-simular)
- [Testbench de Validação](#testbench-de-validação)
- [Resultados](#resultados)
- [Referências](#referências)

---

## Visão Geral

| Parâmetro | Valor |
|-----------|-------|
| Capacidade | 1 KB |
| Organização | Direct-Mapped |
| Blocos | 64 × 16 bytes |
| Palavras por bloco | 4 × 32 bits |
| Política de escrita (hit) | Write-Back |
| Política de escrita (miss) | Write-Allocate |
| Latência da memória | 2 ciclos (configurável) |
| Simulador | Icarus Verilog 12.0 |
| Testes | **26/26 PASS** |

---

## Arquitetura

### Decomposição do endereço (32 bits)

```
[31:10] Tag    — 22 bits — identifica o bloco na memória
[9:4]   Index  —  6 bits — seleciona a linha da cache (0–63)
[3:0]   Offset —  4 bits — byte dentro do bloco
```

### FSM — Máquina de Estados (4 estados)

```
IDLE ──► COMPARE_TAG ──► (hit) ──────────────────► IDLE
                    └──► (miss, dirty=0) ──────► ALLOCATE ──► COMPARE_TAG
                    └──► (miss, dirty=1) ──► WRITE_BACK ──► ALLOCATE ──► COMPARE_TAG
```

| Estado | Função |
|--------|--------|
| `IDLE` | Aguarda `cpu_req=1` e captura endereço, dado e tipo de operação |
| `COMPARE_TAG` | Verifica hit (`valid=1` e `tag==saved_tag`). Serve em 1 ciclo em caso de hit |
| `WRITE_BACK` | Descarrega o bloco dirty na memória via burst de 4 palavras |
| `ALLOCATE` | Carrega o novo bloco da memória via burst de 4 palavras |

### Interface com a CPU (handshake)

| Sinal | Direção | Descrição |
|-------|---------|-----------|
| `cpu_req` | entrada | CPU solicita acesso |
| `cpu_ack` | saída | Cache confirma conclusão |
| `cpu_stall` | saída | CPU deve aguardar (miss em andamento) |

---

## Estrutura do Repositório

```
.
├── rtl/
│   ├── cache_controller.sv     # DUT — controlador de cache (FSM principal)
│   └── main_memory.sv          # Modelo comportamental da memória principal
├── tb/
│   └── tb_cache_controller.sv  # Testbench — 26 testes em 6 suites
├── sim/
│   └── cache_sim.vcd           # Waveform gerado após simulação (gitignore)
├── scripts/
│   └── run_sim.sh              # Script de compilação e simulação
└── README.md
```

---

## Como Simular

### Pré-requisitos

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) `>= 12.0`
- [GTKWave](https://gtkwave.sourceforge.net/) (opcional, para visualizar waveforms)

### Executar a simulação

```bash
# A partir da raiz do repositório
bash scripts/run_sim.sh
```

O script compila os módulos RTL junto com o testbench e executa a simulação. A saída esperada no terminal é:

```
==========================================================
 TESTBENCH — Controlador de Cache
 1KB, 64 blocos, direct-mapped, write-back, write-alloc
==========================================================
[PASS] 1.1 Read Miss retorna dado correto da memória
[PASS] 1.2 Read Hit retorna mesmo valor
...
==========================================================
 RESULTADO FINAL
 Total : 26 | Passou : 26 | Falhou : 0
 *** TODOS OS TESTES PASSARAM ***
==========================================================
```

### Visualizar waveforms

```bash
gtkwave sim/cache_sim.vcd
```

---

## Testbench de Validação

O arquivo `tb_cache_controller.sv` contém a suíte completa de testes para validar o comportamento do controlador. O ambiente instancia o módulo sob teste (`cache_controller`) e um modelo comportamental de memória (`main_memory`), fornecendo as interfaces de clock, sinais de controle e rotinas automatizadas para injeção de leitura e escrita (`cpu_read` e `cpu_write`).

A validação assegura a corretude da FSM, do mecanismo write-back e das interações de mapeamento direto através das seguintes categorias:

| Suite | Descrição | Status |
|:------|:----------|:------:|
| **1 — Read Path** | Verifica cenários de *Read Hit*, *Read Miss*, carregamento de blocos e atualização de registradores (`valid` e `tag`) após alocação | ✅ PASS |
| **2 — Write Path** | Verifica escritas (*Write Hit/Miss*), atualização correta do bit *dirty* e confirmação de que a memória não é modificada imediatamente (política Write-Back) | ✅ PASS |
| **3 — Substituição** | Confirma a ocorrência de transferências write-back durante a substituição de blocos *dirty* e valida a política de concorrência Direct-Mapped | ✅ PASS |
| **4 — Consistência** | Realiza dezenas de operações de leitura após escrita repetidas e simula conflitos intencionais de índice para testar a integridade dos dados armazenados | ✅ PASS |
| **5 — Casos Limite** | Exercita acessos nos limites da memória (`Addr = 0x0` e `Addr = 0x3FFC`) e assegura transições corretas de esvaziamento após o reset elétrico | ✅ PASS |
| **6 — Handshake** | Confirma a estabilidade e o tempo exato dos sinais assíncronos e síncronos da interface de processamento (`cpu_stall` e `cpu_ack`) | ✅ PASS |

O testbench também provê a extração automática de dados VCD (`sim/cache_sim.vcd`), ideal para inspeção em analisadores de waveforms como o GTKWave.

---

## Resultados

### Resumo dos testes

| Suite | Testes | Status |
|-------|--------|--------|
| 1 — Read Path | 5 | ✅ PASS |
| 2 — Write Path | 4 | ✅ PASS |
| 3 — Substituição | 6 | ✅ PASS |
| 4 — Consistência | 3 | ✅ PASS |
| 5 — Casos Limite | 5 | ✅ PASS |
| 6 — Handshake | 3 | ✅ PASS |
| **Total** | **26** | **26/26** |

### Latência por operação (latência mem = 2 ciclos)

| Operação | Condição | Ciclos |
|----------|----------|--------|
| Leitura | Hit | 2 |
| Leitura | Miss — bloco limpo | ~11 |
| Leitura | Miss — bloco dirty | ~19 |
| Escrita | Hit | 2 |
| Escrita | Miss — write-allocate, limpo | ~11 |
| Escrita | Miss — write-allocate, dirty | ~19 |

---

## Referências

- PATTERSON, David A.; HENNESSY, John L. *Computer Organization and Design: The Hardware/Software Interface — RISC-V Edition*. 2. ed. Waltham: Morgan Kaufmann, 2020.
