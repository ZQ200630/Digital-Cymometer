//****************************************Copyright (c)***********************************//
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com
//关注微信公众平台微信号："正点原子"，免费获取FPGA & STM32资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           cymometer
// Last modified Date:  2018/4/4 16:11:57
// Last Version:        V1.0
// Descriptions:        等精度频率计模块，测量被测信号频率
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2018/4/4 16:11:55
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module cymometer
   #(parameter    CLK_FS = 26'd50_000_000) // 基准时钟频率值
    (   //system clock
        input                 clk_fs ,     // 基准时钟信号
        input                 rst_n  ,     // 复位信号

        //cymometer interface
        input                 clk_fx ,     // 被测时钟信号
        output  reg [31:0]  fx_cnt_out,
        output  reg [31:0]  fs_cnt_out,
        output  reg [7:0]   pulse_width,
        output       reg       ok
);

//parameter define
localparam   MAX       =  10'd64;           // 定义fs_cnt、fx_cnt的最大位宽
localparam   GATE_TIME = 32'd10_000_000;        // 门控时间设置

//reg define
reg                gate        ;           // 门控信号
reg                gate_fs     ;           // 同步到基准时钟的门控信号
reg                gate_fs_r   ;           // 用于同步gate信号的寄存器
reg                gate_fs_d0  ;           // 用于采集基准时钟下gate下降沿
reg                gate_fs_d1  ;           // 
reg                gate_fx_d0  ;           // 用于采集被测时钟下gate下降沿
reg                gate_fx_d1  ;           // 
reg    [   31:0]   gate_cnt    ;           // 门控计数
reg    [MAX-1:0]   fs_cnt_low      ;           // 门控时间内基准时钟的计数值
reg    [MAX-1:0]   fs_cnt_low_temp ;           // fs_cnt 临时值
reg    [MAX-1:0]   fs_cnt_high      ;           // 门控时间内基准时钟的计数值
reg    [MAX-1:0]   fs_cnt_high_temp ;           // fs_cnt 临时值
reg    [MAX-1:0]   fs_cnt      ;           // 门控时间内基准时钟的计数值
reg    [MAX-1:0]   fs_cnt_temp ;           // fs_cnt 临时值
reg    [MAX-1:0]   fx_cnt      ;           // 门控时间内被测时钟的计数值
reg    [MAX-1:0]   fx_cnt_temp ;           // fx_cnt 临时值

//wire define
wire               neg_gate_fs;            // 基准时钟下门控信号下降沿
wire               neg_gate_fx;            // 被测时钟下门控信号下降沿

//*****************************************************
//**                    main code
//*****************************************************

//边沿检测，捕获信号下降沿
assign neg_gate_fs = gate_fs_d1 & (~gate_fs_d0);
assign neg_gate_fx = gate_fx_d1 & (~gate_fx_d0);

//门控信号计数器，使用被测时钟计数
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n)
        gate_cnt <= 32'd0; 
    else if(gate_cnt == GATE_TIME + 32'd40_000_000)
        gate_cnt <= 32'd0;
    else
        gate_cnt <= gate_cnt + 1'b1;
end

//门控信号，拉高时间为GATE_TIME个实测时钟周期
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n)
        gate <= 1'b0;
    else if(gate_cnt < 4'd10)
        gate <= 1'b0;     
    else if(gate_cnt < GATE_TIME)
        gate <= 1'b1;
    else if(gate_cnt <= GATE_TIME + 32'd40_000_000)
        gate <= 1'b0;
    else 
        gate <= 1'b0;
end

//将门控信号同步到基准时钟下
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin
        gate_fs_r <= 1'b0;
        gate_fs   <= 1'b0;
    end
    else begin
        gate_fs_r <= gate;
        gate_fs   <= gate_fs_r;
    end
end

//打拍采门控信号的下降沿（被测时钟下）
always @(posedge clk_fx or negedge rst_n) begin
    if(!rst_n) begin
        gate_fx_d0 <= 1'b0;
        gate_fx_d1 <= 1'b0;
    end
    else begin
        gate_fx_d0 <= gate;
        gate_fx_d1 <= gate_fx_d0;
    end
end

//打拍采门控信号的下降沿（基准时钟下）
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin
        gate_fs_d0 <= 1'b0;
        gate_fs_d1 <= 1'b0;
    end
    else begin
        gate_fs_d0 <= gate_fs;
        gate_fs_d1 <= gate_fs_d0;
    end
end

//门控时间内对被测时钟计数
always @(posedge clk_fx or negedge rst_n) begin
    if(!rst_n) begin
        fx_cnt_temp <= 32'd0;
        fx_cnt <= 32'd0;
    end
    else if(gate)
        fx_cnt_temp <= fx_cnt_temp + 1'b1;
    else if(neg_gate_fx) begin
        fx_cnt_temp <= 32'd0;
        fx_cnt  <= fx_cnt_temp;
    end
end

//门控时间内对基准时钟计数
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin
        fs_cnt_temp <= 32'd0;
        fs_cnt <= 32'd0;
    end
    else if(gate_fs) begin
		fs_cnt_temp <= fs_cnt_temp + 1'b1;
	 end
    else if(neg_gate_fs) begin
        fs_cnt <= fs_cnt_temp;
        fs_cnt_temp <= 32'd0;
    end
end

always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin
        fs_cnt_high_temp <= 32'd0;
        fs_cnt_high <= 32'd0;
    end
    else if(gate_fs & clk_fx) begin
        fs_cnt_high_temp <= fs_cnt_high_temp + 1'b1;
		  end
    else if(neg_gate_fs) begin
        fs_cnt_high <= fs_cnt_high_temp;
        fs_cnt_high_temp <= 32'd0;
    end
end

//计算被测信号频率
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin
        fs_cnt_out <= 32'b0;
        fx_cnt_out <= 32'b0;
    end
    else if(gate_fs == 1'b0)
        fs_cnt_out <= fs_cnt;
        fx_cnt_out <= fx_cnt;
end

always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin
        pulse_width <= 8'b0;
    end
    else if(fs_cnt_temp == 16'd10000)
        pulse_width <= (fs_cnt_high_temp * 256) / fs_cnt_temp;
end

reg  a3_edge;
reg [2:0] a3;

always @(posedge clk_fs or negedge rst_n)
begin
    if(!rst_n) begin
        a3 <= 3'b000;
    end
    else begin
        a3 <= {a3[1:0], gate_fs};
			end
	a3_edge <= a3[2] ^ a3[1];
end



always @(posedge clk_fs or negedge rst_n)
begin 
    if(!rst_n) 
    begin
        ok <= 1'b0;
    end
    else if(a3_edge == 1'b1)
        ok <= 1'b1;
    else
        ok <= 1'b0;
end

endmodule 