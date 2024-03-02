`timescale 1ps/1ps
module geofence ( clk,reset,X,Y,valid,is_inside);
  input clk;
  input reset;
  input [9:0] X;
  input [9:0] Y;
  output reg valid;
  output reg is_inside;





  reg me;
  reg  signed [11:0] ma,mb;
  wire signed [23:0] mo; 
  wire mv;

  multi_div #(
    .SIZE_A(12),
    .SIZE_B(12),
    .SIGNED(1),
    .STEP_SIZE(1) 
  ) multi_u1(
    .clk(clk),.reset(reset),
    .en(me),
    .select(1'b0),
    .a(ma),
    .b(mb),
    .P(mo),
    .div_zero(),
    .Valid(mv),
    .Busy()
  );

  



  
  reg [2:0] state;
  reg [2:0] state_counter_0,state_counter_1;
  reg [2:0] state_step;

  reg [9:0] check_point [1:0];
  reg [9:0] geofence_point [5:0][1:0];
  reg       check_signed;

  reg signed [26:0] DATA_REG;



  parameter READ_DATA     = 0;
  parameter SORT_POINT    = 1;
  parameter CHECK_IN_SIDE = 2;
  parameter DATA_OUT      = 3;

  
  integer i;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= READ_DATA;
      state_step <= 0;
      state_counter_0 <= 0;
      state_counter_1 <= 0;
      me <= 0;
      is_inside <= 1;
    end else begin
      case (state)
        
        READ_DATA:begin
          if(state_counter_0==0)begin
            check_point[0] <= X;
            check_point[1] <= Y;
            state_counter_0 <= state_counter_0 + 1;
          end
          else begin

            if(state_counter_0 == 6)begin
              state <= SORT_POINT;
              state_counter_0 <= 1;
              state_counter_1 <= 2;
              me <= 0;
            end
            else state_counter_0 <= state_counter_0 + 1;

            geofence_point[state_counter_0-1][0] <= X;
            geofence_point[state_counter_0-1][1] <= Y;

          end 
        
        end











        
        SORT_POINT:begin
          case(state_step)


            0:begin
              ma <= (geofence_point[state_counter_0][0] - geofence_point[0][0]) ; //AX
              mb <= (geofence_point[state_counter_1][1] - geofence_point[0][1]) ; //BY
              me <= 1;
              state_step <= state_step + 1;
            end


            1:begin
              me <= 0;

              if(mv)begin
                me <= 1;
                DATA_REG <= mo; 
                state_step <= state_step + 1;
                ma <= (geofence_point[state_counter_0][1] - geofence_point[0][1]) ; //AY
                mb <= (geofence_point[state_counter_1][0] - geofence_point[0][0]) ; //BX
              end

            end


            2:begin
              me <= 0;

              if(mv)begin
                DATA_REG <= $signed($signed(DATA_REG)-$signed(mo));
                state_step <= state_step + 1;
              end
            end
            3:begin
                //$display("i%d j%d DATA_REG:%d",state_counter_0,state_counter_1,DATA_REG);
                if( $signed(DATA_REG) <= 0 )begin
                  geofence_point[state_counter_0][0] <= geofence_point[state_counter_1][0]; 
                  geofence_point[state_counter_0][1] <= geofence_point[state_counter_1][1]; 
                  geofence_point[state_counter_1][0] <= geofence_point[state_counter_0][0]; 
                  geofence_point[state_counter_1][1] <= geofence_point[state_counter_0][1]; 
                end
              state_step <= state_step + 1;
            end
            4:begin

              if(state_counter_0==4)begin
                state <= CHECK_IN_SIDE;
                state_counter_0 <= 0;
                state_counter_1 <= 0;
                //test
                //for(i=0;i<6;i=i+1)begin
                //  $display("geofence_point[%d][0]:%d,geofence_point[%d][1]:%d",i,geofence_point[i][0],i,geofence_point[i][1]);
                //end
                //test
              end
              else if(state_counter_1==5)begin
                state_counter_0 <= state_counter_0 + 1;
                state_counter_1 <= state_counter_0 + 2;
                
              end 
              else begin
                state_counter_1 <= state_counter_1 + 1;
              end

              state_step <= 0;
            end
          endcase
        end














        CHECK_IN_SIDE:begin
          case(state_step)
            // Check[0]
            0:begin 
              ma <= (geofence_point[state_counter_0][0] - check_point[0] );
              mb <= (geofence_point[ ((state_counter_0+1)==6 ? 0:(state_counter_0+1)) ][1] - geofence_point[state_counter_0][1] );
              //#1 $display("%d %d",ma,mb);
              me <= 1;
              state_step <= state_step + 1;
            end

            1:begin
              me <= 0;
              if(mv)begin
                DATA_REG <= mo;
                state_step <= state_step + 1;
              end
            end

            2:begin
              ma <= (geofence_point[state_counter_0][1] - check_point[1] );
              mb <= (geofence_point[ ((state_counter_0+1)==6 ? 0:(state_counter_0+1)) ][0] - geofence_point[state_counter_0][0]);
              //$display("%d %d",geofence_point[ ((state_counter_0+1)==6 ? 0:(state_counter_0+1)) ][0] , geofence_point[state_counter_0][0]);
              //#1 $display("%d %d",ma,mb);
              me <= 1;
              state_step <= state_step + 1;
            end

            3:begin
              me <= 0;
              if(mv)begin
                //$display("state:%d pass value:%d",state_counter_0,($signed(DATA_REG)-$signed(mo)));
                if(state_counter_0==0) begin
                  check_signed <= (($signed(DATA_REG)-$signed(mo))>0)? 1:0;
                  state_counter_0 <= state_counter_0 + 1;
                end
                else begin
                  if(check_signed != ((($signed(DATA_REG)-$signed(mo))>0)? 1:0) )begin
                    is_inside <= 0;
                    state <= DATA_OUT;
                  end else if(state_counter_0==5)begin
                    state <= DATA_OUT;
                  end else begin
                    state_counter_0 <= state_counter_0 + 1;
                  end
                  
                end
                state_step <= 0;
              end
            end




            

          endcase
        end

        default begin
          state <= READ_DATA;
          state_step <= 0;
          state_counter_0 <= 0;
          state_counter_1 <= 0;
          me <= 0;
          is_inside <= 1;
        end



      endcase
    end
  end


  always@(*)begin
    valid <= (state == DATA_OUT) ? 1'b1:1'b0;
  end

endmodule


















// File Name:
//  mulit_div.v
//
// Interface:
//  
//  Author:
//    CHONG-HAO XU
//
//  Descritpion:
//    select: multi : 0
//            div   : 1   
//    


module multi_div
#(
  parameter SIZE_A = 128,
  parameter SIZE_B = 64,
  parameter SIGNED = 0,
  parameter STEP_SIZE = 1 
)(
  input wire clk,reset,
  input wire en,
  input wire select,
  input wire [SIZE_A-1:0] a,
  input wire [SIZE_B-1:0] b,
  output reg [SIZE_A+SIZE_B-1:0] P,
  output reg div_zero,
  output reg Valid,
  output reg Busy
);

  parameter READ_IN       = 0,
            CALCULATE     = 1,
            PREPARE_DATA  = 2,
            DATA_OUT      = 3;


  reg [1:0] state;
  reg [9:0] state_counter;
  
  reg neg_signed;

  reg [SIZE_A-1:0] data_b;
  reg [SIZE_A+SIZE_B:0] r;  //a + 1'b0 + SIZE_B'b0

  always@(*)begin
    Valid <= (state == DATA_OUT) ? 1'b1:1'b0;
    Busy  <= (state == CALCULATE || state == PREPARE_DATA) ? 1'b1:1'b0;
  end


  always@(posedge clk or posedge reset)begin
    if(reset)begin
      state <= READ_IN;
      state_counter <= 0;
    end else begin
      case(state)
        
        
        READ_IN   :begin
          if(en)begin

            if(select && b==0)begin
              state <= DATA_OUT;
              div_zero <= 1;
            end else begin
              state <= CALCULATE;
              div_zero <= 0;
            end 
            state_counter <= 0;

          end  
        end
        
        
        
        
        CALCULATE :begin
          

          if(state_counter == (SIZE_A/STEP_SIZE)-1)begin
            state <= PREPARE_DATA;
            state_counter <= 0;
          end
          else begin
            state_counter <= state_counter + 1;
          end

        end
        
        

        PREPARE_DATA:begin
          state <= DATA_OUT;
          state_counter <= 0;
        end
        
        
        DATA_OUT  :begin
          state <= READ_IN;
          state_counter <= 0;
        end
        
        
        default begin
          state <= READ_IN;
          state_counter <= 0;
        end

      endcase
    end
  end



  reg [SIZE_A-1:0] na;
  reg [SIZE_B-1:0] nb;

  reg in_select;
  integer i;
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      r = 0;
      data_b = 0;
			P = 0;
      neg_signed = 0;
    end else begin


      case(state)
        
        READ_IN   :begin
          if(en)begin
            
            if(SIGNED)begin
              neg_signed = a[SIZE_A-1] ^ b[SIZE_B-1];
              na = a[SIZE_A-1] ? -a:a;
              nb = b[SIZE_B-1] ? -b:b;
            end
            else begin
              na = a;
              nb = b;
            end

            r = {na,1'b0,{SIZE_B{1'b0}}};
            data_b = nb;
            in_select = select;

          end  
        end
        
        
        
        
        CALCULATE :begin

          for(i=0;i<STEP_SIZE;i=i+1)begin 
          	r = r[SIZE_A+SIZE_B] ? ((r<<1)+data_b) : (r<<1);
          end
        end

        PREPARE_DATA:begin
          
          P = r[SIZE_A+SIZE_B-1:0];
          
          if(neg_signed)begin
            P = -P;
          end
        end

      endcase
    end
  end




endmodule
