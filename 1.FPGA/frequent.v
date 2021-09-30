module frequent(
	input sys_clk,
	input sys_rst_n,
	input frequent_in,
	output uart_out_64,
	output uart_out_8
);

//parameter define
parameter  CLK_FREQ = 50000000;       //定义系统时钟频率
parameter  UART_BPS = 115200;         //定义串口波特率

parameter    CLK_FS = 26'd50000000;      // 基准时钟频率值

wire [7:0] uart_data_w_64;               //UART发送数据

wire [7:0] uart_data_w_8;               //UART发送数据

wire [7:0] pulse_width;						//占空比
wire [31:0] cnt_fs;
wire [31:0] cnt_fx;
wire [63:0] data_64;
assign data_64 = {cnt_fs, cnt_fx};

wire			uart_enable_8;
wire			uart_enable_64;
wire			frequent_enable;

wire			fifo_read_empty_8;
wire			fifo_read_empty_64;

wire			fifo_write_full_8;
wire			fifo_write_full_64;

wire fifo_enable_8;
wire fifo_enable_64;

wire			uart_busy_8;
wire			uart_busy_64;

wire			frequent_ok;


assign uart_enable_8 = !fifo_read_empty_8 & !uart_busy_8;
assign uart_enable_64 = !fifo_read_empty_64 & !uart_busy_64;

assign fifo_enable_8 = frequent_ok & !fifo_write_full_8;
assign fifo_enable_64 = frequent_ok & !fifo_write_full_64;

reg                fifo_d0  ;           
reg                fifo_d1  ; 

assign net_edge_enable = fifo_d0 & (~fifo_d1); 


reg[3: 0] test;

assign new_edge = test[3];

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        test <= 4'b0;
    end
    else begin
        test <= {test[2: 0], net_edge_enable };
    end
end


always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        fifo_d0 <= 1'b0;
        fifo_d1 <= 1'b0;
    end
    else begin
        fifo_d0 <= uart_enable_64;
        fifo_d1 <= fifo_d0;
    end
end          


uart_send #(                          //串口发送模块
    .CLK_FREQ       (CLK_FREQ),       //设置系统时钟频率
    .UART_BPS       (UART_BPS))       //设置串口发送波特率
uart_64(                 
    .sys_clk        (sys_clk),
    .sys_rst_n      (sys_rst_n),
     
    .uart_en        (new_edge),
    .uart_din       (uart_data_w_64),
    .uart_txd       (uart_out_64),
	 .out			(uart_busy_64)
    );

uart_send #(                          //串口发送模块
    .CLK_FREQ       (CLK_FREQ),       //设置系统时钟频率
    .UART_BPS       (UART_BPS))       //设置串口发送波特率
uart_8(                 
    .sys_clk        (sys_clk),
    .sys_rst_n      (sys_rst_n),
     
    .uart_en        (uart_enable_8),
    .uart_din       (uart_data_w_8),
    .uart_txd       (uart_out_8),
	 .out			(uart_busy_8)
    );
	 
fifo_8 fifo_8_bit(
	.data	(pulse_width),
	.rdclk (sys_clk),
	.rdreq (uart_enable_8) ,
	.wrclk (sys_clk),
	.wrreq (fifo_enable_8),
	.q (uart_data_w_8),
	.rdempty (fifo_read_empty_8),
	.wrfull (fifo_write_full_8));
	
	
fifo_64 fifo_64_bit(
	.data	(data_64),
	.rdclk (sys_clk),
	.rdreq (net_edge_enable) ,
	.wrclk (sys_clk),
	.wrreq (fifo_enable_64),
	.q (uart_data_w_64),
	.rdempty (fifo_read_empty_64),
	.wrfull (fifo_write_full_64));
	
cymometer #(.CLK_FS(CLK_FS)              // 基准时钟频率值
) u_cymometer(
    //system clock
    .clk_fs      (sys_clk  ),            // 基准时钟信号
    .rst_n       (sys_rst_n),            // 复位信号
    //cymometer interface
    .clk_fx      (frequent_in   ),            // 被测时钟信号
	 .fx_cnt_out	(cnt_fx),
	 .fs_cnt_out	(cnt_fs),
	 .pulse_width	(pulse_width),
	.ok(frequent_ok)
);

	 
endmodule