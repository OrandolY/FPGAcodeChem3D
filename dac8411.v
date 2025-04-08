`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/02/06 14:45:12
// Design Name: 
// Module Name: dac8411
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 1000ksps dac 16bit 0~5V
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dac8411(
    input clk,
    
    input wire [15:0]dac_data,

    output wire DAC_SCLK,
    output wire DAC_D_IN,
    output wire DAC_SYNC

);

reg  clk1M = 1;

//25MHz clk
always@(posedge clk)
    clk1M <= ~clk1M;


reg  [15:0]Votage_reg = 16'h0;

always@(posedge clk)
    if(DAC_SYNC)
        Votage_reg <= dac_data;

//send from high bit
reg [24:0]reg_sync = 25'b1_0000_0000_0000_0000_0000_0000;
reg [24:0]reg_data = 25'b0_00_0000_0000_0000_0000_11_1111;

//update registers
always @(posedge clk1M) 
if(DAC_SYNC)begin
    reg_sync <= {reg_sync[23:0], reg_sync[24]}; // 左移并将最高位送到最低位  
    reg_data <= {2'b00, Votage_reg, 1'b0, 6'b000_000}; // 同样处理  
    //reg_data <= {reg_data[23:0], reg_data[24]};
    end
else begin  
    reg_sync <= {reg_sync[23:0], reg_sync[24]}; // 左移并将最高位送到最低位  
    reg_data <= {reg_data[23:0], reg_data[24]}; // 同样处理  
    end

assign DAC_SCLK = clk1M;
assign DAC_D_IN = reg_data[24];
assign DAC_SYNC = reg_sync[24];

endmodule

