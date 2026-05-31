// =============================================================================
// Cache Controller — Trabalho Prático 1
// Baseado em: Computer Organization and Design: RISC-V Edition, Cap. 5, Sec. 5.12
//
// Configuração padrão:
//   Capacidade      : 1 KB  (64 blocos × 16 bytes)
//   Organização     : Direct-Mapped
//   Tamanho bloco   : 16 bytes (4 palavras de 32 bits)
//   Política escrita: Write-Back + Write-Allocate
// =============================================================================

`timescale 1ns/1ps

module cache_controller #(
    parameter int CACHE_SIZE_BYTES  = 1024,
    parameter int BLOCK_SIZE_BYTES  = 16,
    parameter int ADDR_WIDTH        = 32,
    parameter int DATA_WIDTH        = 32,
    parameter int NUM_BLOCKS        = CACHE_SIZE_BYTES / BLOCK_SIZE_BYTES,
    parameter int WORDS_PER_BLOCK   = BLOCK_SIZE_BYTES / (DATA_WIDTH/8),
    parameter int OFFSET_BITS       = $clog2(BLOCK_SIZE_BYTES),
    parameter int INDEX_BITS        = $clog2(NUM_BLOCKS),
    parameter int TAG_BITS          = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // --- Interface CPU ---
    input  logic                    cpu_req,
    input  logic                    cpu_we,
    input  logic [ADDR_WIDTH-1:0]   cpu_addr,
    input  logic [DATA_WIDTH-1:0]   cpu_wdata,
    output logic [DATA_WIDTH-1:0]   cpu_rdata,
    output logic                    cpu_ack,
    output logic                    cpu_stall,

    // --- Interface Memória Principal ---
    output logic                    mem_req,
    output logic                    mem_we,
    output logic [ADDR_WIDTH-1:0]   mem_addr,
    output logic [DATA_WIDTH-1:0]   mem_wdata,
    input  logic [DATA_WIDTH-1:0]   mem_rdata,
    input  logic                    mem_ack
);

    // =========================================================================
    // Arrays da cache
    // =========================================================================
    logic                   cache_valid [0:NUM_BLOCKS-1];
    logic                   cache_dirty [0:NUM_BLOCKS-1];
    logic [TAG_BITS-1:0]    cache_tag   [0:NUM_BLOCKS-1];
    logic [DATA_WIDTH-1:0]  cache_data  [0:NUM_BLOCKS-1][0:WORDS_PER_BLOCK-1];

    // =========================================================================
    // FSM
    // =========================================================================
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] COMPARE_TAG = 3'd1;
    localparam [2:0] WRITE_BACK  = 3'd2;
    localparam [2:0] ALLOCATE    = 3'd3;

    logic [2:0] state, next_state;

    // =========================================================================
    // Decodificação de endereço (sobre cpu_addr — combinacional)
    // =========================================================================
    logic [1:0]             addr_word_off;
    logic [INDEX_BITS-1:0]  addr_index;
    logic [TAG_BITS-1:0]    addr_tag;

    assign addr_word_off = cpu_addr[OFFSET_BITS-1:2];
    assign addr_index    = cpu_addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS];
    assign addr_tag      = cpu_addr[ADDR_WIDTH-1 : OFFSET_BITS + INDEX_BITS];

    // =========================================================================
    // Contexto salvo
    // =========================================================================
    logic [DATA_WIDTH-1:0]  saved_wdata;
    logic                   saved_we;
    logic [INDEX_BITS-1:0]  saved_index;
    logic [TAG_BITS-1:0]    saved_tag;
    logic [1:0]             saved_word_off;

    logic [1:0]             burst_cnt;

    // =========================================================================
    // Hit combinacional (sobre contexto salvo)
    // =========================================================================
    logic hit;
    assign hit = cache_valid[saved_index] && (cache_tag[saved_index] == saved_tag);

    // Endereços base
    logic [ADDR_WIDTH-1:0] wb_base;
    logic [ADDR_WIDTH-1:0] alloc_base;
    assign wb_base    = {cache_tag[saved_index], saved_index, {OFFSET_BITS{1'b0}}};
    assign alloc_base = {saved_tag,              saved_index, {OFFSET_BITS{1'b0}}};

    // =========================================================================
    // Registro de estado
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // =========================================================================
    // Próximo estado
    // =========================================================================
    always_comb begin
        next_state = state;
        case (state)
            IDLE:        if (cpu_req) next_state = COMPARE_TAG;

            COMPARE_TAG: begin
                if (hit) begin
                    next_state = IDLE;
                end else begin
                    if (cache_valid[saved_index] && cache_dirty[saved_index])
                        next_state = WRITE_BACK;
                    else
                        next_state = ALLOCATE;
                end
            end

            WRITE_BACK:
                if (mem_ack && (burst_cnt == 2'd3)) next_state = ALLOCATE;

            ALLOCATE:
                if (mem_ack && (burst_cnt == 2'd3)) next_state = COMPARE_TAG;

            default: next_state = IDLE;
        endcase
    end

    // =========================================================================
    // Lógica sequencial — saídas e cache
    // =========================================================================
    integer i, w;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_BLOCKS; i = i + 1) begin
                cache_valid[i] <= 1'b0;
                cache_dirty[i] <= 1'b0;
                cache_tag[i]   <= '0;
                for (w = 0; w < WORDS_PER_BLOCK; w = w + 1)
                    cache_data[i][w] <= '0;
            end
            cpu_rdata      <= '0;
            cpu_ack        <= 1'b0;
            cpu_stall      <= 1'b0;
            mem_req        <= 1'b0;
            mem_we         <= 1'b0;
            mem_addr       <= '0;
            mem_wdata      <= '0;
            burst_cnt      <= 2'd0;
            saved_wdata    <= '0;
            saved_we       <= 1'b0;
            saved_index    <= '0;
            saved_tag      <= '0;
            saved_word_off <= 2'd0;

        end else begin
            cpu_ack <= 1'b0;
            mem_req <= 1'b0;
            mem_we  <= 1'b0;

            case (state)
                // -----------------------------------------------------------
                IDLE: begin
                    cpu_stall <= 1'b0;
                    if (cpu_req) begin
                        saved_wdata    <= cpu_wdata;
                        saved_we       <= cpu_we;
                        saved_index    <= addr_index;
                        saved_tag      <= addr_tag;
                        saved_word_off <= addr_word_off;
                        cpu_stall      <= 1'b1;
                    end
                end

                // -----------------------------------------------------------
                COMPARE_TAG: begin
                    if (hit) begin
                        if (!saved_we) begin
                            cpu_rdata <= cache_data[saved_index][saved_word_off];
                        end else begin
                            cache_data[saved_index][saved_word_off] <= saved_wdata;
                            cache_dirty[saved_index]                <= 1'b1;
                        end
                        cpu_ack   <= 1'b1;
                        cpu_stall <= 1'b0;
                    end else begin
                        burst_cnt <= 2'd0;
                        cpu_stall <= 1'b1;
                        if (cache_valid[saved_index] && cache_dirty[saved_index]) begin
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= wb_base;
                            mem_wdata <= cache_data[saved_index][0];
                        end else begin
                            mem_req  <= 1'b1;
                            mem_we   <= 1'b0;
                            mem_addr <= alloc_base;
                        end
                    end
                end

                // -----------------------------------------------------------
                WRITE_BACK: begin
                    if (mem_ack) begin
                        if (burst_cnt < 2'd3) begin
                            burst_cnt <= burst_cnt + 2'd1;
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= wb_base + ((burst_cnt + 1) << 2);
                            mem_wdata <= cache_data[saved_index][burst_cnt + 1];
                        end else begin
                            burst_cnt              <= 2'd0;
                            cache_dirty[saved_index] <= 1'b0;
                            mem_req  <= 1'b1;
                            mem_we   <= 1'b0;
                            mem_addr <= alloc_base;
                        end
                    end else begin
                        mem_req   <= 1'b1;
                        mem_we    <= 1'b1;
                        mem_addr  <= wb_base + (burst_cnt << 2);
                        mem_wdata <= cache_data[saved_index][burst_cnt];
                    end
                end

                // -----------------------------------------------------------
                ALLOCATE: begin
                    if (mem_ack) begin
                        cache_data[saved_index][burst_cnt] <= mem_rdata;
                        if (burst_cnt < 2'd3) begin
                            burst_cnt <= burst_cnt + 2'd1;
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b0;
                            mem_addr  <= alloc_base + ((burst_cnt + 1) << 2);
                        end else begin
                            cache_valid[saved_index] <= 1'b1;
                            cache_dirty[saved_index] <= 1'b0;
                            cache_tag[saved_index]   <= saved_tag;
                            burst_cnt                <= 2'd0;
                        end
                    end else begin
                        mem_req  <= 1'b1;
                        mem_we   <= 1'b0;
                        mem_addr <= alloc_base + (burst_cnt << 2);
                    end
                end

                default: ;
            endcase
        end
    end

endmodule
