`timescale 1ns / 1ps

module stopwatch_control_unit (
    input clk,
    input rst,
    input i_mode,
    input i_clear,
    input i_run_stop,
    input      i_btnu,     //재설계하기, watch랑 stopwatch의 버튼 용도가 다르니까 control unit 2개로 나누던가 하기
    input       [2:0] sw,
    output o_mode,
    output reg o_clear,
    output reg o_run_stop,
    output  [2:0] o_led //상황에 맞춰서 해보기
);

    //state
    parameter [1:0] STOP = 0, RUN = 1, CLEAR = 2, MODE = 3;
    //관리할 레지스터
    reg [1:0] c_state, n_state;
    //mode 저장할 레지스터
    reg mode_reg, mode_next;

    assign o_mode = mode_reg;

    assign o_led = sw;

    //state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= STOP;
            mode_reg <= 1'b0; //rst할 때 항상 up_count로 시작하겠다는 의미
        end else begin
            c_state  <= n_state;
            mode_reg <= mode_next;  //mode memory(레지스터하기 위해서)
        end
    end

    //next, output CL
    always @(*) begin
        //초기화 먼저
        n_state = c_state;
        mode_next = mode_reg;  //현재 상태를 유지하겠다는 의미
        o_clear = 1'b0;
        o_run_stop = 1'b0;

        case (c_state)
            STOP: begin
                o_run_stop = 1'b0;
                o_clear = 1'b0;
                if(i_run_stop) begin //동시에 버튼이 들어오면 우선순위에 따라 동작(교수님은 run_stop 먼저)
                    n_state = RUN;
                end else if (i_clear) begin
                    n_state = CLEAR;
                end else if (i_mode) begin
                    n_state = MODE;
                end else n_state = c_state;
            end

            RUN: begin
                o_run_stop = 1'b1;
                if (i_run_stop) begin
                    n_state = STOP;
                end
            end

            CLEAR: begin
                o_clear = 1'b1; //한 싸이클 동안 유지, 다음 싸이클에 다시 STOP으로 가면서 clear가 0이 되기 때문
                n_state = STOP;  //next clk에 움직임
            end

            MODE: begin
                //o_mode = ~o_mode; 이렇게 하면 위에 0으로 초기화했기 때문에 항상 1이 됨, 그래서 방법을 다르게 사용해야 함!
                mode_next = ~mode_reg; //현재 상태인 mode_reg를 반전시키라는 의미
                n_state = STOP;
            end

        endcase
    end

endmodule
