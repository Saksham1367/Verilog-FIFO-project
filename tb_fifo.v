`timescale 1ns/1ps

module tb_fifo;
    localparam integer DATA_WIDTH          = 16;
    localparam integer ADDR_WIDTH          = 4;
    localparam integer DEPTH               = (1 << ADDR_WIDTH);
    localparam integer ALMOST_FULL_MARGIN  = 2;
    localparam integer ALMOST_EMPTY_MARGIN = 1;
    localparam integer RANDOM_WR_CYCLES    = 250;
    localparam integer RANDOM_RD_CYCLES    = 210;
    localparam integer MODEL_DEPTH         = 4096;

    reg                   wr_clk;
    reg                   wr_rst;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    wire [ADDR_WIDTH-1:0] wr_ptr;
    wire [ADDR_WIDTH:0]   wr_count;
    wire                  wr_ack;
    wire                  overflow;
    wire                  full;
    wire                  almost_full;

    reg                   rd_clk;
    reg                   rd_rst;
    reg                   rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire [ADDR_WIDTH-1:0] rd_ptr;
    wire [ADDR_WIDTH:0]   rd_count;
    wire                  rd_valid;
    wire                  underflow;
    wire                  empty;
    wire                  almost_empty;

    reg  [DATA_WIDTH-1:0] model_mem [0:MODEL_DEPTH-1];
    reg  [DATA_WIDTH-1:0] random_word;
    reg                   random_phase_active;
    integer               errors;
    integer               i;
    integer               model_head;
    integer               model_tail;
    integer               model_count;
    integer               random_seed;
    integer               writes_accepted;
    integer               reads_accepted;

    fifo #(
        .DATA_WIDTH         (DATA_WIDTH),
        .ADDR_WIDTH         (ADDR_WIDTH),
        .ALMOST_FULL_MARGIN (ALMOST_FULL_MARGIN),
        .ALMOST_EMPTY_MARGIN(ALMOST_EMPTY_MARGIN)
    ) dut (
        .wr_clk      (wr_clk),
        .wr_rst      (wr_rst),
        .wr_en       (wr_en),
        .wr_data     (wr_data),
        .wr_ptr      (wr_ptr),
        .wr_count    (wr_count),
        .wr_ack      (wr_ack),
        .overflow    (overflow),
        .full        (full),
        .almost_full (almost_full),
        .rd_clk      (rd_clk),
        .rd_rst      (rd_rst),
        .rd_en       (rd_en),
        .rd_data     (rd_data),
        .rd_ptr      (rd_ptr),
        .rd_count    (rd_count),
        .rd_valid    (rd_valid),
        .underflow   (underflow),
        .empty       (empty),
        .almost_empty(almost_empty)
    );

    always #4.0 wr_clk = ~wr_clk;
    always #6.5 rd_clk = ~rd_clk;

    task raise_error;
        input [8*96-1:0] message;
        begin
            $display("ERROR: %s at time %0t", message, $time);
            errors = errors + 1;
        end
    endtask

    task wait_wr_cycles;
        input integer cycles;
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(posedge wr_clk);
            end
            #1;
        end
    endtask

    task wait_rd_cycles;
        input integer cycles;
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(posedge rd_clk);
            end
            #1;
        end
    endtask

    task reset_model;
        begin
            model_head       = 0;
            model_tail       = 0;
            model_count      = 0;
            writes_accepted  = 0;
            reads_accepted   = 0;
            random_word      = {DATA_WIDTH{1'b0}};
        end
    endtask

    task check_status;
        input integer exp_wr_count;
        input integer exp_rd_count;
        input         exp_full;
        input         exp_empty;
        input         exp_almost_full;
        input         exp_almost_empty;
        input [8*40-1:0] tag;
        begin
            if (wr_count !== exp_wr_count) begin
                $display("ERROR: %s wr_count expected %0d got %0d at time %0t", tag, exp_wr_count, wr_count, $time);
                errors = errors + 1;
            end

            if (rd_count !== exp_rd_count) begin
                $display("ERROR: %s rd_count expected %0d got %0d at time %0t", tag, exp_rd_count, rd_count, $time);
                errors = errors + 1;
            end

            if (full !== exp_full) begin
                $display("ERROR: %s full expected %0b got %0b at time %0t", tag, exp_full, full, $time);
                errors = errors + 1;
            end

            if (empty !== exp_empty) begin
                $display("ERROR: %s empty expected %0b got %0b at time %0t", tag, exp_empty, empty, $time);
                errors = errors + 1;
            end

            if (almost_full !== exp_almost_full) begin
                $display("ERROR: %s almost_full expected %0b got %0b at time %0t", tag, exp_almost_full, almost_full, $time);
                errors = errors + 1;
            end

            if (almost_empty !== exp_almost_empty) begin
                $display("ERROR: %s almost_empty expected %0b got %0b at time %0t", tag, exp_almost_empty, almost_empty, $time);
                errors = errors + 1;
            end
        end
    endtask

    task apply_global_reset;
        begin
            wr_en   = 1'b0;
            rd_en   = 1'b0;
            wr_data = {DATA_WIDTH{1'b0}};
            wr_rst  = 1'b1;
            rd_rst  = 1'b1;
            reset_model;

            repeat (2) @(posedge wr_clk);
            repeat (2) @(posedge rd_clk);

            wr_rst = 1'b0;
            rd_rst = 1'b0;

            wait_wr_cycles(3);
            wait_rd_cycles(3);
        end
    endtask

    task write_word_check;
        input [DATA_WIDTH-1:0] data;
        begin
            wait (full === 1'b0);

            @(negedge wr_clk);
            wr_data = data;
            wr_en   = 1'b1;

            @(posedge wr_clk);
            #1;

            if (wr_ack !== 1'b1) begin
                raise_error("wr_ack was low on an accepted write");
            end

            if (overflow !== 1'b0) begin
                raise_error("overflow asserted on an accepted write");
            end

            @(negedge wr_clk);
            wr_en = 1'b0;
        end
    endtask

    task read_word_check;
        input [DATA_WIDTH-1:0] expected;
        begin
            wait (empty === 1'b0);

            @(negedge rd_clk);
            rd_en = 1'b1;

            @(posedge rd_clk);
            #1;

            if (rd_valid !== 1'b1) begin
                raise_error("rd_valid was low on an accepted read");
            end

            if (underflow !== 1'b0) begin
                raise_error("underflow asserted on an accepted read");
            end

            if (rd_data !== expected) begin
                $display("ERROR: read data mismatch expected %0h got %0h at time %0t", expected, rd_data, $time);
                errors = errors + 1;
            end

            @(negedge rd_clk);
            rd_en = 1'b0;
        end
    endtask

    task expect_overflow;
        input [DATA_WIDTH-1:0] data;
        begin
            @(negedge wr_clk);
            wr_data = data;
            wr_en   = 1'b1;

            @(posedge wr_clk);
            #1;

            if (wr_ack !== 1'b0) begin
                raise_error("blocked write incorrectly asserted wr_ack");
            end

            if (overflow !== 1'b1) begin
                raise_error("overflow did not pulse on blocked write");
            end

            @(negedge wr_clk);
            wr_en = 1'b0;

            @(posedge wr_clk);
            #1;
            if (overflow !== 1'b0) begin
                raise_error("overflow did not clear after one cycle");
            end
        end
    endtask

    task expect_underflow;
        begin
            @(negedge rd_clk);
            rd_en = 1'b1;

            @(posedge rd_clk);
            #1;

            if (rd_valid !== 1'b0) begin
                raise_error("blocked read incorrectly asserted rd_valid");
            end

            if (underflow !== 1'b1) begin
                raise_error("underflow did not pulse on blocked read");
            end

            @(negedge rd_clk);
            rd_en = 1'b0;

            @(posedge rd_clk);
            #1;
            if (underflow !== 1'b0) begin
                raise_error("underflow did not clear after one cycle");
            end
        end
    endtask

    task drive_random_writes;
        input integer cycles;
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(negedge wr_clk);
                wr_en   = (($random(random_seed) & 32'h3) != 0);
                wr_data = random_word;

                if (wr_en) begin
                    random_word = random_word + 1'b1;
                end
            end

            @(negedge wr_clk);
            wr_en = 1'b0;
        end
    endtask

    task drive_random_reads;
        input integer cycles;
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(negedge rd_clk);
                rd_en = (($random(random_seed) & 32'h7) < 5);
            end

            @(negedge rd_clk);
            rd_en = 1'b0;
        end
    endtask

    always @(posedge wr_clk) begin
        #1;
        if (random_phase_active && wr_ack) begin
            if (model_count >= DEPTH) begin
                raise_error("scoreboard overflow on accepted write");
            end else begin
                model_mem[model_tail] = wr_data;

                if (model_tail == MODEL_DEPTH - 1) begin
                    model_tail = 0;
                end else begin
                    model_tail = model_tail + 1;
                end

                model_count     = model_count + 1;
                writes_accepted = writes_accepted + 1;
            end
        end
    end

    always @(posedge rd_clk) begin
        #1;
        if (random_phase_active && rd_valid) begin
            if (model_count == 0) begin
                raise_error("scoreboard underflow on accepted read");
            end else begin
                if (rd_data !== model_mem[model_head]) begin
                    $display("ERROR: random read mismatch expected %0h got %0h at time %0t", model_mem[model_head], rd_data, $time);
                    errors = errors + 1;
                end

                if (model_head == MODEL_DEPTH - 1) begin
                    model_head = 0;
                end else begin
                    model_head = model_head + 1;
                end

                model_count    = model_count - 1;
                reads_accepted = reads_accepted + 1;
            end
        end
    end

    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars(0, tb_fifo);

        wr_clk            = 1'b0;
        rd_clk            = 1'b0;
        wr_rst            = 1'b0;
        rd_rst            = 1'b0;
        wr_en             = 1'b0;
        rd_en             = 1'b0;
        wr_data           = {DATA_WIDTH{1'b0}};
        random_phase_active = 1'b0;
        errors            = 0;
        random_seed       = 32'h1A2B3C4D;

        apply_global_reset;

        if (wr_ack !== 1'b0) begin
            raise_error("wr_ack was not low after reset");
        end
        if (rd_valid !== 1'b0) begin
            raise_error("rd_valid was not low after reset");
        end
        if (overflow !== 1'b0) begin
            raise_error("overflow was not low after reset");
        end
        if (underflow !== 1'b0) begin
            raise_error("underflow was not low after reset");
        end

        check_status(0, 0, 1'b0, 1'b1, 1'b0, 1'b1, "after_reset");

        $display("Phase 1: fill FIFO and verify full/overflow behavior");
        for (i = 0; i < DEPTH; i = i + 1) begin
            write_word_check(16'h1000 + i);
        end

        wait_wr_cycles(2);
        wait_rd_cycles(3);
        check_status(DEPTH, DEPTH, 1'b1, 1'b0, 1'b1, 1'b0, "after_fill");

        if (wr_ptr !== {ADDR_WIDTH{1'b0}}) begin
            $display("ERROR: wr_ptr did not wrap after filling FIFO, got %0d at time %0t", wr_ptr, $time);
            errors = errors + 1;
        end

        expect_overflow(16'hDEAD);
        wait_wr_cycles(1);
        if (full !== 1'b1) begin
            raise_error("full deasserted after blocked write");
        end

        $display("Phase 2: drain FIFO and verify empty/underflow behavior");
        for (i = 0; i < DEPTH; i = i + 1) begin
            read_word_check(16'h1000 + i);
        end

        wait_rd_cycles(2);
        wait_wr_cycles(3);
        check_status(0, 0, 1'b0, 1'b1, 1'b0, 1'b1, "after_drain");

        if (rd_ptr !== {ADDR_WIDTH{1'b0}}) begin
            $display("ERROR: rd_ptr did not wrap after draining FIFO, got %0d at time %0t", rd_ptr, $time);
            errors = errors + 1;
        end

        expect_underflow;

        $display("Phase 3: reset recovery while FIFO contains data");
        for (i = 0; i < 6; i = i + 1) begin
            write_word_check(16'h2000 + i);
        end

        wait_wr_cycles(2);
        wait_rd_cycles(3);
        check_status(6, 6, 1'b0, 1'b0, 1'b0, 1'b0, "before_mid_reset");

        apply_global_reset;
        check_status(0, 0, 1'b0, 1'b1, 1'b0, 1'b1, "after_mid_reset");

        $display("Phase 4: randomized asynchronous traffic with scoreboard");
        random_phase_active = 1'b1;

        fork
            drive_random_writes(RANDOM_WR_CYCLES);
            drive_random_reads(RANDOM_RD_CYCLES);
        join

        random_phase_active = 1'b0;

        $display("Random phase accepted %0d writes and %0d reads", writes_accepted, reads_accepted);

        while (model_count > 0) begin
            read_word_check(model_mem[model_head]);

            if (model_head == MODEL_DEPTH - 1) begin
                model_head = 0;
            end else begin
                model_head = model_head + 1;
            end

            model_count = model_count - 1;
        end

        wait_rd_cycles(2);
        wait_wr_cycles(3);
        check_status(0, 0, 1'b0, 1'b1, 1'b0, 1'b1, "final_state");

        if (errors == 0) begin
            $display("TEST PASSED: parameterized asynchronous FIFO behaved correctly.");
        end else begin
            $display("TEST FAILED: %0d error(s) found.", errors);
        end

        $finish;
    end
endmodule
