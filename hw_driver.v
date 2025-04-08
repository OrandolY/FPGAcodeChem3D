`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/02/17 19:48:18
// Design Name: 
// Module Name: hw_driver
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
module hw_driver(
    
    input wire clk,
    // analog device control
    output wire ADC_DIN ,
    output wire ADC_SCLK,
    input  wire ADC_DOUT,
    output wire ADC_CONV,
    
    
    output wire DAC1_SCLK,
    output wire DAC1_D_IN,
    output wire DAC1_SYNC,
    
    output wire DAC2_SCLK,
    output wire DAC2_D_IN,
    output wire DAC2_SYNC,
    
    output wire DAC3_SCLK,
    output wire DAC3_D_IN,
    output wire DAC3_SYNC,
    
    output wire DAC4_SCLK,
    output wire DAC4_D_IN,
    output wire DAC4_SYNC,
    
    // System ports
    input  RST_N,
    // Uart ports
    input  rx,
    output tx,
    // Eth Send Pins
    output  led,
    output  eth_reset_n,
    output        gmii_tx_clk,
    output  [7:0] gmii_txd,
    output        gmii_txen
    
    );
 
wire  [15:0]adc_data;
wire  [15:0]data_dac1;
wire  [15:0]data_dac2;
wire  [15:0]data_dac3;
wire  [15:0]data_dac4;

//assign data_dac1 = adc_data;
//assign data_dac2 = adc_data;
//assign data_dac3 = adc_data;
//assign data_dac4 = adc_data;
    
signal_ctrl signal_ctrl(
    // System ports
    .Clk   (clk)  ,
    .RST_N (RST_N),
    // Uart ports
    .rx    (rx)   ,
    .tx    (tx)   ,
    // Dtxevice control pins
    .AD0   (adc_data),
    
    .DA2   (data_dac1),
    .DA0   (data_dac2),
    .DA1   (data_dac3),
    // Unused pins
    // pct ~ dac4
    .Pct_out(data_dac4),
    
    // Eth send pins
    .led        (led        ),
    .eth_reset_n(eth_reset_n),
    .gmii_tx_clk(gmii_tx_clk),
    .gmii_txd   (gmii_txd   ),
    .gmii_txen  (gmii_txen  )
    );
    
// hardware driver    
ads8860 ads8860(
    .clk      (clk),
    .adc_data_o(adc_data),

    .ADC_DIN  (ADC_DIN ),
    .ADC_SCLK (ADC_SCLK),
    .ADC_DOUT (ADC_DOUT),
    .ADC_CONV (ADC_CONV)
    );
    
dac8411 dac1(
    .clk      (clk),
    .dac_data (data_dac1),

    .DAC_SCLK (DAC1_SCLK),
    .DAC_D_IN (DAC1_D_IN),
    .DAC_SYNC (DAC1_SYNC)

);

dac8411 dac2(
    .clk      (clk),
    .dac_data (data_dac2),

    .DAC_SCLK (DAC2_SCLK),
    .DAC_D_IN (DAC2_D_IN),
    .DAC_SYNC (DAC2_SYNC)

);

dac8411 dac3(
    .clk      (clk),
    .dac_data (data_dac3),

    .DAC_SCLK (DAC3_SCLK),
    .DAC_D_IN (DAC3_D_IN),
    .DAC_SYNC (DAC3_SYNC)

);

dac8411 dac4(
    .clk      (clk),
    .dac_data (data_dac4),

    .DAC_SCLK (DAC4_SCLK),
    .DAC_D_IN (DAC4_D_IN),
    .DAC_SYNC (DAC4_SYNC)

);  
    
    
    
endmodule
