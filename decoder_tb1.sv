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
    

    covergroup cov @(posedge clk);
        option.per_instance = 1;
        msg: coverpoint received[6:0];
    endgroup

    cov cov_obj = new();
endinterface

//--------------------------------------TRANSACTION----------------------------

class transaction;

    randc bit [6:0] msg;
    randc bit ctrl;
    bit [14:0] received;
    bit [7:0] corrected;
    bit [1:0] nerr;
    bit [14:0] decodedOp;
    bit clk;

    function void post_randomize();
        this.received = {encode(this.msg), this.msg};
      $display("received value put: %b, msg : %b", this.received,this.msg);
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

endclass

//-------------------------------------GENERATOR----------------------------------

class generator;
    transaction tranc;
    mailbox #(transaction) mail;
    mailbox #(transaction) mbxref;

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
            
          if (tranc.corrected == trref.corrected || tranc.decodedOp == trref.received) begin
              $display("out-- %7b \t decodedOp :%b \t ctrl: %b \t in-- %7b", tranc.corrected,tranc.decodedOp,trref.ctrl, trref.msg);
              $display("Matched"); 
            end else
              $error("Error: Expected %b, got %b", trref.msg, tranc.corrected);
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
        env.gen.count = 250;
        env.run();
    end
  
    initial begin
        $dumpfile("dump.vcd"); // Specify the VCD dump file
        $dumpvars; // Dump all variables
    end
endmodule
