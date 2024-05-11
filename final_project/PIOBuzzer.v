module PIOBuzzer(
           input  wire       clk,
           input  wire       address_i,		// Processor interface
           input  wire       nwe,		    // Address bit (typically A[0]
           input  wire [7:0] arm_bus_i,		// Data in
           output reg  [7:0] arm_bus_o,		// Data out
           input  wire [7:0] io_data_i,		// Pin interface
           output reg  [7:0] io_data_o,
           output reg  [7:0] io_data_T
);

// Constants for calculating notes
parameter NOTE_CONSTANT     = 16'h1000;
parameter NOTE_MULTIPLIER   = 7'h40;

// Internal registers
reg [7:0] buzzer_en;
reg [7:0] control;
reg [7:0] data;
reg [15:0] current_note;

wire one_mhz_clock_out;                 // On/off signal for my prescaled clock
wire buzzer_out;                        // On/off signal that oscilates to make noise


initial						            // Reset (load) states
  begin
  control <= 8'hFF;	                    // FF = Off, FE = on
  io_data_o <= 8'b0;                    // Out data
  current_note <= 16'b0;                // Translates the incoming byte to frequency, produce a note
  buzzer_en <= 1'b1;                    // On-off switch
  data <= 8'b0;                         // Holds the incoming byte from memory
  end

// Use Jim's module to get a 1MHz clock for ease of use
clk_div one_mhz_clock(
    .clk(clk),
    .clk_1(one_mhz_clock_out)
);

// Divide the 1MHz clock by dynamic frequencies for different notes
Divider buzzer(
        .clk_i(one_mhz_clock_out),
        .en_i(buzzer_en),
        .count_i(current_note),
        .freq_o(buzzer_out)
);

always @ (*) begin
    if (!nwe) begin	 				    // If writing ...
        if (address_i)				    // ... if odd address, then control...
            control <= arm_bus_i;       // ... update state of buzzer.
        else                            // ... if even address, then data...
            data <= arm_bus_i;          // ... take the value in the address and store it in data
    end 
end


// Calculate the new note to be played based of the input keys. The
// calculation is arbitary and purely what I found to produce nice results for
// the available keys and buzzer, while still providing flexbility to play
// a range of notes.
always @ (*) begin
    if (nwe) begin                      // If reading...
        current_note <=                 // ... calculate our new frequency using the incoming data
            NOTE_CONSTANT - (data * NOTE_MULTIPLIER);        
    end
end

always @ (*) begin
  if (address_i) arm_bus_o = control;
  else           arm_bus_o = io_data_i; 
end

always @ (*) begin
  io_data_T = control;                  // Update tristate
  io_data_o = buzzer_out;               // Write buzzer signal to output bzzzzzzzz
end

endmodule

