`timescale 1ns/1ps
//----------------------------------------------------------------------------
// Traffic Light Controller (Main road / Side road intersection)
//  - Moore FSM, 4 states
//  - Main road is green by default
//  - Side road gets green only when car_side sensor is asserted
//    (and main road has completed its minimum green time)
//  - Times are in clock cycles (parameters) so simulation stays short.
//    For real hardware, put a clock divider in front or raise the values.
//
//  Light encoding: {RED, YELLOW, GREEN}
//----------------------------------------------------------------------------
module traffic_light_controller #(
    parameter T_MAIN_GREEN = 10,   // minimum main-road green time (cycles)
    parameter T_YELLOW     = 3,    // yellow time for both roads   (cycles)
    parameter T_SIDE_GREEN = 6     // maximum side-road green time (cycles)
)(
    input  wire       clk,
    input  wire       rst_n,       // active-low synchronous reset
    input  wire       car_side,    // vehicle sensor on side road
    output reg  [2:0] main_light,  // {R,Y,G}
    output reg  [2:0] side_light   // {R,Y,G}
);

    // State encoding
    localparam [1:0] S_MAIN_G = 2'd0,   // main green , side red
                     S_MAIN_Y = 2'd1,   // main yellow, side red
                     S_SIDE_G = 2'd2,   // main red   , side green
                     S_SIDE_Y = 2'd3;   // main red   , side yellow

    // Light patterns
    localparam [2:0] RED    = 3'b100,
                     YELLOW = 3'b010,
                     GREEN  = 3'b001;

    reg [1:0] state, next_state;
    reg [7:0] timer;                    // counts cycles spent in current state

    // ---------------- State register ----------------
    always @(posedge clk) begin
        if (!rst_n) state <= S_MAIN_G;
        else        state <= next_state;
    end

    // ---------------- Timer ----------------
    // Restarts at 0 whenever the state changes
    always @(posedge clk) begin
        if (!rst_n)                   timer <= 8'd0;
        else if (state != next_state) timer <= 8'd0;
        else                          timer <= timer + 8'd1;
    end

    // ---------------- Next-state logic ----------------
    always @(*) begin
        next_state = state;
        case (state)
            S_MAIN_G: if (timer >= T_MAIN_GREEN-1 && car_side)
                          next_state = S_MAIN_Y;

            S_MAIN_Y: if (timer >= T_YELLOW-1)
                          next_state = S_SIDE_G;

            // leave side green when max time reached OR no more cars waiting
            S_SIDE_G: if (timer >= T_SIDE_GREEN-1 || !car_side)
                          next_state = S_SIDE_Y;

            S_SIDE_Y: if (timer >= T_YELLOW-1)
                          next_state = S_MAIN_G;

            default : next_state = S_MAIN_G;
        endcase
    end

    // ---------------- Output logic (Moore) ----------------
    always @(*) begin
        case (state)
            S_MAIN_G: begin main_light = GREEN;  side_light = RED;    end
            S_MAIN_Y: begin main_light = YELLOW; side_light = RED;    end
            S_SIDE_G: begin main_light = RED;    side_light = GREEN;  end
            S_SIDE_Y: begin main_light = RED;    side_light = YELLOW; end
            default : begin main_light = RED;    side_light = RED;    end
        endcase
    end

endmodule
