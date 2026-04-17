`timescale 1ns/1ps

module fifo (
    input  wire       wr_clk,
    input  wire       wr_rst,
    input  wire       wr_en,
    input  wire [7:0] wr_data,
    output wire [2:0] wr_ptr,
    input  wire       rd_clk,
    input  wire       rd_rst,
    input  wire       rd_en,
    output reg  [7:0] rd_data,
    output wire [2:0] rd_ptr,
    output reg        full,
    output reg        empty
);
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 3;
    localparam DEPTH     = (1 << ADDR_WIDTH);
    localparam PTR_WIDTH = ADDR_WIDTH + 1;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    reg [PTR_WIDTH-1:0] wr_bin;
    reg [PTR_WIDTH-1:0] rd_bin;
    reg [PTR_WIDTH-1:0] wr_gray;
    reg [PTR_WIDTH-1:0] rd_gray;

    reg [PTR_WIDTH-1:0] rd_gray_sync1;
    reg [PTR_WIDTH-1:0] rd_gray_sync2;
    reg [PTR_WIDTH-1:0] wr_gray_sync1;
    reg [PTR_WIDTH-1:0] wr_gray_sync2;

    wire wr_inc = wr_en && !full;
    wire rd_inc = rd_en && !empty;

    wire [PTR_WIDTH-1:0] wr_bin_next  = wr_bin + wr_inc;
    wire [PTR_WIDTH-1:0] rd_bin_next  = rd_bin + rd_inc;
    wire [PTR_WIDTH-1:0] wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
    wire [PTR_WIDTH-1:0] rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;

    wire full_next =
        (wr_gray_next == {~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2],
                          rd_gray_sync2[PTR_WIDTH-3:0]});
    wire empty_next = (rd_gray_next == wr_gray_sync2);

    assign wr_ptr = wr_bin[ADDR_WIDTH-1:0];
    assign rd_ptr = rd_bin[ADDR_WIDTH-1:0];

    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            wr_bin        <= {PTR_WIDTH{1'b0}};
            wr_gray       <= {PTR_WIDTH{1'b0}};
            rd_gray_sync1 <= {PTR_WIDTH{1'b0}};
            rd_gray_sync2 <= {PTR_WIDTH{1'b0}};
            full          <= 1'b0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;

            if (wr_inc) begin
                mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            end

            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
            full    <= full_next;
        end
    end

    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            rd_bin        <= {PTR_WIDTH{1'b0}};
            rd_gray       <= {PTR_WIDTH{1'b0}};
            wr_gray_sync1 <= {PTR_WIDTH{1'b0}};
            wr_gray_sync2 <= {PTR_WIDTH{1'b0}};
            rd_data       <= {DATA_WIDTH{1'b0}};
            empty         <= 1'b1;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;

            if (rd_inc) begin
                rd_data <= mem[rd_bin[ADDR_WIDTH-1:0]];
            end

            rd_bin <= rd_bin_next;
            rd_gray <= rd_gray_next;
            empty   <= empty_next;
        end
    end
endmodule
