`timescale 1ns/1ps
//----------------------------------------------------------------------------
// Self-checking testbench for traffic_light_controller
// Checks:
//   1. Safety  : both roads are never green/yellow at the same time
//   2. Reset   : after reset, main = GREEN, side = RED
//   3. Sensor  : with no side car, main stays green
//   4. Sequence: main G -> main Y -> side G -> side Y -> main G
//   5. Timing  : yellow lasts exactly T_YELLOW cycles
//----------------------------------------------------------------------------
module tb_traffic_light_controller;

    parameter T_MAIN_GREEN = 10;
    parameter T_YELLOW     = 3;
    parameter T_SIDE_GREEN = 6;

    localparam [2:0] RED = 3'b100, YELLOW = 3'b010, GREEN = 3'b001;

    reg        clk;
    reg        rst_n;
    reg        car_side;
    wire [2:0] main_light, side_light;

    integer errors;
    integer yellow_cnt;

    // DUT
    traffic_light_controller #(
        .T_MAIN_GREEN(T_MAIN_GREEN),
        .T_YELLOW    (T_YELLOW),
        .T_SIDE_GREEN(T_SIDE_GREEN)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .car_side  (car_side),
        .main_light(main_light),
        .side_light(side_light)
    );

    // 10 ns clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---------- Safety checker: never both roads "go" ----------
    always @(posedge clk) begin
        if (rst_n) begin
            if ((main_light != RED) && (side_light != RED)) begin
                $display("[%0t] ERROR: both roads non-red! main=%b side=%b",
                          $time, main_light, side_light);
                errors = errors + 1;
            end
        end
    end

    // ---------- Yellow duration checker (main road) ----------
    always @(posedge clk) begin
        if (!rst_n) yellow_cnt <= 0;
        else if (main_light == YELLOW) yellow_cnt <= yellow_cnt + 1;
        else begin
            if (yellow_cnt != 0 && yellow_cnt != T_YELLOW) begin
                $display("[%0t] ERROR: main yellow lasted %0d cycles (expected %0d)",
                          $time, yellow_cnt, T_YELLOW);
                errors = errors + 1;
            end
            yellow_cnt <= 0;
        end
    end

    // ---------- Console monitor ----------
    initial
        $monitor("[%0t] rst_n=%b car_side=%b | main=%b side=%b",
                  $time, rst_n, car_side, main_light, side_light);

    // ---------- Stimulus ----------
    initial begin
        errors   = 0;
        rst_n    = 1'b0;
        car_side = 1'b0;

        // Reset
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk); #1;
        if (main_light !== GREEN || side_light !== RED) begin
            $display("ERROR: wrong state after reset");
            errors = errors + 1;
        end

        // Test 1: no side car -> main must stay green
        repeat (30) @(posedge clk);
        #1;
        if (main_light !== GREEN) begin
            $display("ERROR: main left green with no side car");
            errors = errors + 1;
        end

        // Test 2: side car arrives and stays -> full cycle
        car_side = 1'b1;
        repeat (60) @(posedge clk);

        // Test 3: side car leaves early -> side green should end early
 // Test 3: side car leaves DURING side green -> should exit early
car_side = 1'b1;
wait (side_light == GREEN);       // side green has started
repeat (2) @(posedge clk);        // stay 2 cycles into it
car_side = 1'b0;                  // car leaves (well before 6 cycles)
@(posedge clk); #1;
if (side_light !== YELLOW) begin
    $display("ERROR: side green did not exit early");
    errors = errors + 1;
end
repeat (20) @(posedge clk);       

        // Test 4: short pulse of car_side
        car_side = 1'b1;
        repeat (15) @(posedge clk);
        car_side = 1'b0;
        repeat (30) @(posedge clk);

        // Test 5: reset while side road is green
car_side = 1'b1;
wait (side_light == GREEN);
repeat (2) @(posedge clk);
rst_n = 1'b0;
@(posedge clk); #1;
if (main_light !== GREEN || side_light !== RED) begin
    $display("ERROR: reset did not force main green from side-green state");
    errors = errors + 1;
end
repeat (2) @(posedge clk);
rst_n = 1'b1;
repeat (40) @(posedge clk);

        // Result
        if (errors == 0) $display("\n*** TEST PASSED: no errors ***\n");
        else             $display("\n*** TEST FAILED: %0d errors ***\n", errors);
        $stop;
    end

endmodule
