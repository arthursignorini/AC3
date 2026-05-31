// =============================================================================
// Testbench — Cache Controller
// Cobre todos os cenários da Seção 7 do enunciado
// =============================================================================
`timescale 1ns/1ps

module tb_cache_controller;

    // =========================================================================
    // Parâmetros (devem coincidir com o DUT)
    // =========================================================================
    localparam ADDR_WIDTH      = 32;
    localparam DATA_WIDTH      = 32;
    localparam CACHE_SIZE      = 1024;
    localparam BLOCK_SIZE      = 16;
    localparam NUM_BLOCKS      = CACHE_SIZE / BLOCK_SIZE;   // 64
    localparam WORDS_PER_BLK   = BLOCK_SIZE / 4;            // 4
    localparam OFFSET_BITS     = 4;   // log2(16)
    localparam INDEX_BITS      = 6;   // log2(64)
    localparam TAG_BITS        = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // 22
    localparam CLK_PERIOD      = 10;

    // =========================================================================
    // Helpers de decodificação de endereço (usados no TB)
    // =========================================================================
    function automatic logic [1:0] get_woff(input logic [31:0] a);
        get_woff = a[OFFSET_BITS-1:2];
    endfunction
    function automatic logic [INDEX_BITS-1:0] get_idx(input logic [31:0] a);
        get_idx = a[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    endfunction
    function automatic logic [TAG_BITS-1:0] get_tag(input logic [31:0] a);
        get_tag = a[ADDR_WIDTH-1:OFFSET_BITS+INDEX_BITS];
    endfunction

    // =========================================================================
    // Sinais
    // =========================================================================
    logic                   clk, rst_n;
    logic                   cpu_req, cpu_we;
    logic [ADDR_WIDTH-1:0]  cpu_addr;
    logic [DATA_WIDTH-1:0]  cpu_wdata;
    logic [DATA_WIDTH-1:0]  cpu_rdata;
    logic                   cpu_ack, cpu_stall;

    logic                   mem_req, mem_we;
    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic [DATA_WIDTH-1:0]  mem_wdata, mem_rdata;
    logic                   mem_ack;

    // =========================================================================
    // Contadores
    // =========================================================================
    int total_tests, pass_count, fail_count;

    // =========================================================================
    // DUT
    // =========================================================================
    cache_controller #(
        .CACHE_SIZE_BYTES(CACHE_SIZE),
        .BLOCK_SIZE_BYTES(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .cpu_req(cpu_req), .cpu_we(cpu_we),
        .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata), .cpu_ack(cpu_ack), .cpu_stall(cpu_stall),
        .mem_req(mem_req), .mem_we(mem_we),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata), .mem_ack(mem_ack)
    );

    // =========================================================================
    // Modelo de memória
    // =========================================================================
    main_memory #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
        .MEM_SIZE(4096), .LATENCY(2)
    ) mem_model (
        .clk(clk), .rst_n(rst_n),
        .mem_req(mem_req), .mem_we(mem_we),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata), .mem_ack(mem_ack)
    );

    // =========================================================================
    // Clock
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // VCD
    // =========================================================================
    initial begin
        $dumpfile("sim/cache_sim.vcd");
        $dumpvars(0, tb_cache_controller);
    end

    // =========================================================================
    // Tarefas auxiliares
    // =========================================================================
    task automatic cpu_read(
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data
    );
        @(posedge clk);
        cpu_req  <= 1'b1;
        cpu_we   <= 1'b0;
        cpu_addr <= addr;
        cpu_wdata<= '0;
        do @(posedge clk); while (!cpu_ack);
        data = cpu_rdata;
        cpu_req <= 1'b0;
        @(posedge clk);
    endtask

    task automatic cpu_write(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data
    );
        @(posedge clk);
        cpu_req   <= 1'b1;
        cpu_we    <= 1'b1;
        cpu_addr  <= addr;
        cpu_wdata <= data;
        do @(posedge clk); while (!cpu_ack);
        cpu_req <= 1'b0;
        @(posedge clk);
    endtask

    task automatic check(input string name, input logic cond);
        total_tests++;
        if (cond) begin
            $display("[PASS] %s", name);
            pass_count++;
        end else begin
            $display("[FAIL] %s  @ t=%0t", name, $time);
            fail_count++;
        end
    endtask

    task do_reset();
        rst_n = 1'b0;
        cpu_req = 0; cpu_we = 0; cpu_addr = 0; cpu_wdata = 0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);
    endtask

    // =========================================================================
    // Sequência de testes
    // =========================================================================
    logic [DATA_WIDTH-1:0] rdata_a, rdata_b;
    logic [ADDR_WIDTH-1:0] addr_a, addr_b, addr_c;
    logic [INDEX_BITS-1:0] idx;
    int all_ok;

    initial begin
        total_tests = 0;
        pass_count  = 0;
        fail_count  = 0;

        $display("==========================================================");
        $display("  TESTBENCH — Controlador de Cache");
        $display("  1KB, 64 blocos, direct-mapped, write-back, write-alloc");
        $display("==========================================================");

        do_reset();

        // ==================================================================
        // SUITE 1 — Read Path
        // ==================================================================
        $display("\n--- Suite 1: Read Path ---");

        // 1.1 Read miss → carrega bloco
        addr_a = 32'h0000_0040;
        cpu_read(addr_a, rdata_a);
        check("1.1 Read Miss retorna dado correto da memória",
              rdata_a == mem_model.mem_array[addr_a[31:2]]);

        // 1.2 Read hit (mesmo endereço, bloco já na cache)
        cpu_read(addr_a, rdata_b);
        check("1.2 Read Hit retorna mesmo valor", rdata_b == rdata_a);

        // 1.3 Read hit em outra palavra do mesmo bloco
        cpu_read(addr_a + 4, rdata_b);
        check("1.3 Read Hit outra palavra do bloco",
              rdata_b == mem_model.mem_array[(addr_a+4) >> 2]);

        // 1.4 Bit valid=1 após alocação
        idx = get_idx(addr_a);
        check("1.4 valid=1 após miss+alocação", dut.cache_valid[idx] == 1'b1);

        // 1.5 Tag correta após alocação
        check("1.5 Tag correta após alocação", dut.cache_tag[idx] == get_tag(addr_a));

        // ==================================================================
        // SUITE 2 — Write Path
        // ==================================================================
        $display("\n--- Suite 2: Write Path ---");

        // 2.1 Write hit → dado atualizado
        cpu_write(addr_a, 32'hDEAD_BEEF);
        cpu_read(addr_a, rdata_a);
        check("2.1 Write Hit — cache atualizada", rdata_a == 32'hDEAD_BEEF);

        // 2.2 Dirty bit=1 após write hit
        check("2.2 Write Hit — dirty=1", dut.cache_dirty[idx] == 1'b1);

        // 2.3 Write-back: memória ainda com valor original (não escreveu direto)
        check("2.3 Write-Back — mem não atualizada imediatamente",
              mem_model.mem_array[addr_a[31:2]] != 32'hDEAD_BEEF);

        // 2.4 Write miss com write-allocate
        addr_b = 32'h0000_1000;   // índice diferente
        cpu_write(addr_b, 32'hCAFE_BABE);
        cpu_read(addr_b, rdata_a);
        check("2.4 Write Miss (write-allocate) — leitura retorna valor escrito",
              rdata_a == 32'hCAFE_BABE);

        // ==================================================================
        // SUITE 3 — Substituição e Write-Back
        // ==================================================================
        $display("\n--- Suite 3: Substituição e Write-Back ---");

        // 3.1 Força write-back ao substituir bloco dirty
        // Garante dirty em addr_a
        cpu_write(addr_a, 32'hABCD_1234);
        // addr_c → mesmo índice que addr_a, tag diferente → gera conflito
        addr_c = {(get_tag(addr_a) + 1'b1), get_idx(addr_a), {OFFSET_BITS{1'b0}}};
        cpu_read(addr_c, rdata_a);   // deve triggar write-back de addr_a
        check("3.1 Write-Back ocorre ao substituir bloco dirty",
              mem_model.mem_array[addr_a[31:2]] == 32'hABCD_1234);

        // 3.2 Novo bloco alocado corretamente
        idx = get_idx(addr_c);
        check("3.2 Bloco substituto valid=1", dut.cache_valid[idx] == 1'b1);
        check("3.2 Tag do bloco substituto correta", dut.cache_tag[idx] == get_tag(addr_c));

        // 3.3 Preenchimento completo da cache
        $display("     Preenchendo todos os %0d blocos...", NUM_BLOCKS);
        begin
            logic [DATA_WIDTH-1:0] tmp;
            for (int i = 0; i < NUM_BLOCKS; i++) begin
                // Usa tag=0x3F (diferente da atual) para forçar novos blocos
                logic [ADDR_WIDTH-1:0] fa;
                fa = {22'h3F_0000, i[5:0], 4'h0};
                cpu_read(fa, tmp);
            end
        end
        all_ok = 1;
        for (int i = 0; i < NUM_BLOCKS; i++)
            if (!dut.cache_valid[i]) all_ok = 0;
        check("3.3 Todos os 64 blocos preenchidos (valid=1)", all_ok == 1);

        // 3.4 Política de substituição: direct-mapped
        // Em direct-mapped, um acesso com novo tag no mesmo índice SEMPRE substitui.
        // Verificamos que após 2 acessos conflitantes ao índice 5, o bloco
        // mais recente está na cache (não há escolha — o índice determina a linha).
        begin
            logic [DATA_WIDTH-1:0] tmp;
            logic [ADDR_WIDTH-1:0] f1, f2;
            f1 = {22'h00_0001, 6'd5, 4'h0};   // tag=1, índice=5
            f2 = {22'h00_0002, 6'd5, 4'h0};   // tag=2, índice=5 → substitui f1
            cpu_read(f1, tmp);
            cpu_read(f2, tmp);   // deve substituir f1
            check("3.4 Direct-Mapped: acesso conflitante substitui bloco anterior",
                  dut.cache_tag[5] == 22'h00_0002);
            check("3.4 Direct-Mapped: bloco substituído não está mais na cache (tag mudou)",
                  dut.cache_tag[5] != 22'h00_0001);
        end

        // ==================================================================
        // SUITE 4 — Consistência de Dados
        // ==================================================================
        $display("\n--- Suite 4: Consistência ---");

        // 4.1 Sequência R→W→R
        addr_a = 32'h0000_0080;
        cpu_read(addr_a, rdata_a);
        cpu_write(addr_a, 32'h1234_5678);
        cpu_read(addr_a, rdata_b);
        check("4.1 R→W→R: leitura reflete escrita", rdata_b == 32'h1234_5678);

        // 4.2 10 leituras consecutivas — valor estável
        begin
            logic [DATA_WIDTH-1:0] rd;
            all_ok = 1;
            for (int i = 0; i < 10; i++) begin
                cpu_read(addr_a, rd);
                if (rd !== 32'h1234_5678) all_ok = 0;
            end
            check("4.2 Valor estável em 10 leituras consecutivas", all_ok == 1);
        end

        // 4.3 Conflito de índice preserva dado na memória
        addr_a = 32'h0000_0100;
        addr_b = {(get_tag(addr_a) + 22'd1), get_idx(addr_a), {OFFSET_BITS{1'b0}}};
        cpu_write(addr_a, 32'hAAAA_AAAA);
        cpu_write(addr_b, 32'hBBBB_BBBB);   // desloca addr_a da cache
        cpu_read(addr_a, rdata_a);           // recarga addr_a
        check("4.3 Conflito de índice — write-back preservou dado na mem",
              mem_model.mem_array[addr_a[31:2]] == 32'hAAAA_AAAA);

        // ==================================================================
        // SUITE 5 — Casos Limite
        // ==================================================================
        $display("\n--- Suite 5: Casos Limite ---");

        // 5.1 Endereço 0x0
        cpu_read(32'h0000_0000, rdata_a);
        check("5.1 Acesso ao endereço 0x0",
              rdata_a == mem_model.mem_array[0]);

        // 5.2 Endereço alto (dentro do MEM_SIZE = 4096 palavras = 0x3FFC)
        cpu_read(32'h0000_3FFC, rdata_a);
        check("5.2 Acesso ao endereço extremo alto (0x3FFC)",
              rdata_a == mem_model.mem_array[32'h3FFC >> 2]);

        // 5.3 Reset — todos inválidos
        do_reset();
        all_ok = 1;
        for (int i = 0; i < NUM_BLOCKS; i++)
            if (dut.cache_valid[i]) all_ok = 0;
        check("5.3 Reset — todos valid=0", all_ok == 1);

        // 5.4 Reset — todos dirty=0
        all_ok = 1;
        for (int i = 0; i < NUM_BLOCKS; i++)
            if (dut.cache_dirty[i]) all_ok = 0;
        check("5.4 Reset — todos dirty=0", all_ok == 1);

        // 5.5 Primeiro acesso após reset
        cpu_read(32'h0000_0040, rdata_a);
        check("5.5 Primeiro acesso após reset carrega dado correto",
              rdata_a == mem_model.mem_array[32'h40 >> 2]);

        // ==================================================================
        // SUITE 6 — Handshake (Stall / Ack)
        // ==================================================================
        $display("\n--- Suite 6: Handshake CPU ---");

        do_reset();

        // 6.1 cpu_stall asserta durante miss
        @(posedge clk);
        cpu_req  <= 1'b1;
        cpu_we   <= 1'b0;
        cpu_addr <= 32'h0000_0200;
        // Aguarda stall subir (FSM precisa de 1 ciclo de IDLE→COMPARE_TAG)
        repeat(2) @(posedge clk);
        check("6.1 cpu_stall=1 durante miss", cpu_stall == 1'b1);
        do @(posedge clk); while (!cpu_ack);
        check("6.2 cpu_ack=1 ao concluir transação", cpu_ack == 1'b1);
        cpu_req <= 1'b0;
        repeat(2) @(posedge clk);
        check("6.3 cpu_stall=0 após conclusão", cpu_stall == 1'b0);

        // ==================================================================
        // Sumário
        // ==================================================================
        repeat(4) @(posedge clk);
        $display("\n==========================================================");
        $display("  RESULTADO FINAL");
        $display("  Total : %0d  |  Passou : %0d  |  Falhou : %0d",
                 total_tests, pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** TODOS OS TESTES PASSARAM ***");
        else
            $display("  *** %0d TESTE(S) FALHARAM ***", fail_count);
        $display("==========================================================");
        $finish;
    end

    // Watchdog
    initial begin #2_000_000; $display("[WATCHDOG] Timeout!"); $finish; end

endmodule
