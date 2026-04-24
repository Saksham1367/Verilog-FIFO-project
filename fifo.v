`timescale 1ns/1ps

module fifo #(
    parameter integer DATA_WIDTH          = 8,
    parameter integer ADDR_WIDTH          = 3,
    parameter integer ALMOST_FULL_MARGIN  = 1,
    parameter integer ALMOST_EMPTY_MARGIN = 1
) (
    input  wire                  wr_clk,
    input  wire                  wr_rst,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire [ADDR_WIDTH-1:0] wr_ptr,
    output wire [ADDR_WIDTH:0]   wr_count,
    output reg                   wr_ack,
    output reg                   overflow,
    output reg                   full,
    output wire                  almost_full,
    input  wire                  rd_clk,
    input  wire                  rd_rst,
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire [ADDR_WIDTH-1:0] rd_ptr,
    output wire [ADDR_WIDTH:0]   rd_count,
    output reg                   rd_valid,
    output reg                   underflow,
    output reg                   empty,
    output wire                  almost_empty
`ifdef FORMAL
    ,
    output wire [ADDR_WIDTH:0]   formal_wr_bin,
    output wire [ADDR_WIDTH:0]   formal_rd_bin
`endif
);
    localparam integer DEPTH     = (1 << ADDR_WIDTH);
    localparam integer PTR_WIDTH = ADDR_WIDTH + 1;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    reg [PTR_WIDTH-1:0] wr_bin;
    reg [PTR_WIDTH-1:0] rd_bin;
    reg [PTR_WIDTH-1:0] wr_gray;
    reg [PTR_WIDTH-1:0] rd_gray;

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [PTR_WIDTH-1:0] rd_gray_sync1;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [PTR_WIDTH-1:0] rd_gray_sync2;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [PTR_WIDTH-1:0] wr_gray_sync1;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [PTR_WIDTH-1:0] wr_gray_sync2;

    reg [1:0] wr_rst_pipe;
    reg [1:0] rd_rst_pipe;

    wire wr_rst_local = wr_rst_pipe[0];
    wire rd_rst_local = rd_rst_pipe[0];

    wire [PTR_WIDTH-1:0] wr_bin_next;
    wire [PTR_WIDTH-1:0] rd_bin_next;
    wire [PTR_WIDTH-1:0] wr_gray_next;
    wire [PTR_WIDTH-1:0] rd_gray_next;
    wire [PTR_WIDTH-1:0] rd_bin_sync;
    wire [PTR_WIDTH-1:0] wr_bin_sync;
    wire [PTR_WIDTH-1:0] wr_count_int;
    wire [PTR_WIDTH-1:0] rd_count_int;
    wire [31:0]          wr_count_cmp;
    wire [31:0]          rd_count_cmp;
    wire [PTR_WIDTH-1:0] wr_push_ext;
    wire [PTR_WIDTH-1:0] rd_pop_ext;
    wire                  wr_push;
    wire                  rd_pop;
    wire                  full_next;
    wire                  empty_next;

    function [PTR_WIDTH-1:0] bin2gray;
        input [PTR_WIDTH-1:0] bin;
        begin
            bin2gray = (bin >> 1) ^ bin;
        end
    endfunction

    function [PTR_WIDTH-1:0] gray2bin;
        input [PTR_WIDTH-1:0] gray;
        integer idx;
        begin
            gray2bin = {PTR_WIDTH{1'b0}};
            for (idx = 0; idx < PTR_WIDTH; idx = idx + 1) begin
                gray2bin[idx] = ^(gray >> idx);
            end
        end
    endfunction

    function [PTR_WIDTH-1:0] invert_msb2;
        input [PTR_WIDTH-1:0] gray;
        begin
            invert_msb2               = gray;
            invert_msb2[PTR_WIDTH-1]  = ~gray[PTR_WIDTH-1];
            invert_msb2[PTR_WIDTH-2]  = ~gray[PTR_WIDTH-2];
        end
    endfunction

    initial begin
        if (DATA_WIDTH < 1) begin
            $error("fifo: DATA_WIDTH must be >= 1");
            $finish;
        end

        if (ADDR_WIDTH < 1) begin
            $error("fifo: ADDR_WIDTH must be >= 1");
            $finish;
        end

        if ((ALMOST_FULL_MARGIN < 0) || (ALMOST_FULL_MARGIN > DEPTH)) begin
            $error("fifo: ALMOST_FULL_MARGIN must be between 0 and DEPTH");
            $finish;
        end

        if ((ALMOST_EMPTY_MARGIN < 0) || (ALMOST_EMPTY_MARGIN > DEPTH)) begin
            $error("fifo: ALMOST_EMPTY_MARGIN must be between 0 and DEPTH");
            $finish;
        end
    end

    assign wr_push = wr_en && !full;
    assign rd_pop  = rd_en && !empty;
    assign wr_push_ext = {{PTR_WIDTH-1{1'b0}}, wr_push};
    assign rd_pop_ext  = {{PTR_WIDTH-1{1'b0}}, rd_pop};

    assign wr_bin_next  = wr_bin + wr_push_ext;
    assign rd_bin_next  = rd_bin + rd_pop_ext;
    assign wr_gray_next = bin2gray(wr_bin_next);
    assign rd_gray_next = bin2gray(rd_bin_next);

    assign rd_bin_sync = gray2bin(rd_gray_sync2);
    assign wr_bin_sync = gray2bin(wr_gray_sync2);

    assign wr_count_int = wr_bin - rd_bin_sync;
    assign rd_count_int = wr_bin_sync - rd_bin;
    assign wr_count_cmp = {{(32-PTR_WIDTH){1'b0}}, wr_count_int};
    assign rd_count_cmp = {{(32-PTR_WIDTH){1'b0}}, rd_count_int};

    assign wr_ptr = wr_bin[ADDR_WIDTH-1:0];
    assign rd_ptr = rd_bin[ADDR_WIDTH-1:0];
    assign wr_count = wr_count_int;
    assign rd_count = rd_count_int;
`ifdef FORMAL
    assign formal_wr_bin = wr_bin;
    assign formal_rd_bin = rd_bin;
