# Controlador de Cache - Organização e Arquitetura de Computadores

Este repositório contém a implementação em SystemVerilog de um Controlador de Cache e um modelo simplificado de Memória Principal. O projeto foi desenvolvido como o Trabalho Prático 1 da disciplina, baseando-se nas especificações do Capítulo 5, Seção 5.12 do livro *Computer Organization and Design: RISC-V Edition*.

---

## 🛠️ Especificações da Cache

A arquitetura foi configurada com os seguintes parâmetros padrão:

* **Capacidade:** 1 KB
* **Organização:** Mapeamento Direto (Direct-Mapped)
* **Tamanho do Bloco:** 16 bytes (4 palavras de 32 bits)
* **Quantidade de Blocos:** 64 blocos
* **Políticas de Escrita:** Write-Back e Write-Allocate
* **Substituição:** Determinística (baseada no índice)

## 📂 Estrutura de Módulos

O sistema é composto pelos seguintes componentes de hardware e simulação:

| Módulo | Função | Arquivo |
| :--- | :--- | :--- |
| **cache_controller** | FSM principal: processamento de hit/miss, alocação de blocos e controle de handshake com a CPU. | `cache_controller.sv` |
| **main_memory** | Modelo de memória principal operando em protocolo burst com latência configurável (padrão de 2 ciclos). | `main_memory.sv` |

---

## 🧠 Funcionamento da FSM (Máquina de Estados)

A lógica do controlador é orientada por uma Máquina de Estados Finitos síncrona com 4 estados principais:

* **IDLE:** Aguarda a requisição da CPU (`cpu_req=1`), captura endereços e dados em registradores internos e avança para a comparação de tag.
* **COMPARE_TAG:** Verifica a ocorrência de *hit* (bit de validade ativo e correspondência de tag). Em caso de *miss*, avalia o bit *dirty* para decidir se avança para escrita ou alocação.
* **WRITE_BACK:** Responsável por transferir as 4 palavras de um bloco modificado (*dirty*) para a memória principal utilizando transferências do tipo burst.
* **ALLOCATE:** Carrega um novo bloco inteiro de 4 palavras da memória principal via burst. Ao concluir, atualiza os registradores de validade e tag da linha.

## 🧩 Decomposição de Endereçamento

Para um endereço de 32 bits, o sistema realiza a seguinte decomposição lógica:

| Campo | Bits | Largura | Descrição |
| :--- | :--- | :--- | :--- |
| **Tag** | [31:10] | 22 bits | Identifica o bloco alocado na memória. |
| **Index** | [9:4] | 6 bits | Seleciona a linha específica na cache. |
| **Offset** | [3:0] | 4 bits | Mapeia o byte exato dentro do bloco de 16 bytes. |