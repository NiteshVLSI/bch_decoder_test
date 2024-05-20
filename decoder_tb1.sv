// Code your testbench here
// or browse Examples
// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

//--------------------------------------INTERFACE-----------------------------

interface decoder_interface;

    logic [14:0] received;
  logic clk;
    logic start;
    logic ctrl;
    logic [7:0] corrected;
    logic [1:0] nerr;
    logic [14:0] decodedOp;
  
   covergroup cov ;
        option.per_instance = 1;
        msg: coverpoint received[6:0];
     nerr: coverpoint nerr{bins b= {0,1,2};}
     
     cross_bin : cross msg, nerr;
      
        
    endgroup

    cov cov_obj = new();
    

endinterface

//--------------------------------------TRANSACTION----------------------------

class transaction;

    randc bit [6:0] msg;
    bit[14:0] correct_code;
    randc bit ctrl;
    randc bit [1:0] mode;
    randc bit[3:0] e_pos1,e_pos2;
    bit [14:0] received;
    bit [7:0] corrected;
    bit [1:0] nerr;
    bit [14:0] decodedOp;
    bit clk;

    constraint limit{e_pos2 != e_pos1;  mode<2'd3; e_pos2<15;e_pos1<15;}

    function void post_randomize();
        this.received= ig(this.e_pos1,this.e_pos2,this.mode,this.msg);
      $display("received value put: %b, msg : %b  codeword:%b", this.received,this.msg,this.correct_code);
    endfunction

    function transaction copy();
         copy = new();
        copy.msg = this.msg;
        copy.ctrl = this.ctrl;
        copy.received = this.received;
        copy.corrected = this.corrected;
        copy.nerr = this.nerr;
        copy.decodedOp = this.decodedOp;
        copy.clk = this.clk;
        copy.correct_code = this.correct_code;
        copy.mode = this.mode;
    endfunction

    function [7:0] encode;
        input [6:0] temp_b;
        reg [7:0] b;
        reg [7:0] c = 0;
        reg a;
        integer i;
        begin
            b = {temp_b, 1'b0};
            for (i = 0; i < 7; i = i + 1) begin
                a = b[i + 1] ^ c[7];
                c[7] = a ^ c[6];
                c[6] = a ^ c[5];
                c[5] = c[4];
                c[4] = a ^ c[3];
                c[3] = c[2];
                c[2] = c[1];
                c[1] = c[0];
                c[0] = a;
            end
            encode = {c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7]};
        end
    endfunction



  function [14:0]ig(input[3:0]epos1,epos2,input[1:0]mode,input[6:0] msg);
reg[14:0] buff;
    reg[14:0]buff1;
    begin
case(mode)
0:
begin
this.correct_code = {encode(msg),msg};
buff = this.correct_code;

end

1:
begin

this.correct_code = {encode(msg),msg};
buff = this.correct_code;
buff[epos1] = ~buff[epos1];

end

2:
begin
this.correct_code = {encode(msg),msg};
buff = this.correct_code;
buff[epos1] = ~buff[epos1];
buff[epos2] = ~buff[epos2];

end

endcase
      ig=buff;
    end


endfunction
  
  
  
  
   

endclass

//-------------------------------------GENERATOR----------------------------------

class generator;
    transaction tranc;
    mailbox #(transaction) mail;
    mailbox #(transaction) mbxref;
    event sample;

    int count = 250;
    event new_int, finished;

  function new(mailbox #(transaction) mail,mailbox #(transaction) mbxref);
        this.mail = mail;
        this.mbxref = mbxref;
        tranc = new();
    endfunction

    task run();
        repeat(count) begin
            assert(tranc.randomize()) else $error("Randomization Failed");
            -> sample;
            mail.put(tranc.copy());
          mbxref.put(tranc.copy());
            @new_int;
        end
        ->finished;
    endtask
endclass

//-----------------------------------DRIVER--------------------------------------------

class driver;
    mailbox #(transaction) mail;
    transaction dvrs;
    virtual decoder_interface dec_inf;
   event trig;

    function new(mailbox #(transaction) mail);
        this.mail = mail;
    endfunction
  
   task start();
    dec_inf.start <= 1'b1; // Assert reset signal
     repeat(5) @(posedge dec_inf.clk); // Wait for 5 clock cycles
    dec_inf.start <= 1'b0; // Deassert reset signal
     @(posedge dec_inf.clk); // Wait for one more clock cycle
    $display("[DRV] : RESET DONE"); // Display reset completion message
  endtask

    task run();
        forever begin
            mail.get(dvrs);
            -> trig;
            dec_inf.received <= dvrs.received;
            dec_inf.ctrl <= dvrs.ctrl;
           // @(posedge dec_inf.clk);
        end
    endtask
endclass

//----------------------------MONITOR------------------------------------------------
class monitor;
    mailbox #(transaction) mail;
    transaction tranc;
    virtual decoder_interface dec_inf;

    function new(mailbox #(transaction) mail);
        this.mail = mail;
    endfunction

    task run();
        tranc = new();
        forever begin
          repeat(34) @(posedge dec_inf.clk);
            tranc.corrected = dec_inf.corrected;
            tranc.decodedOp = dec_inf.decodedOp;
            tranc.nerr = dec_inf.nerr;
            mail.put(tranc.copy());
        end
    endtask
endclass


//--------------------------------------------------SCOREBOARD-----------------------------------------------------

class scoreboard;
    mailbox #(transaction) mail;
    mailbox #(transaction) mbxref;
    transaction tranc;
    transaction trref;
    event new_int;

  function new(mailbox #(transaction) mail, mailbox #(transaction) mbxref);
    this.mail = mail; // Initialize the mailbox for receiving data from the driver
    this.mbxref = mbxref; // Initialize the mailbox for receiving reference data from the generator
  endfunction

    task run();
        forever begin
         
            mail.get(tranc);
            mbxref.get(trref);
            
          if ( (tranc.decodedOp == trref.correct_code)&&(tranc.nerr==trref.mode)) begin
            $display("out-- %7b \t decodedOp :%b \t nerr = %d\t mode=%d \t ctrl: %b \t in-- %7b", tranc.corrected,tranc.decodedOp,tranc.nerr,trref.mode,trref.ctrl, trref.msg);
              $display("Matched"); 
            end else
              $error("Error: Expected %b, got %b  nerr = %d mode = %d decodedOp= %b codeword=%b", trref.msg, tranc.corrected,tranc.nerr,trref.mode,tranc.decodedOp,trref.correct_code);
            ->new_int;
        end
    endtask
endclass

//----------------------------Environment--------------------------------------------

class environment;
    generator gen;
    driver dvr;
    monitor mon;
    scoreboard sco;
    
    mailbox #(transaction) gtdmail;
    mailbox #(transaction) mtsmail;
    mailbox #(transaction) mbxref;

    virtual decoder_interface dec_inf;

    event next_int_pre;

    function new(virtual decoder_interface dec_inf);
        gtdmail = new();
        mbxref = new();
        mtsmail = new();

        gen = new(gtdmail, mbxref);
        dvr = new(gtdmail);
        mon = new(mtsmail);
        sco = new(mtsmail, mbxref);

        this.dec_inf = dec_inf;

        dvr.dec_inf = dec_inf;
        mon.dec_inf = dec_inf;

        gen.new_int = next_int_pre;
        sco.new_int = next_int_pre;
    endfunction
  
 

    task test();
        fork
            gen.run();
            dvr.run();
            mon.run();
            sco.run();
        join_any
    endtask
  
  task pre_test();
    dvr.start(); // Perform the driver reset
  endtask

    task post_test();
        wait(gen.finished.triggered);
      $display("Percentage = %0.2f ", dec_inf.cov_obj.get_inst_coverage());
        $finish();
    endtask

    task run();
      pre_test();
        test();
        post_test();
    endtask
endclass


//--------------------------------------------------TOP_MODULE------------------------------------------------------
module tb();
    environment env;
    decoder_interface dec_inf();

  sampledec dut(
        .received(dec_inf.received),
        .clk(dec_inf.clk),
    .start(dec_inf.start),
        .ctrl(dec_inf.ctrl),
       .corrected(dec_inf.corrected),
      .decodedOp(dec_inf.decodedOp),
    .nerr(dec_inf.nerr)
 );
  
  //sampledec dut(dec_inf);
  
  
  always@(posedge dec_inf.clk)
  begin

  
        dec_inf.start = 0;
       // #5 dec_inf.start = 0;
    @(env.next_int_pre);
     dec_inf.start = 1;
    #2.5;
    end

    always #5 dec_inf.clk <= ~dec_inf.clk;

    initial begin
        dec_inf.clk = 1;
        env = new(dec_inf);
        env.gen.count = 2000;
        env.run();
    end
  
   initial
    begin
      while(dec_inf.cov_obj.get_coverage < 100) begin
		
			@env.gen.sample;					// randomization
			dec_inf.cov_obj.sample();							// sampling coverage
			//itm.print();
		end
    end
  
    initial begin
        $dumpfile("dump.vcd"); // Specify the VCD dump file
        $dumpvars; // Dump all variables
    end
endmodule