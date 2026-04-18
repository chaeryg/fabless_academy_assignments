`timescale 1ns / 1ps

module watch_control_unit(
    input clk,
    input rst,
    input i_up, 
    input i_down,
    input i_lshift,
    input i_rshift,
    input sw,
    output o_up,
    output o_down,
    output o_set,
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
                RUN      :                    n_state = MSEC_SET;
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
