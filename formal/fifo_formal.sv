`timescale 1ns/1ps

module fifo_formal;
    localparam integer DATA_WIDTH          = 4;
    localparam integer ADDR_WIDTH          = 2;
    localparam integer DEPTH               = (1 << ADDR_WIDTH);
    localparam integer ALMOST_FULL_MARGIN  = 1;
    localparam integer ALMOST_EMPTY_MARGIN = 1;

    (* gclk *) reg formal_timestep;
    reg clk = 1'b0;
    always @(posedge formal_timestep) begin
        clk <= !clk;
    end

    reg [2:0] rst_counter = 3'd3;
    always @(posedge clk) begin
        if (rst_counter != 0) begin
            rst_counter <= rst_counter - 1'b1;
        end
    end

    wire rst = (rst_counter != 0);

    (* anyseq *) reg                   wr_en_formal;
    (* anyseq *) reg                   rd_en_formal;
    (* anyseq *) reg  [DATA_WIDTH-1:0] wr_data_formal;

    wire [ADDR_WIDTH-1:0] wr_ptr;
    wire [ADDR_WIDTH:0]   wr_count;
    wire                  wr_ack;
    wire                  overflow;
    wire                  full;
    wire                  almost_full;
    wire [DATA_WIDTH-1:0] rd_data;
    wire [ADDR_WIDTH-1:0] rd_ptr;
    wire [ADDR_WIDTH:0]   rd_count;
    wire                  rd_valid;
    wire                  underflow;
    wire                  empty;
    wire                  almost_empty;
    wire [ADDR_WIDTH:0]   formal_wr_bin;
    wire [ADDR_WIDTH:0]   formal_rd_bin;
    wire [ADDR_WIDTH:0]   exact_count;
    wire [ADDR_WIDTH-1:0] exact_wr_ptr;
    wire [ADDR_WIDTH-1:0] exact_rd_ptr;
    wire [ADDR_WIDTH:0]   model_count_next;
    wire [ADDR_WIDTH-1:0] model_tail_next;
    wire [ADDR_WIDTH-1:0] model_head_next;

    reg [DATA_WIDTH-1:0] model_mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] model_head = {ADDR_WIDTH{1'b0}};
    reg [ADDR_WIDTH-1:0] model_tail = {ADDR_WIDTH{1'b0}};
    reg [ADDR_WIDTH:0]   model_count = {(ADDR_WIDTH+1){1'b0}};
    reg [1:0]            reset_guard = 2'd0;
    reg                  seen_full = 1'b0;
    reg                  seen_overflow = 1'b0;
    reg                  seen_underflow = 1'b0;
    reg                  f_past_valid = 1'b0;

    fifo #(
        .DATA_WIDTH         (DATA_WIDTH),
        .ADDR_WIDTH         (ADDR_WIDTH),
        .ALMOST_FULL_MARGIN (ALMOST_FULL_MARGIN),
        .ALMOST_EMPTY_MARGIN(ALMOST_EMPTY_MARGIN)
    ) dut (
        .wr_clk      (clk),
        .wr_rst      (rst),
        .wr_en       (wr_en_formal),
        .wr_data     (wr_data_formal),
        .wr_ptr      (wr_ptr),
        .wr_count    (wr_count),
        .wr_ack      (wr_ack),
        .overflow    (overflow),
        .full        (full),
        .almost_full (almost_full),
        .rd_clk      (clk),
        .rd_rst      (rst),
        .rd_en       (rd_en_formal),
        .rd_data     (rd_data),
        .rd_ptr      (rd_ptr),
        .rd_count    (rd_count),
        .rd_valid    (rd_valid),
        .underflow   (underflow),
        .empty       (empty),
        .almost_empty(almost_empty),
        .formal_wr_bin(formal_wr_bin),
        .formal_rd_bin(formal_rd_bin)
    );

    assign exact_count  = formal_wr_bin - formal_rd_bin;
    assign exact_wr_ptr = formal_wr_bin[ADDR_WIDTH-1:0];
    assign exact_rd_ptr = formal_rd_bin[ADDR_WIDTH-1:0];
    assign model_count_next = model_count
                            + {{ADDR_WIDTH{1'b0}}, wr_ack}
                            - {{ADDR_WIDTH{1'b0}}, rd_valid};
    assign model_tail_next = model_tail + wr_ack;
    assign model_head_next = model_head + rd_valid;

    always @(posedge clk) begin
        f_past_valid <= 1'b1;

        if (rst) begin
            reset_guard     <= 2'd2;
        end else if (reset_guard != 0) begin
            reset_guard     <= reset_guard - 1'b1;
        end

        if (rst || (reset_guard != 0)) begin
            model_head      <= {ADDR_WIDTH{1'b0}};
            model_tail      <= {ADDR_WIDTH{1'b0}};
            model_count     <= {(ADDR_WIDTH+1){1'b0}};
            seen_full       <= 1'b0;
            seen_overflow   <= 1'b0;
            seen_underflow  <= 1'b0;

            assert(empty);
            assert(!full);
            assert(!wr_ack);
            assert(!rd_valid);
            assert(!overflow);
            assert(!underflow);
        end else begin
            assert(!(wr_ack && overflow));
            assert(!(rd_valid && underflow));
            assert(almost_full == (wr_count >= (DEPTH - ALMOST_FULL_MARGIN)));
            assert(almost_empty == (rd_count <= ALMOST_EMPTY_MARGIN));
`ifndef FORMAL_INDUCTION
            assert(exact_count <= DEPTH);
            assert(wr_count <= DEPTH);
            assert(rd_count <= DEPTH);
            assert(model_count <= DEPTH);
            assert(model_count_next == exact_count);
            assert(model_tail_next == exact_wr_ptr);
            assert(model_head_next == exact_rd_ptr);
`endif

`ifndef FORMAL_INDUCTION
            if (wr_ack) begin
                assert(model_count < DEPTH);
            end

            if (rd_valid) begin
                assert(model_count > 0);
`ifdef FORMAL_STRONG_DATA
                assert(rd_data == model_mem[model_head]);
`endif
            end

            if (f_past_valid && !$past(rst || (reset_guard != 0))) begin
                assert(wr_ack == $past(wr_en_formal && !full));
                assert(rd_valid == $past(rd_en_formal && !empty));
            end
`endif

            if (wr_ack) begin
                model_mem[model_tail] <= $past(wr_data_formal);
                model_tail            <= model_tail + 1'b1;
            end

            if (rd_valid) begin
                model_head <= model_head + 1'b1;
            end

            case ({wr_ack, rd_valid})
                2'b10: model_count <= model_count + 1'b1;
                2'b01: model_count <= model_count - 1'b1;
                default: model_count <= model_count;
            endcase

            if (full) begin
                seen_full <= 1'b1;
            end
            if (overflow) begin
                seen_overflow <= 1'b1;
            end
            if (underflow) begin
                seen_underflow <= 1'b1;
            end

            cover(full);
            cover(overflow);
            cover(underflow);
            cover(seen_full && model_count == 0);
            cover(seen_full && seen_overflow && seen_underflow);
        end
    end
endmodule
