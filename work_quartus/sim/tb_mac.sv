// tb_mac.sv - self-checking testbench for mac.sv (Milestone 3)
// The testbench keeps its own copy of the expected sum ("model") as a
// 32-bit signed int, computed with plain integer math, and compares it to
// the DUT after every clock. It prints PASS/FAIL per test and a total.

`timescale 1ns/1ps
module tb_mac;

    logic               clk = 0;
    logic               rst_n, load, en;
    logic signed [31:0] bias;
    logic signed [7:0]  x, w;
    logic signed [31:0] acc;

    int model;           // expected value of acc
    int errors = 0;      // mismatches inside the current test
    int passed = 0, failed = 0;

    mac dut (.*);

    always #10 clk = ~clk;   // 50 MHz, like CLOCK_50

    // Compare DUT against the model.
    task automatic check(input string what);
        if (acc !== model) begin
            $display("    mismatch (%s): acc = %0d, expected %0d", what, acc, model);
            errors++;
        end
    endtask

    // Print the result of a test and reset the error counter.
    task automatic report(input string name);
        if (errors == 0) begin $display("PASS  %s", name); passed++; end
        else             begin $display("FAIL  %s", name); failed++; end
        errors = 0;
    endtask

    // Inputs change on the falling edge, the DUT samples on the rising edge,
    // and we check right after the rising edge. This avoids races.
    task automatic do_load(input int b);
        @(negedge clk); load = 1; en = 0; bias = b;
        @(posedge clk); #1;
        model = b;
        check("load");
        load = 0;
    endtask

    task automatic do_mac(input int xi, input int wi);
        @(negedge clk); load = 0; en = 1; x = xi; w = wi;
        @(posedge clk); #1;
        model = model + xi * wi;
        check($sformatf("%0d * %0d", xi, wi));
        en = 0;
    endtask

    // One product from a zero bias: acc should equal exactly a*b.
    task automatic one_product(input string name, input int a, input int b);
        do_load(0);
        do_mac(a, b);
        report(name);
    endtask

    int sum;

    initial begin
        rst_n = 0; load = 0; en = 0; bias = 0; x = 0; w = 0;
        repeat (2) @(posedge clk);
        #1 model = 0; check("reset"); report("reset clears acc");
        @(negedge clk) rst_n = 1;

        // 1. Sign combinations
        one_product("positive x positive (5 * 7 = 35)",       5,    7);
        one_product("positive x negative (5 * -7 = -35)",     5,   -7);
        one_product("negative x negative (-5 * -7 = 35)",    -5,   -7);

        // 2. Extremes
        one_product("127 * 127 = 16129",                    127,  127);
        one_product("-127 * 127 = -16129",                 -127,  127);
        one_product("-128 * -128 = 16384",                 -128, -128);

        // 3. 64 accumulations from a negative bias, with mixed signs
        do_load(-5000);
        for (int i = 0; i < 64; i++)
            do_mac((i * 37) % 256 - 128, (i * 91 + 13) % 256 - 128);
        // independent recomputation of the same sum
        sum = -5000;
        for (int i = 0; i < 64; i++)
            sum += ((i * 37) % 256 - 128) * ((i * 91 + 13) % 256 - 128);
        if (sum !== acc) begin $display("    final sum %0d, expected %0d", acc, sum); errors++; end
        report($sformatf("64 MACs from bias -5000 (final = %0d)", sum));

        // 4. Worst case: 64 x (-128 * -128) on top of the largest bias
        do_load(32'sh7FFF);
        repeat (64) do_mac(-128, -128);
        report($sformatf("64 x (-128*-128) + 32767 = %0d, no overflow", model));

        // 5. Reset in the middle of a sum
        do_load(100);
        do_mac(10, 10); do_mac(-3, 50);
        @(negedge clk) rst_n = 0;
        #1 model = 0; check("async reset");      // async: clears before any edge
        @(posedge clk); #1 check("held in reset");
        @(negedge clk) rst_n = 1;
        do_mac(2, 3);                            // keeps working after reset
        report("reset in the middle of a sum");

        // 6. load and en together: load must win
        do_load(0); do_mac(10, 10);
        @(negedge clk); load = 1; en = 1; bias = -42; x = 100; w = 100;
        @(posedge clk); #1 model = -42; check("load beats en");
        load = 0; en = 0;
        report("load and en high together -> load wins");

        // 7. en low: acc holds
        do_load(77);
        @(negedge clk); en = 0; x = 99; w = 99;
        repeat (3) @(posedge clk);
        #1 check("hold");
        report("en low -> acc holds");

        // 8. Pixel-style input like layer 1 (x = 0 or 1)
        do_load(-10);
        do_mac(1, -37); do_mac(0, 120); do_mac(1, 90); do_mac(0, -128);
        report("pixel inputs 0/1 (-10 - 37 + 90 = 43)");

        $display("--------------------------------");
        $display("%0d passed, %0d failed", passed, failed);
        if (failed == 0) $display("ALL TESTS PASSED");
        $finish;
    end

endmodule
