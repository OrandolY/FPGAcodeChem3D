`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Shijie Yang
// 
// Create Date: 2024/09/22 10:59:46
// Design Name: Driver for scanning machine
// Module Name: signal_ctrl
// Project Name: 
// Target Devices: 7a35t
// Tool Versions: vivado 23.1
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 25.02.22 - Change hardware and data width
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module signal_ctrl(
    //input EN_MACHINE_RUNNING,
    // System ports
    input  Clk,
    input  RST_N,
    // Uart ports
    input  rx,
    output tx,
    // Device control pins
    input  [15:0]AD0,
    //output wire [13:0]DA2,
    output reg  [15:0]DA0,DA1,
    output wire [15:0]DA2,
    
    output wire [15:0]Pct_out,
    
    // Eth send pins
    output  led,
    output  eth_reset_n,
    output        gmii_tx_clk,
    output  [7:0] gmii_txd,
    output        gmii_txen
    );
/* Hardware ports*/  
    // Device wrt clock output
    // Device data width
    localparam AD_WIDTH = 16;
    localparam DA_WIDTH = 16;
/* Ending ports*/
    // Device data for all works end
    reg [AD_WIDTH - 1:0]DA2_Ending = 16'b0;
    reg [AD_WIDTH - 1:0]DA0_Ending = 16'b0;
    reg [AD_WIDTH - 1:0]DA1_Ending = 16'b0;
    
/* RAW frequency generate*/ 
    //Speed mode for ad ; clock period : x * 20ns * 2
    // e.g. 50 means 500kHz capture 
    // e.g. 250 means 100kHz capture
    reg [31:0]MODE_FREQUENCY = 5;//25000;
    reg [31:0]MODE_FREQUENCY_second = 50;//2500000;
    // counter for this (da2_data_clk)
    reg [31:0]clk_cnt = 32'd0;
    reg [31:0]clk_cnt_second = 32'd0;
    
/* ===========================AD0========================= */
    //
    reg [AD_WIDTH - 1:0]SET_THRESHOLD = 16'd1300;
    // running data for AD
    reg [AD_WIDTH - 1:0]ad0_data = 16'd0;
    reg [AD_WIDTH - 1:0]ad0_data_dly = 16'd0;
    // detected ad's upscale
    reg  ad0_up = 1'b1;

/* ===========================DA2========================= */
    // Mode set for DA2
    // StepHeight for DA2
    reg [DA_WIDTH - 1:0] DA2_stepheight = 16'd1;
    // Running mode for DA2 
    // 1:up  0:down
    // Delay to catch the scale of DA2
    wire DA2_runmode;
    reg DA2_runmode_dly = 1'b1;
    // DA2 MAX and MIN
    reg [DA_WIDTH - 1:0] DA2_MIN = 16'd6553;
    reg [DA_WIDTH - 1:0] DA2_MIN_RAW = 16'd6553;
    reg [DA_WIDTH - 1:0] DA2_MAX = 16'd65535;
    // Clock for DA2
    // From mode of FREQUENCY
    reg DA2_clk_data = 1'b1;
    // running data for DA2
    reg [DA_WIDTH - 1:0]da2_data = 16'd0;
    
/* ===========================DA0========================= */
    // Clock for DA0
    wire DA0_clk_data;

    // StepHeight for DA0
    reg [DA_WIDTH - 1:0] DA0_stepheight = 16'd20;
    // Running mode for DA0 
    // 1:up  0:down
    // Delay to catch the scale of DA0
    reg DA0_runmode = 1'b1;
    reg DA0_runmode_dly = 1'b1;
    // DA0 MAX and MIN
    reg [DA_WIDTH - 1:0] DA0_MIN = 16'd6553;
    reg [DA_WIDTH - 1:0] DA0_MAX = 16'd65535;
    // running data for DA0
    reg [DA_WIDTH - 1:0]da0_data = 16'd0;
    
/* ===========================DA1========================= */
    // Clock for DA1
    wire DA1_clk_data;
    // StepHeight for DA0
    reg [DA_WIDTH - 1:0] DA1_stepheight = 16'd20;
    // DA1 MAX and MIN
    reg [DA_WIDTH - 1:0]DA1_MIN = 16'd6553;
    reg [DA_WIDTH - 1:0]DA1_MAX = 16'd65535;
    // running data for DA1
    reg [DA_WIDTH - 1:0]da1_data = 16'd0;
    
/* ===================every change of DA0 DA1 need to delay========================= */
    // set for DA2 holdtime while DA0 changing
    // set for DA2&DA0 holdtime while DA1 changing
    // Set DA need to hold time
    localparam HOLD_TIME_CHANGE = 10000;//500000;//50 000 * 20 ns = 0.1ms
    wire DA0_change_flag;
    reg  DA1_change_flag = 1'b0;
    // use double flag to make sure that DA1 changes after DA0's hold time has over
    wire  DA1_change_flag_2;
    // counter for delay 
    reg [31:0]DA0_change_timecnt = 32'd0;
    reg [31:0]DA1_change_timecnt = 32'd0;

/* ===================Thumb to set enable global========================= */
    // Defalut 0 disable
    reg  EN_MACHINE_RUNNING = 1'b0;
    //wire EN_MACHINE_RUNNING;
    
/* ===================signal to show when the scanning has ended========================= */
    // DA1 has reached highest step and stay for 1ms
    reg  SCAN_END = 1'b0;
    // DA1 has reached highest step, wait for delay
    reg  SCAN_END_early = 1'b0;
    // delay of ending, counter for delay
    reg  [31:0]cnt_scan_end = 32'd0; 
    // the last stage of each DA after scanning end
    localparam DA_0V = 0;

/* ===================[DA2_clk_data] ========================= */
    always@(posedge Clk)
    if(clk_cnt >= MODE_FREQUENCY)
    begin
        clk_cnt <= 32'd0;
        DA2_clk_data <= ~DA2_clk_data;
    end
    else
    begin
        clk_cnt <= clk_cnt + 1'b1;
        DA2_clk_data <= DA2_clk_data;
    end
/* ===================[da2_data] ========================= */
    // Do not change while disabled or DA1 DA0 is chaning
    assign DA2_runmode = ad0_up;
    always@(posedge DA2_clk_data) 
        begin
            if(~EN_MACHINE_RUNNING)
                begin
                    da2_data <= DA2_MIN;
                end
            else if(DA2_runmode && da2_data >= DA2_MAX - DA2_stepheight)
                begin
                    da2_data <= DA2_MAX;
                end
            else if(~DA2_runmode && da2_data <= DA2_MIN + DA2_stepheight)
                begin
                    da2_data <= DA2_MIN;
                end
            else if(DA2_runmode)
                begin
                    da2_data <= da2_data + DA2_stepheight;
                end
            else if(~DA2_runmode)
                begin
                    da2_data <= da2_data - DA2_stepheight;
                end
            else
                begin
                    da2_data <= da2_data;
                end
        end
    
/* ===================[DA0_clk_data] ========================= */
    // Use this signal to lead DA0's change
    reg  da0clk = 1'b1;
    always@(posedge Clk)
    if(clk_cnt_second >= MODE_FREQUENCY_second)
    begin
        clk_cnt_second <= 32'd0;
        da0clk <= ~da0clk;
    end
    else
    begin
        clk_cnt_second <= clk_cnt_second + 1'b1;
        da0clk <= da0clk;
    end
    assign DA0_clk_data = da0clk;
    
/* ===================[DA0_runmode] ========================= */
    // DA0's runmode changes when da0_data finds its high peaks
    // ________--------________--------
    always@(posedge DA0_clk_data)
    begin
        if(~EN_MACHINE_RUNNING)
            begin
                DA0_runmode <= 1'b1;
            end
        else if(da0_data > DA0_MAX - DA0_stepheight)
            begin
                DA0_runmode <= 1'b0;
            end
        else if(da0_data < DA0_MIN + DA0_stepheight)
            begin
                DA0_runmode <= 1'b1;
            end
    end

/* ===================[da0_data] ========================= */
    // Do not change while disabled or DA1 is chaning
    always@(posedge DA0_clk_data) 
    begin
        if(~EN_MACHINE_RUNNING)
            begin
                da0_data <= DA0_MIN;
            end
        //else if(DA1_change_flag)DA1_clk_data
        else if(DA1_clk_data)
            begin
                da0_data <= da0_data;
            end
        else if(DA0_runmode && da0_data >= DA0_MAX - DA0_stepheight)
            begin
                da0_data <= DA0_MAX;
            end
        else if(~DA0_runmode && da0_data <= DA0_MIN + DA0_stepheight)
            begin
                da0_data <= DA0_MIN;
            end
        else if(DA0_runmode)
            begin
                da0_data <= da0_data + DA0_stepheight;
            end
        else if(~DA0_runmode)
            begin
                da0_data <= da0_data - DA0_stepheight;
            end
        else
            begin
                da0_data <= da0_data;
            end
    end
    
/* ===================[DA1_clk_data] ========================= */
    // Delay DA0 runmode to capture DA0's high peaks
    // Use this signal to lead DA1's change
    // --------________--------
    always@(posedge DA0_clk_data)
        DA0_runmode_dly <= DA0_runmode;
    assign DA1_clk_data = (DA0_runmode_dly && ~DA0_runmode);
       
/* ===================[SCAN_END] ========================= */
    // use counter to delay while scanning end reached
    always@(posedge Clk or negedge RST_N)
    begin
        if(~RST_N)
            begin
                cnt_scan_end <= 32'd0;
                SCAN_END <= 1'b0;
            end
        else if(SCAN_END_early && cnt_scan_end == MODE_FREQUENCY_second)
            begin
                cnt_scan_end <= cnt_scan_end;
                SCAN_END <= 1'b1;
            end
        else if(SCAN_END_early)
            begin
                 cnt_scan_end <= cnt_scan_end + 1'b1;
                 SCAN_END <= SCAN_END;
            end
         else
            SCAN_END <= 1'b0;
    end
    
    
/* ===================[SCAN_END_early da1_data] ========================= */ 
    // make DA1 change and generate ending signal   
    always@(negedge DA1_clk_data) 
    begin
        if(~EN_MACHINE_RUNNING)
            begin
                da1_data <= DA1_MIN;
            end
        else if(da1_data >= DA1_MAX - DA1_stepheight)
            begin
                da1_data <= DA1_MAX;
                SCAN_END_early <= 1'b1;
            end
        else if(da1_data < DA1_MIN)
            begin
                da1_data <= DA1_MIN;
            end
        else
            begin
                da1_data <= da1_data + DA1_stepheight;
            end
    end
    
/* ===================[DA1_change_flag] =========================  
    // make DA1 change time hold for 2 period of set hold time
    // use DA1_change_flag_2 to make DA1 change in the second half of its hold time      
    assign DA1_change_flag_2 = (DA1_change_timecnt > HOLD_TIME_CHANGE);
    always@(posedge DA0_clk_data)
    begin
        if(~DA1_change_flag && DA1_clk_data)//no chaning time but detect change and change is upping 
            begin
                DA1_change_flag <= 1'b1;
            end
        else if(DA1_change_flag && DA1_change_timecnt == HOLD_TIME_CHANGE + HOLD_TIME_CHANGE)//already chaging but time is over
            begin
                DA1_change_flag <= 1'b0;
            end
        else
            begin
                DA1_change_flag <= DA1_change_flag;// othertime hold
            end
    end
    // DA1_change_flag hold time
    // use counter to make hold time delay
    always@(posedge DA0_clk_data)
    begin
        if(~DA1_clk_data)
            begin
                DA1_change_timecnt = 32'd0;
            end
        //else if(DA1_change_timecnt == HOLD_TIME_CHANGE + HOLD_TIME_CHANGE)//upping but timeout
        //    begin
        //        DA1_change_timecnt <= DA1_change_timecnt;
        //    end
        else if(DA1_change_flag)//upping and wait time
            begin
                DA1_change_timecnt <= DA1_change_timecnt + 1'b1;
            end
        else
            begin
                DA1_change_timecnt <= DA1_change_timecnt;
            end
    end
*/
/* ===================[DA0_change_flag] ========================= */ 
    // make DA0 change time hold for 1 period of set hold time
    assign DA0_change_flag = 1'b0;
/*    always@(posedge Clk)
    begin
        if(~DA0_change_flag && DA0_clk_data)//no chaning time but detect change and change is upping 
            begin
                DA0_change_flag <= 1'b1;
            end
        else if(DA0_change_flag && DA0_change_timecnt == HOLD_TIME_CHANGE)//already chaging but time is over
            begin
                DA0_change_flag <= 1'b0;
            end
        else
            begin
                DA0_change_flag <= DA0_change_flag;// othertime hold
            end
    end
    // DA0_change_flag hold time
    // use counter to make hold time delay
    always@(posedge Clk)
    begin
        if(DA0_change_flag && DA0_change_timecnt == HOLD_TIME_CHANGE)//upping but timeout
            begin
                DA0_change_timecnt <= 32'd0;
            end
        else if(DA0_change_flag)//upping and wait time
            begin
                DA0_change_timecnt <= DA0_change_timecnt + 1'b1;
            end
        else
            begin
                DA0_change_timecnt <= DA0_change_timecnt;
            end
    end
*/
/* ===================[CURRENT_AD] ========================= */
    // before the system start, catch the adc_current
        // cal result of current // initial the current
    reg  [31:0]current_ad = 32'd0;
    reg  [15:0]ad_delta = 16'd2621;
    // the low 16 bit used to compare with ad0_data
    // wire [15:0]CURRENT_AD; 4.8
    reg  [15:0]CURRENT_AD = 16'h3fff;
    reg  [15:0]adc_data1 = 0;
    reg  [15:0]adc_data2 = 0;
    reg  [15:0]adc_data3 = 0;
    reg  [15:0]adc_data4 = 0;
    reg  [15:0]adc_data5 = 0;
    reg  [15:0]adc_data6 = 0;
    reg  [15:0]adc_data7 = 0;
    reg  [15:0]adc_data8 = 0;
    // assign CURRENT_AD = (~EN_MACHINE_RUNNING) ? current_ad[15:0]
    //                                           : current_ad[15:0] - ad_delta;
    //25.4.8 try git
    always@(posedge Clk)
        if(~EN_MACHINE_RUNNING)
            CURRENT_AD <= current_ad[15:0];
        else 
            CURRENT_AD <= current_ad[15:0] - ad_delta;
    
    // Try to get current of 32 ad_data at the DA2 upping time
    always@(posedge DA2_clk_data or negedge RST_N)
        if(~RST_N)
            begin
                current_ad <= 32'd0;// protect system
            end
        else if(~EN_MACHINE_RUNNING)
            begin
                current_ad <= (adc_data1 + adc_data2 + adc_data3 + adc_data4 + adc_data5 + adc_data6 + adc_data7 + adc_data8)>>3;
                adc_data1  <= ad0_data ;
                adc_data2  <= adc_data1; 
                adc_data3  <= adc_data2; 
                adc_data4  <= adc_data3;
                adc_data5  <= adc_data4; 
                adc_data6  <= adc_data5; 
                adc_data7  <= adc_data6;
                adc_data8  <= adc_data7;
         end
         else
                current_ad <= current_ad;
   
/* ===================[CURRENT_AD] running========================= */
    // after the system start, smooth the adc_current
    reg  [31:0]current_ad_run = 32'd0;
    // the low 16 bit used to compare with ad0_data
    wire [15:0]CURRENT_AD_run;
    reg  [127:0]adc_data_run_transmit = 0;
    assign CURRENT_AD_run = current_ad_run[15:0];
    // assign CURRENT_AD_run = ad0_data[15:0];
    
    // Try to get current of 32 ad_data at the DA2 upping time
    always@(posedge DA2_clk_data or negedge RST_N)
        if(~RST_N)
            begin
                current_ad_run <= {16'd0, ad0_data};// protect system
            end
        else// if(~EN_MACHINE_RUNNING)
            begin
                current_ad_run <= (ad0_data                      +
                                   adc_data_run_transmit[31:16]  + 
                                   adc_data_run_transmit[47:32]  +
                                   adc_data_run_transmit[63:48]  +
                                   adc_data_run_transmit[79:64]  +
                                   adc_data_run_transmit[95:80]  +
                                   adc_data_run_transmit[111:96] +
                                   adc_data_run_transmit[127:112]
                                   )>>3;
                adc_data_run_transmit[15:0]    <= ad0_data                     ;
                adc_data_run_transmit[31:16]   <= adc_data_run_transmit[15:0]  ; 
                adc_data_run_transmit[47:32]   <= adc_data_run_transmit[31:16] ;
                adc_data_run_transmit[63:48]   <= adc_data_run_transmit[47:32] ;
                adc_data_run_transmit[79:64]   <= adc_data_run_transmit[63:48] ;
                adc_data_run_transmit[95:80]   <= adc_data_run_transmit[79:64] ;
                adc_data_run_transmit[111:96]  <= adc_data_run_transmit[95:80] ;
                adc_data_run_transmit[127:112] <= adc_data_run_transmit[111:96];
         end 

/* ===================[ad0_up] ========================= */ 
    // follow the adc input while running
    //assign ad0_up = (~EN_MACHINE_RUNNING) ? 1'b1
    //                :(ad0_data >= CURRENT_AD + SET_THRESHOLD) ? 1'b1
    //                :(ad0_data <= CURRENT_AD - SET_THRESHOLD) ? 1'b0
    //                : 1'b1;
    
    always@(posedge Clk)
        if(~EN_MACHINE_RUNNING)
            ad0_up <= 1'b1;
        else if(ad0_data >= CURRENT_AD + SET_THRESHOLD)
            ad0_up <= 1'b1;
        else if(ad0_data <= CURRENT_AD - SET_THRESHOLD)
            ad0_up <= 1'b0;
        else 
            begin
                ad0_up <= ad0_up;
            end
    
/* ===================[DA2_Ending] ========================= */ 
    // make sure:
    // while running: DA2_Ending = da2_data
    // while ending : DA2_Ending downing
    always@(posedge DA2_clk_data)
        if(SCAN_END && DA2_Ending < DA_0V + DA2_stepheight)
            begin
                DA2_Ending <= DA_0V;
            end
        else if(SCAN_END && DA2_Ending >= DA_0V + DA2_stepheight)
            begin
                DA2_Ending <= DA2_Ending - DA2_stepheight;
            end
        else if(SCAN_END)
            begin
                DA2_Ending <= DA_0V;
            end
        else
            begin
                DA2_Ending <= da2_data;
            end
          
/* ===================[DA0_Ending] ========================= */ 
    // make sure:
    // while running: DA0_Ending = da0_data
    // while ending : DA0_Ending downing after DA2
    always@(posedge DA2_clk_data)//========22:23
        if(EN_MACHINE_RUNNING && ~SCAN_END)
            DA0_Ending <= da0_data;
        else if(SCAN_END && DA2 != DA_0V)//wait for DA2 already closed
            DA0_Ending <= DA0_Ending;
        else if(SCAN_END && DA0_Ending < DA_0V + DA0_stepheight)
            begin
                DA0_Ending <= DA_0V;
            end
        else if(SCAN_END && DA0_Ending >= DA_0V + DA0_stepheight)
            begin
                DA0_Ending <= DA0_Ending - DA0_stepheight;
            end
        else if(SCAN_END)//before sttart
            begin
                DA0_Ending <= DA_0V;
            end
    
/*================== [DA2 & DA0] Ports output switch for DA2 & DA0 ================== */
    // make sure DAports output right
    // capture the fluse of AD1
    
    assign DA2 = (~EN_MACHINE_RUNNING) ? DA2_MIN
                : (EN_MACHINE_RUNNING && ~SCAN_END) ? da2_data
                : (EN_MACHINE_RUNNING && SCAN_END)  ? DA2_Ending
                : DA2_Ending;
    
    always@(posedge DA2_clk_data)//DA2_clk_data)
    if(~EN_MACHINE_RUNNING)
        // before start, make sure deflaut state
        begin
            ad0_data <= AD0;
            DA0 <= DA0_MIN;
            //DA2 <= DA2_MIN;
        end
        //running, output
    else if(EN_MACHINE_RUNNING && ~SCAN_END)
        begin
            ad0_data <= AD0;
            DA0 <= da0_data;
            //DA2 <= da2_data;
        end
        // closing after scanning
    else if(EN_MACHINE_RUNNING && SCAN_END)
        begin
            ad0_data <= AD0;
            DA0 <= DA0_Ending;
            //DA2 <= DA2_Ending;
        end
 
/* ===================[DA1_Ending] ========================= */ 
    // make sure:
    // while running: DA1_Ending = da1_data
    // while ending : DA1_Ending downing after DA2 and DA0
    always@(posedge DA2_clk_data)
        if(EN_MACHINE_RUNNING && ~SCAN_END)
            DA1_Ending <= da1_data;
        else if(DA2 != DA_0V || DA0 != DA_0V)//wait for DA2 DA0 already closed
            DA1_Ending <= DA1_Ending;
        else if(SCAN_END && DA1_Ending < DA_0V + DA1_stepheight)
            begin
                DA1_Ending <= DA_0V;
            end
        else if(SCAN_END && DA1_Ending >= DA_0V + DA1_stepheight)
            begin
                DA1_Ending <= DA1_Ending - DA0_stepheight;
            end
        else
            begin
                DA1_Ending <= da1_data;
            end   
            
/* ==================[DA1] Ports output switch for DA1================== */
    always@(posedge DA2_clk_data)
    begin
        if(EN_MACHINE_RUNNING && SCAN_END)
            DA1 <= DA1_Ending;
        else if(~EN_MACHINE_RUNNING)
            DA1 <= DA1_MIN;
        else if(DA1_change_flag_2)
            DA1 <= da1_data;
        else
            DA1 <= DA1;
    end

/*======================[Pct_out]==================*/
reg [31:0]freq_pct = 25;// read clk = 50M/(fre*2), sin wave period = read clk / 10k
test_sinwave test_sinwave(
    .clk(Clk),//50MHz
    .freq(freq_pct),
    
    .sin_data(Pct_out)
    );

/* ================= UART module ================= */
    // 0: 9600 baud rate
    reg [2:0]BAUD_SET = 3'd0;

    wire [7:0]RX_DATA;
    wire RX_DONE;

    reg [7:0]TX_DATA = 8'b0;
    wire TX_DONE;
    reg EN_TX = 1'b0;

    wire CMD_VALID;
    wire [39:0]CMD_40;

    //UART ports
    uart_byte_rx uart_byte_rx (
        .clk(Clk),
        .reset_n(RST_N),

        .baud_set(BAUD_SET),
        .uart_rx(rx),

        .data_byte(RX_DATA),
        .rx_done(RX_DONE)
    );

    uart_byte_tx uart_byte_tx(
        .clk(Clk),
        .reset_n(RST_N),
    
        .data_byte(TX_DATA),

        .send_en(EN_TX),  
        .baud_set(BAUD_SET),  
        
        .uart_tx(tx),  
        .tx_done(TX_DONE),
        .uart_state() 
    );

    bit8_trans_bit40 bit8_trans_bit40(
        .clk(Clk),
        .rst_n(RST_N),

        .bit8_in(RX_DATA),
        .bit8_in_valid(RX_DONE),

        .bit40_out(CMD_40),
        .bit40_out_valid(CMD_VALID)
    );

/* ================= Thumb check and set paramter ================= */
    //check all data's width while changing devices
    always @(posedge Clk) 
        if(CMD_VALID && CMD_40 == 40'h5533553355)//open machine
            begin
                EN_MACHINE_RUNNING <= 1'b1;
                TX_DATA  <= CMD_40[39:32];
                EN_TX    <= 1'b1;
            end
        else if(CMD_VALID && CMD_40 == 40'hEE11EE11EE)//stop (default)
            begin
                EN_MACHINE_RUNNING <= 1'b0;
                TX_DATA  <= CMD_40[39:32];
                EN_TX    <= 1'b1;
            end
        else if(CMD_VALID)begin
            case(CMD_40[39:32])
                8'hFC: //set frequency adc&da2  FC 00 00 09 C4
                    begin
                        MODE_FREQUENCY <= CMD_40[31:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
                8'hCF: //set frequency da0 da1  FC 00 03 D0 90
                    begin
                        MODE_FREQUENCY_second <= CMD_40[31:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
                8'hA0: //set threshold  A0 00 00 06 40
                    begin
                        SET_THRESHOLD <= CMD_40[AD_WIDTH - 1:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
                8'hA9: //set threshold  A0 00 00 0C 80
                    begin
                        ad_delta <= CMD_40[AD_WIDTH - 1:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
                //DA2----
                8'hB0: //set DA2 MIN & MAX
                    begin
                        DA2_MIN <= CMD_40[15 + DA_WIDTH:16];
                        DA2_MAX <= CMD_40[DA_WIDTH - 1:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
                8'hB5: //set DA2 STEP
                    begin
                        DA2_stepheight <= CMD_40[DA_WIDTH - 1:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
                //DA0----
                8'hD1: //set DA2 MIN & MAX
                    begin
                        DA0_MIN <= CMD_40[15 + DA_WIDTH:16];
                        DA0_MAX <= CMD_40[DA_WIDTH - 1:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
                8'hD6: //set DA2 STEP
                    begin
                        DA0_stepheight <= CMD_40[DA_WIDTH - 1:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
                //DA0----
                8'hE2: //set DA2 MIN & MAX
                    begin
                        DA1_MIN <= CMD_40[15 + DA_WIDTH:16];
                        DA1_MAX <= CMD_40[DA_WIDTH - 1:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
                8'hE8: //set DA2 STEP
                    begin
                        DA1_stepheight <= CMD_40[DA_WIDTH - 1:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end 
                8'hA5: //set pct freq
                    begin
                        freq_pct <= CMD_40[31:0];
                        TX_DATA  <= CMD_40[39:32];
                        EN_TX    <= 1'b1;
                    end
            endcase		
        end
        else
            begin
                EN_TX    <= 1'b0;
                TX_DATA  <= 8'h00;
            end

/* ================= ETH module ================= */
    // record all devices's reg for 1MHz
    // use eth send to uppermachine
    // set dst_ip 192.168.0.3 2599
    // need to get the destinnation's mac ip
    // cautions:enable all times, need to check the ram of upmachine
    fifo_send_ethernet fifo_send_ethernet(
        .clk50M(Clk),
        .DIV_FROM_50M(MODE_FREQUENCY_second),
        
        .EN_MACHINE_RUNNING(EN_MACHINE_RUNNING),
        
        .reset_n(RST_N),
        
        .AD0({ad0_data}),
        .DA2({DA2}),
        .DA0({DA0}),
        .DA1({DA1}),
        //.AD0(16'hAABB),
        //.DA2(16'hCCDD),
        //.DA0(16'hEEFF),
        //.DA1(16'h5577),
        
        .led(led),
        .eth_reset_n(eth_reset_n),
        
        .gmii_tx_clk(gmii_tx_clk),
        .gmii_txd(gmii_txd),
        .gmii_txen(gmii_txen)
        );


endmodule
