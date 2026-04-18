`timescale 1ns / 1ps

module button_debounce (
    input  clk,
    input  rst,
    input  i_btn,
    output o_btn
);

    //clock divider 구현
    //100Mhz -> 100Khz
    parameter F_COUNT = 100_000_000/100_000;
    reg [$clog2(F_COUNT)-1:0] r_counter;
    reg clk_100khz;

    always @(posedge clk, posedge rst) begin
        if(rst) begin
            r_counter <= 0;
            clk_100khz <= 1'b0;
        end else begin
            r_counter <= r_counter + 1;
            if(r_counter == F_COUNT-1) begin
                r_counter <= 0;
                clk_100khz <= 1'b1;
            end else begin
                clk_100khz <= 1'b0;
            end
        end
    end

    //synchronizer 구현
    reg [7:0] sync_reg, sync_next;
    wire debounce;

    always @(posedge clk_100khz, posedge rst) begin
        if(rst)begin
            sync_reg <= 7'h00;
        end else begin
            sync_reg <= sync_next;
        end
    end

    always @(*) begin
        //초기화는 없어도 됨
        sync_next = {i_btn, sync_reg[7:1]}; //위에서부터 집어넣기 
        //sync_next = {sync_reg[6:0], i_btn}; //아래에서부터 집어넣기
    end

    //8input to 1 output and gate
    assign debounce = &sync_reg; //8bit 모두 and해서 debounce라는 핀으로 뽑아라는 뜻

    reg edge_reg;

    //rising edge detect
    //디바운스 신호를 플립플롭에 넣기
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            edge_reg <= 1'b0;        
        end else begin
            edge_reg <= debounce;
        end
    end

    assign o_btn = debounce& (~edge_reg);
    

endmodule
