# [cite_start]Testbench de Validação do Controlador de Cache [cite: 182, 315]

[cite_start]Este documento descreve a suíte de testes implementada no arquivo `tb_cache_controller.sv` para validar o comportamento do Controlador de Cache[cite: 113]. [cite_start]A simulação foi projetada para cobrir rigorosamente as especificações, operando com 26 casos de teste automatizados divididos em 6 baterias[cite: 104, 113]. 

---

## 🏗️ Estrutura do Testbench

[cite_start]O ambiente instancia o módulo sob teste (`cache_controller`) e um modelo comportamental de memória (`main_memory`), fornecendo as interfaces de clock, sinais de controle e rotinas automatizadas para injeção de leitura e escrita (`cpu_read` e `cpu_write`)[cite: 334, 336, 340, 343].

## 🧪 Baterias de Teste (Suites)

[cite_start]A validação assegura a corretude da FSM, do mecanismo write-back e das interações de mapeamento direto através das seguintes categorias[cite: 176, 177, 353]:

| Suite | Descrição | Status Esperado |
| :--- | :--- | :--- |
| **1 - Read Path** | [cite_start]Verifica cenários de *Read Hit*, *Read Miss*, carregamento de blocos e atualização de registradores (valid e tag) após alocação. [cite: 177, 354] | [cite_start]PASS [cite: 177] |
| **2 - Write Path** | [cite_start]Verifica escritas (*Write Hit/Miss*), atualização correta do bit *dirty* e confirmação de que a memória não é modificada imediatamente (política Write-Back). [cite: 177, 362] | [cite_start]PASS [cite: 177] |
| **3 - Substituição** | [cite_start]Confirma a ocorrência de transferências write-back durante a substituição de blocos *dirty* e valida a política de concorrência Direct-Mapped. [cite: 177, 369] | [cite_start]PASS [cite: 177] |
| **4 - Consistência** | [cite_start]Realiza dezenas de operações de leitura após escrita repetidas e simula conflitos intencionais de índice para testar a integridade dos dados armazenados. [cite: 177, 388] | [cite_start]PASS [cite: 177] |
| **5 - Casos Limite** | [cite_start]Exercita acessos nos limites da memória (`Addr = 0x0` e `Addr = 0x3FFC`) e assegura transições corretas de esvaziamento após o reset elétrico. [cite: 177, 397] | [cite_start]PASS [cite: 177] |
| **6 - Handshake** | [cite_start]Confirma a estabilidade e o tempo exato dos sinais assíncronos e síncronos da interface de processamento (`cpu_stall` e `cpu_ack`). [cite: 177, 408] | [cite_start]PASS [cite: 177] |

---

## 📈 Resultados da Simulação

A execução do arquivo atesta as transições e latências descritas no relatório acadêmico gerando um log de completude. Ao final da rotina simulada, o terminal deverá reportar:

* [cite_start]**Total de testes:** 26 [cite: 235, 414]
* [cite_start]**Testes bem-sucedidos:** 26 [cite: 235, 414]
* [cite_start]**Falhas detectadas:** 0 [cite: 235, 414]

[cite_start]O testbench também provê a extração automática de dados VCD (`sim/cache_sim.vcd`), ideal para inspeção em analisadores de Waveforms como o GTKWave. [cite: 240, 338]