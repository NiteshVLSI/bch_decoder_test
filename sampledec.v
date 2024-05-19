`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:45:45 04/14/2018 
// Design Name: 
// Module Name:    sampledec 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module sampledec(received,clk,start,ctrl,corrected,decodedOp,nerr);
	 input [14:0] received;
    input clk;
    input start;
	 input ctrl;
	 
    output[7:0]corrected;
	 output[1:0]nerr;
	 output[14:0]decodedOp;
    reg [7:0]corrected;  
    reg [1:0]nerr;
	 reg [14:0]decodedOp;
	 
    reg[14:0]out;
    reg[14:0]temp;
	 reg[3:0]temp1,temp2,temp3,temp4,temp5;
	
	 reg[3:0]s1,s2,s3,s4;
	 reg[3:0]e1,e2;
	 reg[3:0]b,c,sum;
	 reg dout,eout;
    integer k,l,m,n,p;
	 
	 ///*** DECODING CIRCUIT ***
	 
	 always@(posedge clk)
	 begin
	 
    if(start)
	 begin
	 temp=received;out=0;
	 b=0;c=0;sum=0;
	 s1=0;s2=0;s3=0;s4=0;
	 temp1=0;temp2=0;temp3=0;temp4=0;temp5=0;
	 e1=0;e2=0;
	 nerr=2'b00;
	 k=0;l=0;m=0;p=0;n=15;
	 end
	 
	 else 
	 begin
	 p=p+1;
	 	 
	 ///*** Syndrome Calculation ***
	 //It takes 16 clock pulses to generate the syndromes because 15 bits and all the shift reg has to get 
	 //the data to use it.
	 
if(p<16)
begin 
	 dout=temp[0];
	 temp={temp[0],temp[14:1]};
	 b={b[0]^dout,b[0]^b[3],b[2],b[1]};
	 
	 s1={b[3],b[2],b[1],b[0]};
	 s2={b[3]^b[1],b[1],b[2]^b[0],b[0]};
	 s4={b[3]^b[2]^b[1]^b[0],b[2]^b[0],b[1]^b[0],b[0]};
	 c={c[0]^dout,c[0]^c[3],c[2]^c[0],c[1]^c[0]};
	 s3={c[3],c[0],c[1],c[0]^c[1]^c[2]};
end
 
	 //Majority logic circuit and,or circuit
else if(p==16) 
begin
	 e1=s1;
	 temp1=mul2no(s1,s1);
	 temp2=mul2no(temp1,s1);
	 temp3=mul2no(temp2,temp2);
	 temp4=mul2no(temp3,temp3);
	 temp5=mul2no(temp4,temp1);
    sum=add(s3,temp2);
	 e2=mul2no(temp5,sum);
end
   
else if(p>16 && p<32) 
begin
    k=k+1;
	 eout=~((e1[0]^e2[0])|(e1[1]^e2[1])|(e1[2]^e2[2])|(e1[3]^e2[3]^1));
    e1={e1[0],e1[0]^e1[3],e1[2],e1[1]};
	 e2={e2[1],e2[0]^e2[1],e2[3]^e2[0],e2[2]};
	 
	 if(eout)
	 begin 
	 nerr=nerr+2'b01;
	 l=k-1;
	 m=n-l;
	
	 if(m==15)
	 begin
	 temp[14]=~temp[14];
	 end
	 
	 else 
	 begin
	 temp[14-m]=~temp[14-m];
	 out=temp;
	 end
	 
	 end
	 
	 else
	 out=temp;
end

       else if(p==32)
begin
out=temp;
case(ctrl)
  
1'd0:corrected=out[6:0]; //corrected data
1'd1:corrected=out[14:7];//parity bits
  
endcase
p=31;
decodedOp=out;
end

end
end
///***Multiplication of two elements***

function[3:0]mul2no;
input [3:0]in1;
input [3:0]in2;
reg r1,r2,r3,r4;
begin
    r1=((in1[3]&in2[3])^(in1[2]&in2[0])^(in1[1]&in2[1])^(in1[0]&in2[2]));
    r2=((in1[3]&in2[2])^(in1[2]&in2[3])^(in1[2]&in2[0])^(in1[1]&in2[1])^(in1[1]&in2[0])^(in1[0]&in2[2])^(in1[0]&in2[1]));
    r3=((in1[3]&in2[1])^(in1[2]&in2[2])^(in1[1]&in2[3])^(in1[1]&in2[0])^(in1[0]&in2[1])^(in1[0]&in2[0]));
    r4=((in1[3]&in2[0])^(in1[2]&in2[1])^(in1[1]&in2[2])^(in1[0]&in2[3])^(in1[0]&in2[0]));
    mul2no={r1,r2,r3,r4};
end
endfunction

///***Addition***

function [3:0]add;
input [3:0]in1;
input [3:0]in2;
begin
add={in1[3]^in2[3],in1[2]^in2[2],in1[1]^in2[1],in1[0]^in2[0]};	 
end
endfunction

endmodule

