`timescale 1ns / 1ps

module stopwatch_datapath #(
    parameter MSEC_WIDTH = 7,
    SEC_WIDTH = 6,
    MIN_WIDTH = 6,
    HOUR_WIDTH = 5
) (

    input                     clk,
    input                     rst,
    input                     i_runstop,
    input                     i_clear,
    input                     i_mode,
    output [MSEC_WIDTH - 1:0] msec,
    output [ SEC_WIDTH - 1:0] sec,
    output [ MIN_WIDTH - 1:0] min,
    output [HOUR_WIDTH - 1:0] hour
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    //hour
    tick_counter #(
        .TIMES      (24), //이름으로 parameter 연결은 앞에 점 두고 괄호로 값 넣기
        .BIT_WIDTH(HOUR_WIDTH)
    ) U_HOUR_TICK_COUNTER (
        .clk         (clk),
        .rst         (rst),
        .i_tick      (w_hour_tick),  //from min o_tick
        .i_clear     (i_clear),
        .i_mode      (i_mode),
        .time_counter(hour),
        .o_tick      ()
    );
    //min
    tick_counter #(
        .TIMES      (60), //이름으로 parameter 연결은 앞에 점 두고 괄호로 값 넣기
        .BIT_WIDTH(MIN_WIDTH)
    ) U_MIN_TICK_COUNTER (
        .clk         (clk),
        .rst         (rst),
        .i_tick      (w_min_tick),
        .i_clear     (i_clear),
        .i_mode      (i_mode),
        .time_counter(min),
        .o_tick      (w_hour_tick)  //to hour o_tick
    );
    //sec
    tick_counter #(
        .TIMES(60), //이름으로 parameter 연결은 앞에 점 두고 괄호로 값 넣기
        .BIT_WIDTH(SEC_WIDTH)
    ) U_SEC_TICK_COUNTER (
        .clk         (clk),
        .rst         (rst),
        .i_tick      (w_sec_tick),  //from mesc o_tick
        .i_clear     (i_clear),
        .i_mode      (i_mode),
        .time_counter(sec),
        .o_tick      (w_min_tick)
    );
    //msec
    tick_counter #(
        .TIMES(100), //이름으로 parameter 연결은 앞에 점 두고 괄호로 값 넣기
        .BIT_WIDTH(MSEC_WIDTH)
    ) U_MSEC_TICK_COUNTER (
        .clk         (clk),
        .rst         (rst),
        .i_tick      (w_tick_100hz),
        .i_clear     (i_clear),
        .i_mode      (i_mode),
        .time_counter(msec),
        .o_tick      (w_sec_tick)     //to sec tick counter
    );

    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk(clk),
        .rst(rst),
        .i_runstop(i_runstop),
        .i_clear(i_clear),
        .o_tick_100hz(w_tick_100hz)  //출력으로 내보내야 하니까 reg 타입
    );
endmodule

//tick gen 100hz
module tick_gen_100hz (
    input      clk,
    input      rst,
    input      i_runstop,
    input      i_clear,
    output reg o_tick_100hz  //출력으로 내보내야 하니까 reg 타입
);

    //100 Hz Counter number * 1000 for simulation
    parameter F_COUNT = 100_000_000 / 100_000;  //100Hz counter number
    reg [$clog2(F_COUNT)-1 : 0] counter_reg;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg  <= 0;  //bit수 모를 때는 0으로 처리해도 됨
            o_tick_100hz <= 1'b0;
        end else begin
            if (i_runstop) begin
                counter_reg <= counter_reg + 1;
                //o_tick_100hz <= 1'b0; 여기에 있으면 다중 처리하게 되므로 X, 합성기가 보고 최적화시킬 수도 있음

                if (counter_reg == F_COUNT - 1) begin
                    counter_reg  <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end else if (i_clear) begin
                counter_reg  <= 0;
                o_tick_100hz <= 1'b0;
            end
        end

    end

endmodule

module tick_counter #(
    parameter TIMES = 100,  //TIMES는 count 값으로 활용
    BIT_WIDTH = 7
) (
    input                          clk,
    input                          rst,
    input                          i_tick,
    input                          i_clear,
    input                          i_mode,
    output     [BIT_WIDTH - 1 : 0] time_counter,
    output reg                     o_tick
);

    //counter register
    reg [BIT_WIDTH-1:0] counter_reg, counter_next;
    assign time_counter = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_next; //상승 에지 발생할 때마다 업데이트
        end

    end
    //next counter 다음 값 결정하는 CL : blocking 연산(=)
    always @(*) begin
        counter_next = counter_reg;
        o_tick = 1'b0;
        if (i_tick) begin
            //output : next(current_next), input : current(counter_reg)
            if (i_mode) begin
                counter_next = counter_reg - 1;
                if (counter_reg == 0) begin
                    o_tick = 1'b1;
                    counter_next = TIMES - 1;
                end else begin
                    o_tick = 1'b0;
                end
            end else begin
                //up count
                counter_next = counter_reg + 1;
                if (counter_reg == TIMES - 1) begin  //TIMES까지만 세고 
                    o_tick = 1'b1;
                    counter_next = 0;
                end else begin  //오동작할 수도 있어서 넣음
                    o_tick = 1'b0;
                end
            end
        end else if (i_clear) begin
            counter_next = 0;
            o_tick       = 1'b0;
        end
    end
endmodule
