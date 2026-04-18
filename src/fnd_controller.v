`timescale 1ns / 1ps


module fnd_controller #(
    parameter MSEC_WIDTH = 7,
    SEC_WIDTH = 6,
    MIN_WIDTH = 6,
    HOUR_WIDTH = 5
) (
    input                     clk,
    input                     rst,
    input                     sw,       //sw[0], 0 : msec_sec, 1 : min_hour
    //추가
    input                     i_set, 
    input  [1:0]              i_sel,
    input  [MSEC_WIDTH - 1:0] msec,
    input  [ SEC_WIDTH - 1:0] sec,
    input  [ MIN_WIDTH - 1:0] min,
    input  [HOUR_WIDTH - 1:0] hour,
    output [             3:0] fnd_com,
    output [             7:0] fnd_data
);
    wire [3:0] w_out_mux, w_out_mux_msec_sec, w_out_mux_min_hour;
    wire [3:0] w_msec_digit_1, w_msec_digit_10;
    wire [3:0] w_sec_digit_1, w_sec_digit_10;
    wire [3:0] w_min_digit_1, w_min_digit_10;
    wire [3:0] w_hour_digit_1, w_hour_digit_10;
    wire [2:0] w_digit_sel;
    wire       w_1khz;
    wire       w_blink;

    //digit split
    digit_splitter #(
        .BIT_WIDTH(MSEC_WIDTH)
    ) U_MSEC_DS (
        .digit_in(msec),
        .digit_1 (w_msec_digit_1),
        .digit_10(w_msec_digit_10)
    );

    digit_splitter #(
        .BIT_WIDTH(SEC_WIDTH)
    ) U_SEC_DS (
        .digit_in(sec),
        .digit_1 (w_sec_digit_1),
        .digit_10(w_sec_digit_10)
    );

    digit_splitter #(
        .BIT_WIDTH(MIN_WIDTH)
    ) U_MIN_DS (
        .digit_in(min),
        .digit_1 (w_min_digit_1),
        .digit_10(w_min_digit_10)
    );

    digit_splitter #(
        .BIT_WIDTH(HOUR_WIDTH)
    ) U_HOUR_DS (
        .digit_in(hour),
        .digit_1 (w_hour_digit_1),
        .digit_10(w_hour_digit_10)
    );

    wire w_dot_onoff;

    comparator U_COMP_DOTONOFF (  //CL
        .comp_in(w_blink),  //msec 7bit
        .dot_onoff(w_dot_onoff)
    );
    
    //어떤 자릿수 깜빡일지 결정
    wire i_msec_onoff = (i_set == 1'b1) && (i_sel == 2'b00);
    wire i_sec_onoff  = (i_set == 1'b1) && (i_sel == 2'b01);
    wire i_min_onoff  = (i_set == 1'b1) && (i_sel == 2'b10);
    wire i_hour_onoff = (i_set == 1'b1) && (i_sel == 2'b11);

    // MUX에 들어가기 전에, 조건이 맞으면 빈 화면(4'hf)으로 덮어씌움!
    wire [3:0] w_msec_1_onoff  = (i_msec_onoff && w_dot_onoff) ? 4'hf : w_msec_digit_1;
    wire [3:0] w_msec_10_onoff = (i_msec_onoff && w_dot_onoff) ? 4'hf : w_msec_digit_10;
    wire [3:0] w_sec_1_onoff   = (i_sec_onoff  && w_dot_onoff) ? 4'hf : w_sec_digit_1;
    wire [3:0] w_sec_10_onoff  = (i_sec_onoff  && w_dot_onoff) ? 4'hf : w_sec_digit_10;
    wire [3:0] w_min_1_onoff   = (i_min_onoff  && w_dot_onoff) ? 4'hf : w_min_digit_1;
    wire [3:0] w_min_10_onoff  = (i_min_onoff  && w_dot_onoff) ? 4'hf : w_min_digit_10;
    wire [3:0] w_hour_1_onoff  = (i_hour_onoff && w_dot_onoff) ? 4'hf : w_hour_digit_1;
    wire [3:0] w_hour_10_onoff = (i_hour_onoff && w_dot_onoff) ? 4'hf : w_hour_digit_10;

    mux_8x1 U_MUX_MSEC_SEC (
        //0~9까지의 입력값이 있으니까 4bit로!
        .in0    (w_msec_1_onoff),     //0의 자리  
        .in1    (w_msec_10_onoff),    //10의 자리
        .in2    (w_sec_1_onoff),      //100의 자리
        .in3    (w_sec_10_onoff),     //1000의 자리
        .in4    (4'hf),
        .in5    (4'hf),
        .in6    ({3'b111,w_dot_onoff}),    //dot display 위한 자리
        .in7    (4'hf),
        .sel    (w_digit_sel),        //to select input
        .out_mux(w_out_mux_msec_sec)
    );

    mux_8x1 U_MUX_MIN_HOUR (
        //0~9까지의 입력값이 있으니까 4bit로!
        .in0(w_min_1_onoff),  //min의 1의 자리  
        .in1(w_min_10_onoff),  //min의 10의 자리
        .in2(w_hour_1_onoff),  //
        .in3(w_hour_10_onoff),  //
        .in4(4'hf),
        .in5(4'hf),
        .in6({3'b111,w_dot_onoff}),  //dot display 위한 자리
        .in7(4'hf),
        .sel(w_digit_sel),  //to select input
        .out_mux(w_out_mux_min_hour)
    );
    mux_2x1 U_MUX_2X1 (
        .in0(w_out_mux_msec_sec),  //MSEC와 SEC
        .in1(w_out_mux_min_hour),  //MIN과 HOUR
        .sel(sw),
        .out_mux(w_out_mux)
    );
    bcd U_BCD (
        .bin     (w_out_mux),
        .bcd_data(fnd_data)
    );
    clk_div_1khz U_CLK_DIV_1KHZ (
        .clk(clk),
        .rst(rst),
        .o_1khz(w_1khz),
        .o_blink(w_blink)//이걸 reg로 바꾸면 x상태에서 시작하니까 뭘로 변할지를 모름
    );
    counter_8 U_COUNTER_8 (
        .clk(w_1khz),
        .rst(rst),
        .digit_sel(w_digit_sel)
    );
    decoder_2X4 U_DECODER_2X4 (
        .decoder_in(w_digit_sel[1:0]),  //상위 비트가 묶이지 않도록
        .fnd_com(fnd_com)
    );
endmodule

module comparator (  //CL
    input  [6:0] comp_in,   //msec 7bit
    output       dot_onoff
);
    //0~49 : false 0, 50~99 : true 1 
    assign dot_onoff = (comp_in == 1);

endmodule
module mux_2x1 (
    input  [3:0] in0,     //MSEC와 SEC
    input  [3:0] in1,     //MIN과 HOUR
    input        sel,
    output [3:0] out_mux
);

    assign out_mux = (sel) ? in1 : in0; //sel이 참이면 min_hour, 즉, 스위치 0일 때 msec과 sec 먼저 나가도록

endmodule

module clk_div_1khz (
    input clk,
    input rst,
    output o_1khz, //이걸 reg로 바꾸면 x상태에서 시작하니까 뭘로 변할지를 모름
    output o_blink
    );

    reg [15:0] counter_reg;  //16bit짜리 플립플롭 생성됨
    reg [25:0] counter_blink;
    reg o_1khz_reg;
    reg o_blink_reg;

    assign o_1khz = o_1khz_reg;
    assign o_blink = o_blink_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 16'd0;
            o_1khz_reg  <= 1'b0;
            o_blink_reg <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (50_000 - 1)) begin
                counter_reg <= 16'd0;
                o_1khz_reg  <= ~o_1khz_reg;
            end
            
            counter_blink <= counter_blink + 1;
            if (counter_blink == (50_000_000 - 1)) begin
                counter_blink <= 26'd0;
                o_blink_reg   <= ~o_blink_reg;
            end
        end

    end

endmodule


module counter_8 (
    input clk,
    input rst,
    output [2:0] digit_sel
);

    reg [2:0] counter_reg;  //0,1,2,3,4,5,6,7

    assign digit_sel = counter_reg;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
        end
    end
endmodule

module decoder_2X4 (
    input      [1:0] decoder_in,
    output reg [3:0] fnd_com
);

    always @(*) begin
        case (decoder_in)
            2'b00: fnd_com = 4'b1110;
            2'b01: fnd_com = 4'b1101;
            2'b10: fnd_com = 4'b1011;
            2'b11: fnd_com = 4'b0111;

            default: fnd_com = 4'b1111;
        endcase
    end

endmodule

module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input  [BIT_WIDTH-1:0] digit_in,
    output [          3:0] digit_1,
    output [          3:0] digit_10
);

    //assign 사용
    assign digit_1  = digit_in % 10;
    assign digit_10 = (digit_in / 10) % 10;


endmodule
module mux_8x1 (
    //0~9까지의 입력값이 있으니까 4bit로!
    input [3:0] in0,  //0의 자리  
    input [3:0] in1,  //10의 자리
    input [3:0] in2,  //100의 자리
    input [3:0] in3,  //1000의 자리
    input [3:0] in4,    
    input [3:0] in5,  
    input [3:0] in6,  
    input [3:0] in7,
    input [2:0] sel,  //to select input
    output [3:0] out_mux
);
    reg [3:0] out_reg;
    assign out_mux = out_reg;

    //mux
    always @(*) begin
        case (sel)
            3'b000: out_reg = in0;
            3'b001: out_reg = in1;
            3'b010: out_reg = in2;
            3'b011: out_reg = in3;
            3'b100: out_reg = in4;
            3'b101: out_reg = in5;
            3'b110: out_reg = in6;
            3'b111: out_reg = in7;

            default:
            out_reg = 4'b0000; //full case 처리했기 때문에 아무 문제가 없지만 그래도 default 추가해서 래치 발생하지 않도록
        endcase
    end
endmodule

module bcd (
    input [3:0] bin,
    output reg [7:0] bcd_data
);

    always @(bin) begin  //항상 bin을 감시하라는 뜻
        case(bin) //설계할 때는 always 구문 안에서만 case 사용 가능
            4'b0000: bcd_data = 8'hC0;
            4'b0001: bcd_data = 8'hF9;
            4'b0010: bcd_data = 8'hA4;
            4'b0011: bcd_data = 8'hB0;
            4'b0100: bcd_data = 8'h99;
            4'b0101: bcd_data = 8'h92;
            4'b0110: bcd_data = 8'h82;
            4'b0111: bcd_data = 8'hF8;
            4'b1000: bcd_data = 8'h80;
            4'b1001: bcd_data = 8'h90;
            4'b1010:bcd_data = 8'h88;  //A니까 여기서부터는 쓰지 않음
            4'b1011: bcd_data = 8'h83;
            4'b1100: bcd_data = 8'hC6;
            4'b1101: bcd_data = 8'hA1;
            /*4'b1110: bcd_data = 8'h86;
            4'b1111: bcd_data = 8'h8E;*/

            4'b1110: bcd_data = 8'h7F;  //DP ON
            4'b1111: bcd_data = 8'hFF;  //DP OFF

            default: bcd_data = 8'hFF;
        endcase

    end
endmodule


