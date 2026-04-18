`timescale 1ns / 1ps


module top_stopwatch_watch(
    input        clk,
    input        rst,
    input        btnR,
    input        btnL,
    input        btnU,
    input        btnD,
    input  [2:0] sw,
    output [2:0] led,
    output [3:0] fnd_com,
    output [7:0] fnd_data
    );

    parameter MSEC_WIDTH = 7, SEC_WIDTH = 6, MIN_WIDTH = 6, HOUR_WIDTH = 5;

    wire [MSEC_WIDTH-1:0] w_msec, w_msec_st, w_msec_wt;
    wire [SEC_WIDTH-1:0 ] w_sec, w_sec_st, w_sec_wt;
    wire [MIN_WIDTH-1:0 ] w_min, w_min_st, w_min_wt;
    wire [HOUR_WIDTH-1:0] w_hour, w_hour_st, w_hour_wt;

    wire w_runstop, w_clear, w_mode;
    wire w_btnR, w_btnL, w_btnD, w_btnU;
    wire w_up, w_down, w_set;
    wire [1:0] w_sel;

    button_debounce U_BTNR (
    .clk (clk),
    .rst (rst),
    .i_btn(btnR),
    .o_btn(w_btnR)
    );

    button_debounce U_BTNL (
    .clk (clk),
    .rst (rst),
    .i_btn(btnL),
    .o_btn(w_btnL)
    );

    button_debounce U_BTND (
    .clk (clk),
    .rst (rst),
    .i_btn(btnD),
    .o_btn(w_btnD)
    );

    button_debounce U_BTNU (
    .clk (clk),
    .rst (rst),
    .i_btn(btnU),
    .o_btn(w_btnU)
    );

    stopwatch_control_unit U_STOPWATCH_CONTROL (
    .clk (clk),
    .rst (rst),
    .i_mode (w_btnD),
    .i_clear (w_btnL),
    .i_run_stop(w_btnR),
    .o_mode (w_mode),
    .o_clear (w_clear),
    .o_run_stop(w_runstop)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
    .clk (clk),
    .rst (rst),
    .i_run_stop(w_runstop),
    .i_clear (w_clear),
    .i_mode (w_mode),
    .msec (w_msec_st),
    .sec (w_sec_st),
    .min (w_min_st),
    .hour (w_hour_st)
    );

    watch_control_unit U_WATCH_CONTROL(
    .clk(clk),
    .rst(rst),
    .i_up(w_btnU), 
    .i_down(w_btnD),
    .i_lshift(w_btnL),
    .i_rshift(w_btnR),
    .sw(sw[2]),
    .o_up(w_up),
    .o_down(w_down),
    .o_set(w_set),
    .o_sel(w_sel)
    );

    watch_datapath U_WATCH_DATAPATH (
    .clk(clk),
    .rst(rst),
    .i_up(w_up),
    .i_down(w_down),
    .i_set(w_set),
    .i_sel(w_sel),
    .msec(w_msec_wt),
    .sec(w_sec_wt),
    .min(w_min_wt),
    .hour(w_hour_wt)
    );

    assign w_msec  = (sw[0]) ? w_msec_st  : w_msec_wt;
    assign w_sec   = (sw[0]) ? w_sec_st   : w_sec_wt;
    assign w_min   = (sw[0]) ? w_min_st   : w_min_wt;
    assign w_hour  = (sw[0]) ? w_hour_st  : w_hour_wt;  

    assign led = sw;

    fnd_controller U_FND_CNTL (
    .clk (clk),
    .rst (rst),
    .sw (sw[1]), 
    .i_set(w_set),
    .i_sel(w_sel),
    .msec (w_msec),
    .sec (w_sec),
    .min (w_min),
    .hour (w_hour),
    .fnd_com (fnd_com),
    .fnd_data(fnd_data)
    );

endmodule


    
module stopwatch_control_unit (
    input clk,
    input rst,
    input i_mode,
    input i_clear,
    input i_run_stop, 
    output o_mode,
    output reg o_clear,
    output reg o_run_stop
    );

    //state
    parameter [1:0] STOP = 0, RUN = 1, CLEAR = 2, MODE = 3;

    //관리할 레지스터
    reg [1:0] c_state, n_state;

    //mode 저장할 레지스터
    reg mode_reg, mode_next;
    assign o_mode = mode_reg;

    //state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= STOP;
            mode_reg <= 1'b0; //rst할 때 항상 up_count로 시작
        end else begin
            c_state <= n_state;
            mode_reg <= mode_next; 
        end
    end

    //next, output CL
    always @(*) begin
        n_state = c_state;
        mode_next = mode_reg; //현재 상태를 유지하겠다는 의미
        o_clear = 1'b0;
        o_run_stop = 1'b0;

        case (c_state)
            STOP: begin
                    o_run_stop = 1'b0;
                    o_clear = 1'b0;
                    if      (i_run_stop) n_state = RUN;
                    else if (i_clear   ) n_state = CLEAR;
                    else if (i_mode    ) n_state = MODE;
                    else                 n_state = c_state;  end
            RUN:  begin
                    o_run_stop = 1'b1;
                    if      (i_run_stop) n_state = STOP;     end
            CLEAR: begin
                    o_clear = 1'b1; //한 싸이클 동안 유지
                    n_state = STOP;                          end
            MODE: begin
                    mode_next = ~mode_reg; //현재 상태인 mode_reg를 반전
                    n_state = STOP;                          end
        endcase
    end
    
endmodule



module watch_control_unit(
    input        clk,
    input        rst,
    input        i_up, 
    input        i_down,
    input        i_lshift,
    input        i_rshift,
    input        sw,
    output       o_up,
    output       o_down,
    output       o_set,
    output [1:0] o_sel
    );

    //state
    parameter [2:0] RUN = 0, MSEC_SET = 1, SEC_SET = 2, MIN_SET = 3, HOUR_SET = 4;

    reg [2:0] c_state, n_state;

    // 출력 신호 정의 (datapath로 전송)
    assign o_set  = (c_state != RUN);
    assign o_up   = (o_set) ? i_up   : 1'b0; // btnU -> i_up
    assign o_down = (o_set) ? i_down : 1'b0; // btnD -> i_down
    assign o_sel  = (c_state == MSEC_SET) ? 2'd0 :
                    (c_state == SEC_SET)  ? 2'd1 :
                    (c_state == MIN_SET)  ? 2'd2 :
                    (c_state == HOUR_SET) ? 2'd3 : 2'd0;

    always @(posedge clk or posedge rst) begin
        if (rst) c_state <= RUN;
        else     c_state <= n_state;
    end

    always @(*) begin
        n_state = c_state;      
        if (sw) begin
            case(c_state)
                RUN      :                    n_state = SEC_SET;
                MSEC_SET : if      (i_lshift) n_state = SEC_SET;
                           else if (i_rshift) n_state = HOUR_SET;
                           else               n_state = c_state;
                SEC_SET  : if      (i_lshift) n_state = MIN_SET;
                           else if (i_rshift) n_state = MSEC_SET;
                           else               n_state = c_state;
                MIN_SET  : if      (i_lshift) n_state = HOUR_SET;
                           else if (i_rshift) n_state = SEC_SET;
                           else               n_state = c_state;
                HOUR_SET : if      (i_lshift) n_state = MSEC_SET;
                           else if (i_rshift) n_state = MIN_SET;
                           else               n_state = c_state;
                default  :                    n_state = c_state;
            endcase
        end else begin
            n_state = RUN;
        end
    end

endmodule
