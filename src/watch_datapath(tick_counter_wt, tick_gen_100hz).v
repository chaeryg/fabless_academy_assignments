`timescale 1ns / 1ps


module watch_datapath #(
    MSEC_WIDTH = 7,  
    SEC_WIDTH  = 6, 
    MIN_WIDTH  = 6, 
    HOUR_WIDTH = 5)(
    input                    clk,
    input                    rst,
    input                    i_run,
    input                    i_up,
    input                    i_down,
    input                    i_set,
    input             [1:0]  i_sel,
    output [MSEC_WIDTH-1:0]  msec,
    output [ SEC_WIDTH-1:0]  sec,
    output [ MIN_WIDTH-1:0]  min,
    output [HOUR_WIDTH-1:0]  hour
    );

    wire w_tick_100hz;
    wire w_tick_sec, w_tick_min, w_tick_hour;

    // i_up 신호 분배
    wire up_hour = (i_sel == 2'd3) ? i_up : 1'b0;
    wire up_min  = (i_sel == 2'd2) ? i_up : 1'b0;
    wire up_sec  = (i_sel == 2'd1) ? i_up : 1'b0;
    wire up_msec = (i_sel == 2'd0) ? i_up : 1'b0;

    // i_down 신호 분배 
    wire dn_hour = (i_sel == 2'd3) ? i_down : 1'b0;
    wire dn_min  = (i_sel == 2'd2) ? i_down : 1'b0;
    wire dn_sec  = (i_sel == 2'd1) ? i_down : 1'b0;
    wire dn_msec = (i_sel == 2'd0) ? i_down : 1'b0;


    tick_counter_wt #(
    .TIMES    (100), 
    .BIT_WIDTH(MSEC_WIDTH),
    .INITIAL_VALUE(0)) U_MSEC_WT(
    .clk          (clk),
    .rst          (rst),
    .i_tick       (w_tick_100hz),
    .i_up         (up_msec),
    .i_down       (dn_msec),
    .i_set        (i_set),
    .time_counter (msec),
    .o_tick       (w_tick_sec)
    );

    tick_counter_wt #(
    .TIMES    (60), 
    .BIT_WIDTH(SEC_WIDTH),
    .INITIAL_VALUE(0)) U_SEC_WT(
    .clk          (clk),
    .rst          (rst),
    .i_tick       (w_tick_sec),
    .i_up         (up_sec),
    .i_down       (dn_sec),
    .i_set        (i_set),
    .time_counter (sec),
    .o_tick       (w_tick_min)
    );

    tick_counter_wt #(
    .TIMES    (60), 
    .BIT_WIDTH(SEC_WIDTH),
    .INITIAL_VALUE(0)) U_MIN_WT(
    .clk          (clk),
    .rst          (rst),
    .i_tick       (w_tick_min),
    .i_up         (up_min),
    .i_down       (dn_min),
    .i_set        (i_set),
    .time_counter (min),
    .o_tick       (w_tick_hour)
    );

    tick_counter_wt #(
    .TIMES    (24), 
    .BIT_WIDTH(SEC_WIDTH),
    .INITIAL_VALUE(12)) U_HOUR_WT(
    .clk          (clk),
    .rst          (rst),
    .i_tick       (w_tick_hour),
    .i_up         (up_hour),
    .i_down       (dn_hour),
    .i_set        (i_set),
    .time_counter (hour),
    .o_tick       ()
    );

    tick_gen_100hz_wt U_TICK_GEN (
    .clk(clk),
    .rst(rst),
    .i_set(i_set),
    .o_tick_100hz(w_tick_100hz)      
    );

endmodule



module tick_counter_wt #(
    TIMES     = 100, 
    BIT_WIDTH = 7,
    INITIAL_VALUE = 0)(
    input                  clk,
    input                  rst,
    input                  i_tick,
    input                  i_up,
    input                  i_down,
    input                  i_set,
    output [BIT_WIDTH-1:0] time_counter,
    output reg             o_tick
    );

    //counter register
    reg [BIT_WIDTH-1:0] counter_reg, counter_next;
    assign time_counter = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= INITIAL_VALUE;
        end else begin
            counter_reg <= counter_next;
        end
    end

    // next count
    always @(*) begin
        counter_next = counter_reg;
        o_tick       = 1'b0;
        if (i_set) begin
            if(i_up) begin                      counter_next = counter_reg + 1;
                if (counter_reg == (TIMES - 1)) counter_next = 0;
            end else if (i_down) begin          counter_next = counter_reg - 1;
                if (counter_reg == 0          ) counter_next = TIMES - 1;
            end else                            counter_next = counter_reg;

        end else if (i_tick) begin
            counter_next = counter_reg + 1; 
            if (counter_reg == (TIMES - 1)) begin
                counter_next = 0;
                o_tick       = 1'b1;
            end else begin
                o_tick       = 1'b0;
            end
        end
        
    end

endmodule



module tick_gen_100hz_wt (
    input      clk,
    input      rst,
    input      i_set,
    output reg o_tick_100hz      
    );

    reg [$clog2(100_000_000/100)-1 : 0] counter_reg;  

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg  <= 20'd0;
            o_tick_100hz <= 1'b0;  
        end else begin
            if (!i_set) begin
                counter_reg  <= counter_reg + 1;
                o_tick_100hz <= 1'b0;
                if(counter_reg == (1_000_000 - 1)) begin 
                    counter_reg  <= 20'd0; 
                    o_tick_100hz <= 1'b1; 
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end else begin
                counter_reg  <= 0;
                o_tick_100hz <= 1'b0;
            end
        end
    end

endmodule
