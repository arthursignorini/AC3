// =============================================================================
// Modelo de Memória Principal — Simulação
// Memória simples com latência configurável (handshake mem_req/mem_ack)
// =============================================================================

`timescale 1ns/1ps

module main_memory #(
    parameter int ADDR_WIDTH   = 32,
    parameter int DATA_WIDTH   = 32,
    parameter int MEM_SIZE     = 4096,   // palavras (16 KB)
    parameter int LATENCY      = 2       // ciclos de latência
)(
    input  logic                    clk,
    input  logic                    rst_n,

    input  logic                    mem_req,
    input  logic                    mem_we,
    input  logic [ADDR_WIDTH-1:0]   mem_addr,
    input  logic [DATA_WIDTH-1:0]   mem_wdata,
    output logic [DATA_WIDTH-1:0]   mem_rdata,
    output logic                    mem_ack
);

    logic [DATA_WIDTH-1:0] mem_array [MEM_SIZE];
    logic [$clog2(LATENCY+1)-1:0] lat_cnt;

    // Inicializa memória com padrão conhecido (endereço × 4 + 1)
    initial begin
        for (int i = 0; i < MEM_SIZE; i++)
            mem_array[i] = (i * 4) + 1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ack  <= 1'b0;
            mem_rdata <= '0;
            lat_cnt  <= '0;
        end else begin
            mem_ack <= 1'b0;

            if (mem_req) begin
                if (lat_cnt < LATENCY - 1) begin
                    lat_cnt <= lat_cnt + 1'b1;
                end else begin
                    lat_cnt  <= '0;
                    mem_ack  <= 1'b1;

                    if (mem_we) begin
                        mem_array[mem_addr[ADDR_WIDTH-1:2] % MEM_SIZE] <= mem_wdata;
                    end else begin
                        mem_rdata <= mem_array[mem_addr[ADDR_WIDTH-1:2] % MEM_SIZE];
                    end
                end
            end else begin
                lat_cnt <= '0;
            end
        end
    end

endmodule
