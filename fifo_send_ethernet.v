`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/12/21 11:56:28
// Design Name: 
// Module Name: fifo_send_ethernet
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo_send_ethernet(
    clk50M,

    reset_n,
    
//    AD0,
//    DA2,
//    DA0,
//    DA1,
    
    led,
    eth_reset_n,
    
    gmii_tx_clk,
    gmii_txd,
    gmii_txen
    );
    
    
input  wire clk50M;

reg    [15:0]AD0 = 16'hAABB;
reg    [15:0]DA2 = 16'hCCDD;
reg    [15:0]DA0 = 16'hEEFF;
reg    [15:0]DA1 = 16'h1122;

reg  rd_en = 0;

wire clk_10;
wire clk125M;
wire clk62M5;
wire fifo_full;
wire fifo_empty;

//assign wr_en = 1;
//assign rd_en = fifo_full;

reg  [127:0]fifo_din = 128'h0;

//  wire       clk125M;
  wire       udp_gmii_rst_n;
  wire       pll_locked;
  reg [15:0] cnt_dly_time;
  wire       tx_en_pulse;  
  wire       payload_req;
  wire [7:0]  payload_dat;
  reg [15:0] tx_byte_cnt;

clk_wiz_0 clk_wiz_0
   (
    // Clock out ports
    .clk_out1(clk_10),     // output clk_out1
    .clk_out2(clk125M),     // output clk_out2
    .clk_out3(clk62M5),     // output clk_out2
    // Status and control signals
    .reset(0), // input reset
    .locked(pll_locked),       // output locked
   // Clock in ports
    .clk_in1(clk50M)      // input clk_in1
);

input         reset_n = 1;
output        led;
output        eth_reset_n;
output        gmii_tx_clk;
output  [7:0] gmii_txd;
output        gmii_txen;

  assign led            = pll_locked;
  assign eth_reset_n    = pll_locked;
  assign udp_gmii_rst_n = pll_locked;

  eth_udp_tx_gmii eth_udp_tx_gmii
  (
    .clk125M       (clk125M               ),
    .reset_n       (udp_gmii_rst_n        ),
                   
    .tx_en_pulse   (tx_en_pulse           ),
    .tx_done       (tx_done               ),
                   
    .dst_mac       (48'h08_26_AE_35_A0_32 ),
    .src_mac       (48'h00_0a_35_01_fe_c0 ),  
    .dst_ip        (32'hc0_a8_00_03       ),
    .src_ip        (32'hc0_a8_00_02       ),	
    .dst_port      (16'd1000              ),
    .src_port      (16'd5000              ),
                   
    .data_length   (800                   ),
    
    .payload_req_o (payload_req           ),
    .payload_dat_i (payload_dat           ),

    .gmii_tx_clk   (gmii_tx_clk           ),	
    .gmii_txen     (gmii_txen             ),
    .gmii_txd      (gmii_txd              )
  );
	always@(posedge clk125M or negedge udp_gmii_rst_n)
  if(!udp_gmii_rst_n)
    cnt_dly_time <= 16'd0;
  else
    cnt_dly_time <= cnt_dly_time + 1'b1;

  //ssign tx_en_pulse = &cnt_dly_time;
  assign tx_en_pulse = fifo_full;
  
  always@(posedge clk125M or negedge reset_n)
  if(!reset_n)
    tx_byte_cnt <= 16'd0;
  else if(payload_req)
    begin
    tx_byte_cnt <= tx_byte_cnt + 1'b1;
    //payload_dat <= payload_dat + 1'b1;
    end
  else
    tx_byte_cnt <= 16'd0;


//--------------------------------------------------
localparam DIV_FROM_10M = 10;

reg  [31:0]clk_cnt = 0;
reg  clk_100k      = 1'b0;
always@(posedge clk_10)
    if(clk_cnt == DIV_FROM_10M - 1)
        clk_cnt <= 0;
    else
        clk_cnt <= clk_cnt + 1'b1;

always@(posedge clk_10)
    if(clk_cnt == DIV_FROM_10M - 1)
        clk_100k <= 1'b1;
    else
        clk_100k <= 1'b0;

//---------------------------------------------------
//内部采样计数
reg  [31:0]LableOfData = 32'h00_00_00_01;
//要写入的数据的更新

always@(negedge clk_10)
    if(~reset_n)
        fifo_din <= 128'h0;
    else if(clk_cnt == DIV_FROM_10M - 2)
        begin
            fifo_din <= {16'h12_34, LableOfData, 16'h56_78, AD0, DA2, DA0, DA1};
            LableOfData <= LableOfData + 1'b1;
            AD0 <= AD0;// + 1'b1;
            DA2 <= DA2;// + 1'b1;
            DA0 <= DA0;// + 1'b1;
            DA1 <= DA1;// + 1'b1;
        end
    else
        fifo_din <= fifo_din;

always@(posedge clk125M or negedge reset_n)
    if(!reset_n)
        rd_en <= 0;
    else if(fifo_full)
        rd_en <= 1'b1;
    else if(rd_en && tx_done)
        rd_en <= 1'b0;
    else
        rd_en <= rd_en;
    
//-----------------------------------------------
wire wr_rst_busy;
wire [15:0]fifo_data_out;

reg  Flag_high8 = 1'b1;
always@(posedge clk125M or negedge reset_n)
    if(!reset_n)
        Flag_high8 <= 1;
    else
        Flag_high8 <= ~Flag_high8;

assign payload_dat = Flag_high8 ? fifo_data_out[15:8] : fifo_data_out[7:0];
assign fifo_wr_clk = clk_100k;

fifo_0 fifo_0 (
  .rst(~reset_n),        // input wire rst
  .wr_clk(~clk_10),  // input wire wr_clk
  .rd_clk(~clk62M5),  // input wire rd_clk
  .din(fifo_din),        // input wire [127 : 0] din
  .wr_en(fifo_wr_clk),    // input wire wr_en
  .rd_en(rd_en & payload_req),    // input wire rd_en  (rd_en & payload_req)
  .dout(fifo_data_out),      // output wire [15 : 0] dout
  .full(fifo_full),      // output wire full
  .empty(fifo_empty),   // output wire empty
  .wr_rst_busy(wr_rst_busy),  // output wire wr_rst_busy
  .rd_rst_busy()
);
    

    
endmodule
