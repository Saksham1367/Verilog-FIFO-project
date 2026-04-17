`timescale 1ns/1ps

module tb_fifo;
    reg rd_en;
    reg wr_en;
    reg [7:0] wr_data;
    wire [7:0] rd_data;
    reg rd_clk;
    reg wr_clk;
    wire [2:0] rd_ptr;
    wire [2:0] wr_ptr;
    reg rd_rst;
    reg wr_rst;
    wire full;
    wire empty;

    integer i;
    integer errors;

    fifo dut (
        .wr_clk (wr_clk),
        .wr_rst (wr_rst),
        .wr_en  (wr_en),
        .wr_data(wr_data),
        .wr_ptr (wr_ptr),
        .rd_clk (rd_clk),
        .rd_rst (rd_rst),
        .rd_en  (rd_en),
        .rd_data(rd_data),
        .rd_ptr (rd_ptr),
        .full   (full),
        .empty  (empty)
    );

    always #5  wr_clk = ~wr_clk;
    always #13 rd_clk = ~rd_clk;

    task wait_wr_cycles;
        input [31:0] cycles;
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(posedge wr_clk);
            end
        end
    endtask

    task wait_rd_cycles;
        input [31:0] cycles;
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(posedge rd_clk);
            end
        end
    endtask

    task write_byte;
        input [7:0] data;
        begin
            @(negedge wr_clk);
            wr_data = data;
            wr_en   = 1'b1;
            @(posedge wr_clk);
            #1;
            wr_en   = 1'b0;
        end
    endtask

    task read_and_check;
        input [7:0] expected;
        begin
            @(negedge rd_clk);
            rd_en = 1'b1;
            @(posedge rd_clk);
            #1;
            if (rd_data !== expected) begin
                $display("ERROR: expected %02h, got %02h at time %0t", expected, rd_data, $time);
                errors = errors + 1;
            end
            rd_en = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars(0, tb_fifo);

        rd_en   = 1'b0;
        wr_en   = 1'b0;
        wr_data = 8'h00;
        rd_clk  = 1'b0;
        wr_clk  = 1'b0;
        rd_rst  = 1'b1;
        wr_rst  = 1'b1;
        errors  = 0;

        repeat (2) @(posedge wr_clk);
        repeat (2) @(posedge rd_clk);
        wr_rst = 1'b0;
        rd_rst = 1'b0;

        wait_wr_cycles(2);
        wait_rd_cycles(2);

        if (empty !== 1'b1 || full !== 1'b0) begin
            $display("ERROR: FIFO should be empty after reset.");
            errors = errors + 1;
        end

        $display("Phase 1: fill FIFO");
        for (i = 0; i < 8; i = i + 1) begin
            write_byte(8'h10 + i);
        end

        wait_wr_cycles(2);
        if (full !== 1'b1) begin
            $display("ERROR: FIFO should be full after 8 writes.");
            errors = errors + 1;
        end

        $display("Phase 1: overflow write should be blocked");
        write_byte(8'hFF);
        wait_wr_cycles(1);
        if (full !== 1'b1) begin
            $display("ERROR: full flag should stay high when FIFO is full.");
            errors = errors + 1;
        end

        wait_rd_cycles(3);
        $display("Phase 1: drain FIFO");
        for (i = 0; i < 8; i = i + 1) begin
            read_and_check(8'h10 + i);
        end

        wait_rd_cycles(2);
        if (empty !== 1'b1) begin
            $display("ERROR: FIFO should be empty after 8 reads.");
            errors = errors + 1;
        end

        $display("Phase 2: wrap-around and mixed operation");
        for (i = 0; i < 4; i = i + 1) begin
            write_byte(8'h20 + i);
        end

        wait_rd_cycles(3);

        read_and_check(8'h20);
        read_and_check(8'h21);

        for (i = 0; i < 6; i = i + 1) begin
            write_byte(8'h30 + i);
        end

        wait_rd_cycles(4);

        read_and_check(8'h22);
        read_and_check(8'h23);
        read_and_check(8'h30);
        read_and_check(8'h31);
        read_and_check(8'h32);
        read_and_check(8'h33);
        read_and_check(8'h34);
        read_and_check(8'h35);

        wait_rd_cycles(2);
        if (empty !== 1'b1) begin
            $display("ERROR: FIFO should be empty at the end of the test.");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("TEST PASSED: FIFO behaved correctly.");
        end else begin
            $display("TEST FAILED: %0d error(s) found.", errors);
        end

        $finish;
    end
endmodule
