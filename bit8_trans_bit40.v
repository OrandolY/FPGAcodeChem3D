//8bit_40bit
module bit8_trans_bit40(
  input            clk,
  input            rst_n,

  input      [7:0] bit8_in,//RX_DATA
  input            bit8_in_valid,//RX_DONE

  output reg [39:0]bit40_out,
  output reg       bit40_out_valid
);

  reg [3:0]bit8_cnt;//
  reg [39:0]data_lock;//

  //5�?8bit 计数
  always@(posedge clk or negedge rst_n)
  begin
    if(!rst_n)
      bit8_cnt <= 1'b0;
	 else if(bit8_cnt == 5)
	   bit8_cnt <= 1'b0;	
    else if(bit8_in_valid)
      bit8_cnt <= bit8_cnt + 1'b1;
    else
      bit8_cnt <= bit8_cnt;
  end

  
  always@(posedge clk or negedge rst_n)
  begin
    if(!rst_n)
     data_lock <= 40'd0;
    else if(bit8_in_valid)
     data_lock <= {data_lock[31:0],bit8_in};
    else
     data_lock <= data_lock;
  end
  
  //40bit输出
  always@(posedge clk or negedge rst_n)
  begin
    if(!rst_n)
      bit40_out <= 40'd0;
    else if(bit8_cnt == 5)
      bit40_out <= data_lock[39:0];
    else
      bit40_out <= bit40_out;
  end

  always@(posedge clk or negedge rst_n)
  begin
    if(!rst_n)
      bit40_out_valid <= 1'b0;
    else if (bit8_cnt == 5)
      bit40_out_valid <= 1'b1;
    else
      bit40_out_valid <= 1'b0;
  end

endmodule 