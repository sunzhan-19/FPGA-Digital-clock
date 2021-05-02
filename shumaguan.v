//clock带闹钟，带整点报时,上下午显示，12/24小时制，报整点时数
`timescale 1ns / 1ps
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Company: HUST
// Engineer: Sunzhan
// 
// Create Date: 2021/03/15 19:12:58
// Design Name: DIGITAL CLOCK
// Module Name: DIGITAL CLOCK
// Project Name: DIGITAL CLOCK
// Tool Versions: Vivado.2018.3

module top_clock (
    input                   clk,//100M
    input                   nCLR,EN,//清零，使能
    input                   Adj_Min,Adj_Hour,Hour_CRL,//分钟调整，小时调整，12/24进制控制
    input                   SET_CLOCK,//闹钟设置
    input                   CLOSE,//闹钟关闭
    output   wire           LED,//秒针闪烁
    output   wire   [7:0]   AN,//数码管使能
    output   wire   [7:0]   HEX,//数码管数据
    output   reg            AUDIO//MONO AUDIO OUT
);
    wire                    Hour_EN,MinH_EN,MinL_EN;
    wire     [7:0]          Hour_24,Hour_12,Hour_24_CLOCK,Hour_12_CLOCK;
    wire     [31:0]         iDIG;//译码管数据
    wire                    CLK_1HZ;
    wire                    CLK_500HZ;
    wire                    CLK_1000HZ;
    supply1                 VDD;//电平1
    wire                    AP_TIME,AP_CLOCK;//当前时间上下午，闹钟上下午
    wire     [7:0]          Hour,Minute,Second;
    wire     [7:0]          Minute_CLOCK;//闹钟分钟
    reg      [23:0]         CLOCK;//闹钟：AP_CLOCK+Hour+Minute
    reg                     music_begin;//闹钟音乐开始标志
    wire                    music;//闹钟音乐
    wire     [4:0]          Hour_audio_cnt;//小时10进制计数
    reg                     Hour_Audio_begin;//整点报时音乐开始标志
    wire                    HOUR_AUDIO;//整点报时音乐
    //-----------------分频---------------//
    Divider_XHZ divider_1HZ(nCLR,clk,CLK_1HZ);
    defparam divider_1HZ.OUT_Freq=1;
    
    Divider_XHZ divider_500HZ(nCLR,clk,CLK_500HZ);
    defparam divider_500HZ.OUT_Freq=500;
    
    Divider_XHZ divider_1000HZ(nCLR,clk,CLK_1000HZ);
    defparam divider_1000HZ.OUT_Freq=1000;   
    //------------------------ -----------//

    assign LED=CLK_1HZ;//秒针LED灯闪烁

    //----------------------------------  同步时钟  -------------------------------//   
    counter_10 S0(CLK_1HZ,nCLR,EN,Second[3:0]);
    counter_6  S1(CLK_1HZ,nCLR,(Second[3:0]==4'h9),Second[7:4]);//秒
        
    counter_10 S2(CLK_1HZ,nCLR,MinL_EN,Minute[3:0]);
    counter_6  S3(CLK_1HZ,nCLR,MinH_EN,Minute[7:4]);//分
    assign MinL_EN=(Adj_Min&&(~SET_CLOCK))?VDD:(Second==8'h59);
    assign MinH_EN=(Adj_Min&&(Minute[3:0]==4'h9)&&(~SET_CLOCK))||(Minute[3:0]==4'h9)&&(Second==8'h59);

    counter_24Hours H0(CLK_1HZ,nCLR,Hour_EN,Hour_24[7:4],Hour_24[3:0]);
    counter_12Hours H1(CLK_1HZ,nCLR,Hour_EN,Hour_12[7:4],Hour_12[3:0]);//时
    assign  Hour_EN=(Adj_Hour&&(~SET_CLOCK))?VDD:((Minute==8'h59)&&(Second==8'h59));
    //----------------------------------------------------------------------------//
    
    //--------------------------------    闹钟设置      -----------------------------------//
    counter_10 S4(CLK_1HZ,nCLR,Adj_Min&&SET_CLOCK,Minute_CLOCK[3:0]);//CLOCK_SET
    counter_6  S5(CLK_1HZ,nCLR,Adj_Min&&SET_CLOCK&&(Minute_CLOCK[3:0]==4'h9),Minute_CLOCK[7:4]);//CLOCK_SET
    
    counter_24Hours H3(CLK_1HZ,nCLR,Adj_Hour&&SET_CLOCK,Hour_24_CLOCK[7:4],Hour_24_CLOCK[3:0]);//CLOCK_SET
    counter_12Hours H4(CLK_1HZ,nCLR,Adj_Hour&&SET_CLOCK,Hour_12_CLOCK[7:4],Hour_12_CLOCK[3:0]);//CLOCK_SET
    //-------------------------------------------------------------------//
    
    //----------------------  上下午显示AM&PM  -------------------//
    AP_Hour AP1_12(CLK_1HZ,nCLR,Hour_EN,AP_TIME);//时间AP
    AP_Hour AP2_12(CLK_1HZ,nCLR,Adj_Hour&&SET_CLOCK,AP_CLOCK);//闹钟AP
    //-----------------------------------------------------------// 

    //----------------------------------译码管数据控制及显示---------------------------------//
    assign    Hour[7:4]=SET_CLOCK?((Hour_CRL==1)?Hour_24_CLOCK[7:4]:Hour_12_CLOCK[7:4]) : ((Hour_CRL==1)?Hour_24[7:4]:Hour_12[7:4]);
    assign    Hour[3:0]=SET_CLOCK?((Hour_CRL==1)?Hour_24_CLOCK[3:0]:Hour_12_CLOCK[3:0]) : ((Hour_CRL==1)?Hour_24[3:0]:Hour_12[3:0]);

    assign    iDIG[31:24]=SET_CLOCK?(AP_CLOCK?(8'hbc):(8'hac)):(AP_TIME?(8'hbc):(8'hac));
    assign    iDIG[23:20]=Hour[7:4];    
    assign    iDIG[19:16]=Hour[3:0];    
    assign    iDIG[15:12]=SET_CLOCK?Minute_CLOCK[7:4]:Minute[7:4];
    assign    iDIG[11:8]=SET_CLOCK?Minute_CLOCK[3:0]:Minute[3:0];
    assign    iDIG[7:4]=Second[7:4];
    assign    iDIG[3:0]=Second[3:0];
    
    SEG7_LUT_8 SEG7_LUT_JISHU( clk, nCLR, iDIG, AN, HEX);//译码管显示
    //--------------------------------------------------------------------------------------//

    //-------------------------------报整点时数------------------------------------//
    hour_audio HourAudio(CLK_1HZ,nCLR,Hour_EN,Hour_CRL,Hour_audio_cnt);//小时十进制计数
    HOUR_BEGIN HB1(clk,CLK_1HZ,Hour_Audio_begin,Hour_audio_cnt,HOUR_AUDIO);//报时音频输出
    //----------------------------------------------------------------------------//

    //-----------------------闹钟音乐输出----------------------//
    audio_music music_xx(clk,music_begin,music);//闹钟音乐输出
    //-----------------------------------------------------//

    //-------------------------- 闹钟寄存，闹钟音乐开始控制，整点报时数控制 -------------------------//
    always@(posedge clk)//闹钟寄存
         begin if(~nCLR)
                 CLOCK<=24'hac6000;
                else if(SET_CLOCK)
                 CLOCK<={AP_CLOCK,Hour,Minute_CLOCK};
                else begin
                CLOCK<=CLOCK;
                music_begin<=((!SET_CLOCK)&&CLOCK=={AP_TIME,Hour,Minute}&&(Second==8'h00))?0:1;
                Hour_Audio_begin<=(Minute[7:4]==5 && Minute[3:0]==9 && Second[7:4]==5 && Second[3:0]==9)?0:1;
                end
               
    end
    //--------------------------------------------------------------------------------------------//

    //-----------------------------------音频输出控制--------------------------------//
    always@(CLK_1HZ)//MONO AUDIO OUT
        begin 
            if((!SET_CLOCK)&&CLOCK=={AP_TIME,Hour,Minute}&&(Second<=8'h59)&&(~CLOSE))
                AUDIO<=music;     //闹钟音乐
        	else if(Minute[7:4]==5 && Minute[3:0]==9 && Second[7:4]==5 && (Second[3:0]==1||Second[3:0]==3||Second[3:0]==5||Second[3:0]==7))
        		AUDIO<=CLK_500HZ; //整点前低音*4
        	else if(Minute[7:4]==5 && Minute[3:0]==9 && Second[7:4]==5 && Second[3:0]==9)
        	    AUDIO<=CLK_1000HZ;//整点前高音*1
           else if(Minute[7:4]==0 && Minute[3:0]==0 && Second[7:4]<=2&&Second[3:0]<=9)
                AUDIO<=HOUR_AUDIO;//报整点时数
        	else 
        	AUDIO=1'b0;
    end 
    //------------------------------------------------------------------------------//

endmodule

//*******************************上下午显示控制***************************//
module AP_Hour(//上下午显示控制
    input       clk,
    input       nCLR,
    input       Hour_EN,
    output      AP
    
);
    reg AP_TEMP;
    reg [3:0] cnt_12;
    always@(posedge clk or negedge nCLR)
            begin
                if(~nCLR) begin
                    cnt_12<=4'd0;
                    AP_TEMP=1'b0;
                    end
                else if(Hour_EN)
                    begin
                        if(cnt_12<4'b1011) begin
                             cnt_12<=cnt_12+1;
                            AP_TEMP=AP_TEMP;
                             end
                        else begin
                            cnt_12<=4'b0000;
                           AP_TEMP=AP_TEMP+1'b1;
                            end
                    end
                else begin
                    cnt_12<=cnt_12;
                   AP_TEMP<=AP_TEMP;
                    end
      end
      assign AP=AP_TEMP;
endmodule

//*****************************整点报时数音频产生*****************************//
module HOUR_BEGIN (//整点报时数音频产生
    input          clk,
    input          CLK_1HZ,
    input          nCLR,
    input  [4:0]   Hour_Audio,
    output  reg    H_AUDIO
);
    wire CLK_500HZ;
    Divider_XHZ divider_500HZ(nCLR,clk,CLK_500HZ);
    defparam divider_500HZ.OUT_Freq=500;
    reg [4:0] cnt;
    always@(posedge CLK_1HZ or negedge nCLR)
    begin
        if(~nCLR)begin
            cnt<=5'd0;
            end
        else if(cnt==5'd31)
            cnt<=5'd0;
        else begin
            cnt<=cnt+1'b1;
            end
     end

     always @(posedge clk or negedge nCLR) begin
         if (~nCLR) begin
             H_AUDIO<=0;
         end else if(CLK_1HZ&&cnt<Hour_Audio) begin
             H_AUDIO<=CLK_500HZ;
         end
         else H_AUDIO<=0;
     end
    
endmodule

//****************************小时全十进制计数（5位）******************************//
module hour_audio(//小时全十进制计数（5位）
    input            clk,nCLR,EN,
    input            Hour_CRL,
    output reg [4:0] hour_audio
);
    always @(posedge clk or negedge nCLR ) begin
        if (~nCLR) begin
            hour_audio<=5'd0;
        end else if(~EN) begin
            hour_audio<=hour_audio;
        end
        else if(hour_audio==(Hour_CRL?5'd23:5'd11))
             hour_audio<=0;
        else hour_audio<=hour_audio+1;
 
    end
endmodule


//*****************************24小时制BCD码小时计数*****************************//
module counter_24Hours(//24小时制BCD码小时计数
    input            clk,nCLR,EN,
    output reg [3:0] CntH,CntL
);

    always @(posedge clk or negedge nCLR ) begin
        if (~nCLR) begin
            {CntH,CntL}<=8'h00;
        end else if (~EN) begin
            {CntH,CntL}<={CntH,CntL};
        end else if ((CntH>2)||(CntL>9)||((CntH==2)&&(CntL>=3)))
            {CntH,CntL}<=8'h00;
        else if ((CntH==2)&&(CntL<3)) begin 
            CntH<=CntH;
            CntL<=CntL+1'b1;
        end else if (CntL==9) begin
            CntH<=CntH+1'b1;CntL<=4'b0000;
        end else begin
            CntH<=CntH;CntL<=CntL+1'b1;
        end
    end
endmodule


//*****************************12小时制BCD码小时计数*****************************//
module counter_12Hours(//12小时制BCD码小时计数
    input            clk,nCLR,EN,
    output reg [3:0] CntH,CntL,
    output reg [3:0] hour_audio
);
    always @(posedge clk or negedge nCLR ) begin
        if (~nCLR) begin
            {CntH,CntL}<=8'h12;
         
        end else if (~EN) begin
            {CntH,CntL}<={CntH,CntL};
           
        end else if ((CntH>1)||(CntL>9)||((CntH==1)&&(CntL==1)))
        begin
            {CntH,CntL}<=8'h12;
    
        end
        else if ({CntH,CntL}==8'h12)
          {CntH,CntL}<=8'h01;
         else if (CntH==1&&CntL<1) begin 
            CntH<=CntH;CntL<=CntL+1'b1;
        end else if (CntL==9) begin
            CntH<=CntH+1'b1;CntL<=4'b0000;
        end else begin
            CntH<=CntH;CntL<=CntL+1'b1;
        end
    end
endmodule

//***************************模十计数器*******************************//
module counter_10 (
    input clk,nCLR,EN,
    output reg[3:0] Q
);
    always @(posedge clk or negedge nCLR  or negedge EN) begin
        if (~nCLR) begin
            Q<=4'b0000;
        end 
        else  begin if(~EN) 
             Q<=Q;
              else if (Q==4'b1001) Q<=4'b0000;
                else Q<=Q+1'b1;
               end
    end
    
endmodule

//****************************模六计数器******************************//
module counter_6 (
    input clk,nCLR,EN,
    output reg[3:0] Q
);
    always @(posedge clk or negedge nCLR  or posedge EN) begin
        if (~nCLR) begin
            Q<=4'b0000;
        end 
        else  begin if(~EN) 
             Q<=Q;
              else if (Q==4'b0101) Q<=4'b0000;
                else Q<=Q+1'b1;
               end
    end
    
endmodule

//*****************************八*七位译码管带点驱动,刷新率60HZ*****************************//
module SEG7_LUT_8(//八*七位译码管带点驱动
    input             clk,
    input             nCLR,
    input      [31:0] iDIG,//8个译码管待显示数据
    output reg [7:0]  AN,//译码管使能
    output reg [7:0]  HEX//译码管数据
    );
   // reg [31:0] iDIG=32'h20200316;调试用
    reg    [7:0]    AN_CRL;
    wire            CLK_480HZ;//480HZ时钟，60hz刷新率
    wire   [7:0]    HEX_CRL0,HEX_CRL1,HEX_CRL2,HEX_CRL3,HEX_CRL5,HEX_CRL4,HEX_CRL6,HEX_CRL7;
    Divider_XHZ divider_480HZ(nCLR,clk,CLK_480HZ);
    defparam divider_480HZ.OUT_Freq=480;//480HZ时钟
     SEG7_LUT u7(iDIG[31:28],0, HEX_CRL0);//左1
     SEG7_LUT u6(iDIG[27:24],1, HEX_CRL1);//左2
     SEG7_LUT u5(iDIG[23:20],1, HEX_CRL2);//左3
     SEG7_LUT u4(iDIG[19:16],0, HEX_CRL3);//左4
     SEG7_LUT u3(iDIG[15:12],1, HEX_CRL4);//左5
     SEG7_LUT u2(iDIG[11:8], 0, HEX_CRL5);//左6
     SEG7_LUT u1(iDIG[7:4],  1, HEX_CRL6);//左7
     SEG7_LUT u0(iDIG[3:0],  1, HEX_CRL7);//左8
     
    always@(negedge nCLR or posedge CLK_480HZ)//有限状态机，状态自动转换，进行使能和数据控制
        begin if(!nCLR) begin
                        AN_CRL<=8'b1111_1111;
                        HEX<=8'b1111_1111;
                    end
             else begin
                        case(AN_CRL)
                           8'b1111_1111: begin
                                        AN<=8'b0111_1111;    
                                        AN_CRL<=8'b0111_1111;
                                        HEX<=HEX_CRL0;
                                        end 
                           8'b0111_1111: begin
                                        AN<=8'b1011_1111;
                                        AN_CRL<=8'b1011_1111;
                                        HEX<=HEX_CRL1;
                                        end
                           8'b1011_1111: begin
                                        AN<=8'b1101_1111;
                                        AN_CRL<=8'b1101_1111;
                                        HEX<=HEX_CRL2;
                                        end
                           8'b1101_1111: begin
                                            AN<=8'b1110_1111;
                                        AN_CRL<=8'b1110_1111;
                                        HEX<=HEX_CRL3;
                                        end
                           8'b1110_1111: begin
                                        AN<=8'b1111_0111;
                                        AN_CRL<=8'b1111_0111;
                                        HEX<=HEX_CRL4;
                                        end
                           8'b1111_0111: begin            
                                        AN<=8'b1111_1011;     
                                        AN_CRL<=8'b1111_1011; 
                                        HEX<=HEX_CRL5;
                                        end          
                           8'b1111_1011: begin            
                                        AN<=8'b1111_1101;     
                                        AN_CRL<=8'b1111_1101; 
                                        HEX<=HEX_CRL6;   
                                        end  
                           8'b1111_1101: begin            
                                        AN<=8'b1111_1110;     
                                        AN_CRL<=8'b1111_1110; 
                                        HEX<=HEX_CRL7;    
                                        end       
                            8'b1111_1110: begin            
                                            AN<=8'b0111_1111; 
                                        AN_CRL<=8'b0111_1111; 
                                        HEX<=HEX_CRL0;      
                                        end     
                            default : begin
                                        AN<=8'b01111111;
                                        AN_CRL<=8'b01111111;
                                        HEX<=HEX_CRL0;
                                      end
                           endcase
                       end
               end
endmodule

//*****************************单个译码管BCD码转换*****************************//
 module SEG7_LUT(//单个译码管BCD码转换
	input      [3:0] in,
	input            DP_CRL,//点，低电平亮
	output reg [7:0] seg
);
	always@(in) begin
    case ({DP_CRL,in})
       5'h00  : seg<= 8'b0100_0000 ;    5'h10  : seg<= 8'b1100_0000 ;  
       5'h01  : seg<= 8'b0111_1001 ;    5'h11  : seg<= 8'b1111_1001 ;  
       5'h02  : seg<= 8'b0010_0100 ;    5'h12  : seg<= 8'b1010_0100 ;  
       5'h03  : seg<= 8'b0011_0000 ;    5'h13  : seg<= 8'b1011_0000 ;  
       5'h04  : seg<= 8'b0001_1001 ;    5'h14  : seg<= 8'b1001_1001 ;  
       5'h05  : seg<= 8'b0001_0010 ;    5'h15  : seg<= 8'b1001_0010 ;  
       5'h06  : seg<= 8'b0000_0010 ;    5'h16  : seg<= 8'b1000_0010 ;  
       5'h07  : seg<= 8'b0111_1000 ;    5'h17  : seg<= 8'b1111_1000 ;  
       5'h08  : seg<= 8'b0000_0000 ;    5'h18  : seg<= 8'b1000_0000 ;  
       5'h09  : seg<= 8'b0001_1000 ;    5'h19  : seg<= 8'b1001_1000 ;  
       5'h0a  : seg<= 8'b0000_1000 ;    5'h1a  : seg<= 8'b1000_1000 ; //显示A，用于上下午显示
       5'h0b  : seg<= 8'b0000_1100 ;    5'h1b  : seg<= 8'b1000_1100 ; //显示P，用于上下午显示
       5'h0c  : seg<= 8'b0011_1111 ;    5'h1c  : seg<= 8'b1011_1111 ; //显示-，用于上下午显示   
       5'h0d  : seg<= 8'b0010_0001 ;    5'h1d  : seg<= 8'b1010_0001 ;  
       5'h0e  : seg<= 8'b0000_0110 ;    5'h1e  : seg<= 8'b1000_0110 ;  
       5'h0f  : seg<= 8'b0000_1110 ;    5'h1f  : seg<= 8'b1000_1110 ;  
     endcase           
     end
endmodule
 //     |-----a-----|
 //  f |           | b
 //   |-----g-----|
 //e |           | c
 // |-----d-----|
 
//******************************分频器，使用时需定义参数****************************//
module Divider_XHZ(//分频器，使用时需定义参数
    input nCLR,
    input CLK_100M,
    output reg CLK_1HZ//默认输出1HZ频率
    );
    parameter N = 27;
    parameter CLK_Freq = 100000000;
    parameter OUT_Freq = 1;
    reg [N-1:0] Count_DIV;
    
    always @(posedge CLK_100M or negedge nCLR)
    begin
        if(!nCLR)           //低电平置零
        begin
            CLK_1HZ <= 0;
            Count_DIV <=0;
        end
        else
        begin
            if(Count_DIV < (CLK_Freq/(2 * OUT_Freq)-1))
				Count_DIV <= Count_DIV + 1'b1;
			else
			begin
				Count_DIV <= 0;
				CLK_1HZ <= ~CLK_1HZ;
			end
        end    
    end
endmodule

//******************************闹钟音乐，洋娃娃与小熊跳舞片段****************************//
module audio_music(//闹钟音乐，洋娃娃与小熊跳舞片段
    input clk,
    input nCLR,//作为音乐开始标志，保证闹钟到时从第一个音符开始响起
    output reg  Y
    );
    wire CLK_4HZ;
    wire clk_1,clk_2,clk_3,clk_4,clk_5,clk_6,clk_7;//分别对应7个音符

    Divider_XHZ divider_1(nCLR,clk,clk_1);
    defparam divider_1.OUT_Freq=261;
    Divider_XHZ divider_2(nCLR,clk,clk_2);
    defparam divider_2.OUT_Freq=293;
    Divider_XHZ divider_3(nCLR,clk,clk_3);
    defparam divider_3.OUT_Freq=329;
    Divider_XHZ divider_4(nCLR,clk,clk_4);
    defparam divider_4.OUT_Freq=349;
    Divider_XHZ divider_5(nCLR,clk,clk_5);
    defparam divider_5.OUT_Freq=391;
    Divider_XHZ divider_6(nCLR,clk,clk_6);
    defparam divider_6.OUT_Freq=440;
    Divider_XHZ divider_7(nCLR,clk,clk_7);
    defparam divider_7.OUT_Freq=493;
    Divider_XHZ divider_8(nCLR,clk,CLK_4HZ);
    defparam divider_8.OUT_Freq=4;
    
    reg [7:0] cnt;//根据计数器值顺序读音符

    always@(posedge CLK_4HZ or negedge nCLR)
    begin
        if(~nCLR)begin
            cnt<=7'd1;
            end
        else if(cnt==7'd83)
            cnt<=7'd0;
        else begin
            cnt<=cnt+1'b1;
            end
     end
     always@(posedge clk)
    begin
        if(~nCLR)
        Y<=1'b0;
        else if(CLK_4HZ)begin
        case (cnt)
        8'd1        :       Y<=1'b0;
        8'd2        :       Y<= clk_1;
        8'd3        :       Y<= clk_2;
        8'd4        :       Y<= clk_3;
        8'd5        :       Y<= clk_4;
        8'd6        :       Y<= clk_5;
        8'd7        :       Y<= clk_5;
        8'd8        :       Y<= clk_5;
        8'd9        :       Y<= clk_4;
        8'd10       :       Y<= clk_3;
        8'd11       :       Y<= clk_4;
        8'd12       :       Y<= clk_4;
        8'd13       :       Y<= clk_4;
        8'd14       :       Y<= clk_3;
        8'd15       :       Y<= clk_2;
        8'd16       :       Y<= clk_1;
        8'd17       :       Y<= clk_3;
        8'd18       :       Y<= clk_5;
        8'd19       :       Y<=1'b0;
        8'd20       :       Y<= clk_1;  
        8'd21       :       Y<= clk_2;  
        8'd22       :       Y<= clk_3;  
        8'd23       :       Y<= clk_4;  
        8'd24       :       Y<= clk_5;  
        8'd25       :       Y<= clk_5;  
        8'd26       :       Y<= clk_5;  
        8'd27       :       Y<= clk_4;  
        8'd28       :       Y<= clk_3;  
        8'd29       :       Y<= clk_4;  
        8'd30       :       Y<= clk_4;  
        8'd31       :       Y<= clk_4;  
        8'd32       :       Y<= clk_3;  
        8'd33       :       Y<= clk_2;  
        8'd34       :       Y<= clk_1;  
        8'd35       :       Y<= clk_3;  
        8'd36       :       Y<= clk_1;  
        8'd37       :       Y<=1'b0;
        8'd38       :       Y<= clk_6;  
        8'd39       :       Y<= clk_6; 
        8'd40       :       Y<= clk_6;
        8'd41       :       Y<= clk_5;
        8'd42       :       Y<= clk_4;
        8'd43       :       Y<=1'b0;
        8'd44       :       Y<= clk_5;
        8'd45       :       Y<= clk_5;
        8'd46       :       Y<= clk_5;
        8'd47       :       Y<= clk_4;
        8'd48       :       Y<= clk_3;
        8'd49       :       Y<=1'b0;
        8'd50       :       Y<= clk_4;  
        8'd51       :       Y<= clk_4;
        8'd52       :       Y<= clk_4; 
        8'd53       :       Y<= clk_3;  
        8'd54       :       Y<= clk_2;  
        8'd55       :       Y<=1'b0;
        8'd56       :       Y<= clk_1;  
        8'd57       :       Y<= clk_3;  
        8'd58       :       Y<= clk_5;  
        8'd59       :       Y<=1'b0;
        8'd60       :       Y<=1'b0;
        8'd61       :       Y<= clk_6;  
        8'd62       :       Y<= clk_6;  
        8'd63       :       Y<= clk_6;  
        8'd64       :       Y<= clk_5;  
        8'd65       :       Y<= clk_4;  
        8'd66       :       Y<=1'b0;
        8'd67       :       Y<= clk_5;  
        8'd68       :       Y<= clk_5;  
        8'd69       :       Y<= clk_5;
        8'd70       :       Y<= clk_4;
        8'd71       :       Y<= clk_3;
        8'd72       :       Y<=1'b0;
        8'd73       :       Y<= clk_4;
        8'd74       :       Y<= clk_4;
        8'd75       :       Y<= clk_4;
        8'd76       :       Y<= clk_3;
        8'd77       :       Y<= clk_2;
        8'd78       :       Y<=1'b0;
        8'd79       :       Y<= clk_1;
        8'd80       :       Y<= clk_3;
        8'd81       :       Y<= clk_1;
        8'd82       :       Y<=1'b0;
        8'd83       :       Y<=1'b0;
   
        default     :       Y<=1'b0;
        endcase
        end
        else   Y=1'b0;
    end
 endmodule





