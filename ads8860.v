`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/02/06 20:33:07
// Design Name: 
// Module Name: ads8860
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 500ksps adc 16bit 0~5V
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ads8860(
    input clk,
    
    output reg [15:0]adc_data_o,

    output wire ADC_DIN,
    output wire ADC_SCLK,
    input  wire ADC_DOUT,
    output wire  ADC_CONV
    );
    
    //wire clk200m;
    //wire clk10m;
    
    reg  [15:0]adc_data = 0;
    //reg  [15:0]adc_data_o = 0;
    
    assign ADC_DIN = 1;
    
    reg  adc_sclk;
    reg  adc_conv;
    
    assign ADC_SCLK = adc_sclk;
    assign ADC_CONV = adc_conv;
    
    reg [31:0]cnt_period = 0;
    reg [7:0] cnt_adc = 0;

always@(posedge clk)
    if(cnt_period == 99)
        cnt_period <= 0;
    else
        cnt_period <= cnt_period + 1'b1;
        
always@(posedge clk)
    begin
    case(cnt_period) 
        /*0,1,2,3,4,5 : begin
                adc_sclk <= 1'b0;
                adc_conv <= 1'b1;
            end*/
        61,62,63,64,65,66 : begin
                adc_sclk <= 1'b0;
                adc_conv <= 1'b0;
            end
        67,69,71,73,75,77,79,81,83,85,87,89,91,93,95,97:begin
                adc_sclk <= 1'b1;
                adc_conv <= 1'b0;
            end
        68,70,72,74,76,78,80,82,84,86,88,90,92,94,96,98:begin
                adc_sclk <= 1'b0;
                adc_conv <= 1'b0;
                //adc_data <= {adc_data[14:0], ADC_DOUT};
            end
        99: begin
                adc_sclk <= 1'b0;
                adc_conv <= 1'b0;
                adc_data_o <= adc_data;
            end
        default : begin
                adc_sclk <= 1'b0;
                adc_conv <= 1'b1;
            end
    endcase
    end

always@(negedge ADC_SCLK)
    adc_data <= {adc_data[14:0], ADC_DOUT};
/*
ila0 ila (
	.clk(clk200m), // input wire clk


	.probe0(ADC_DIN), // input wire [0:0]  probe0  
	.probe1(ADC_SCLK), // input wire [0:0]  probe1 
	.probe2(ADC_DOUT), // input wire [0:0]  probe2 
	.probe3(ADC_CONV), // input wire [0:0]  probe3 
	.probe4(flag), // input wire [0:0]  probe4 
	.probe5(adc_data_o) // input wire [15:0]  probe5
);

  pll0 pll
   (
    // Clock out ports
    .clk_out1(clk200m),     // output clk_out1
    .clk_out2(clk10m),     // output clk_out2
    // Status and control signals
    .reset(0), // input reset
    .locked(),       // output locked
   // Clock in ports
    .clk_in1(clk)      // input clk_in1
);
*/
endmodule