`endif

    assign full_next    = (wr_gray_next == invert_msb2(rd_gray_sync2));
    assign empty_next   = (rd_gray_next == wr_gray_sync2);
    assign almost_full  = (wr_count_cmp >= (DEPTH - ALMOST_FULL_MARGIN));
    assign almost_empty = (rd_count_cmp <= ALMOST_EMPTY_MARGIN);

    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            wr_rst_pipe <= 2'b11;
        end else begin
            wr_rst_pipe <= {1'b0, wr_rst_pipe[1]};
        end
    end

    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            rd_rst_pipe <= 2'b11;
        end else begin
            rd_rst_pipe <= {1'b0, rd_rst_pipe[1]};
        end
    end

    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            wr_bin        <= {PTR_WIDTH{1'b0}};
            wr_gray       <= {PTR_WIDTH{1'b0}};
            rd_gray_sync1 <= {PTR_WIDTH{1'b0}};
            rd_gray_sync2 <= {PTR_WIDTH{1'b0}};
            wr_ack        <= 1'b0;
            overflow      <= 1'b0;
            full          <= 1'b0;
        end else if (wr_rst_local) begin
            wr_bin        <= {PTR_WIDTH{1'b0}};
            wr_gray       <= {PTR_WIDTH{1'b0}};
            rd_gray_sync1 <= {PTR_WIDTH{1'b0}};
            rd_gray_sync2 <= {PTR_WIDTH{1'b0}};
            wr_ack        <= 1'b0;
            overflow      <= 1'b0;
            full          <= 1'b0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;

            wr_ack   <= wr_push;
            overflow <= wr_en && full;

            if (wr_push) begin
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
            rd_valid      <= 1'b0;
            underflow     <= 1'b0;
            empty         <= 1'b1;
        end else if (rd_rst_local) begin
            rd_bin        <= {PTR_WIDTH{1'b0}};
            rd_gray       <= {PTR_WIDTH{1'b0}};
            wr_gray_sync1 <= {PTR_WIDTH{1'b0}};
            wr_gray_sync2 <= {PTR_WIDTH{1'b0}};
            rd_data       <= {DATA_WIDTH{1'b0}};
            rd_valid      <= 1'b0;
            underflow     <= 1'b0;
            empty         <= 1'b1;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;

            rd_valid  <= rd_pop;
            underflow <= rd_en && empty;

            if (rd_pop) begin
                rd_data <= mem[rd_bin[ADDR_WIDTH-1:0]];
            end

            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
            empty   <= empty_next;
        end
    end
endmodule
