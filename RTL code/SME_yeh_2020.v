module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);
input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;
output match;
output [4:0] match_index;
output valid;

localparam Hat = 8'h5E;
localparam Dollar = 8'h24;
localparam Dot = 8'h2E;
localparam Space = 8'h20;

localparam LOAD = 0;
localparam OUTPUT = 1;
localparam PROCESS = 2;

reg match, valid;
reg [4:0] match_index;

reg [1:0] cur_state, next_state;
reg [7:0] string[31:0], pattern[7:0];
reg [5:0] str_idx, pat_idx;
reg [5:0] str_max, pat_max;
reg [5:0] str_ptr; // where str_idx should go back

reg [1:0] mode; // mode[1]: 1 if met Hat, mode[0] : 1 if met Dollar
reg finish; // end processing
reg success; // is match or not

reg is_H, is_D; // is the pattern matched under Hat/Dollar condition

always @(*) begin
    next_state = cur_state;
    case (cur_state)
        LOAD: if (!isstring && !ispattern) next_state = PROCESS;
        PROCESS: if (finish) next_state = OUTPUT;
        default: next_state = LOAD;
    endcase
end

always @(posedge clk or posedge reset)
begin
    if (reset)begin
        valid <= 0;
        match <= 0;
        match_index <= 5'd0;
        str_idx <= 0;
        pat_idx <= 0;
        mode <= 0;
        success <= 'hx;
        finish <= 0;
    end
    else begin
        case(cur_state)
            LOAD: begin
                valid <= 0;
                str_idx <= 0;
                pat_idx <= 0;
                if(isstring) begin // Read String
                    string[str_idx] <= chardata;
                    str_idx <= str_idx + 1;
                    str_max <= str_idx;
                end
                else if(ispattern) begin // Read Pattern
                    str_idx <= 0;
                    /* Set Mode */
                    if(chardata == Hat) begin
                        mode[1] <= 1;
                    end
                    else if(chardata == Dollar) begin
                        mode[0] <= 1;
                    end
                    else begin // Read pure text
                        pattern[pat_idx] <= chardata;
                        pat_idx <= pat_idx + 1;
                        pat_max <= pat_idx;
                    end
                end
                else begin
                    pat_idx <= 0;
                    str_ptr <= 1;
                end
            end
            PROCESS:begin // assume the "^.$" case
                if (str_idx == str_max + 1) begin // meet the end of the string
                    finish <= 1;
                    success <= 0;
                end
                else if (string[str_idx] == pattern[pat_idx] || pattern[pat_idx] == Dot) begin
                    if(pat_idx == pat_max) begin // the whole pattern (pure text) match
                        if (is_H && is_D) begin // match under specified conditions
                            finish <= 1;
                            match_index <= str_idx - pat_max;
                            success <= 1;
                        end
                        else begin // move the whole pattern forward 1 char
                            pat_idx <= 0;
                            str_idx <= str_ptr;
                            str_ptr <= str_ptr + 1;
                        end
                    end
                    else begin // continue to compare the next char of pattern
                        str_idx <= str_idx + 1;
                        pat_idx <= pat_idx + 1;
                    end
                end
                else begin // move the whole pattern forward 1 char
                    pat_idx <= 0;
                    str_idx <= str_ptr;
                    str_ptr <= str_ptr + 1;
                end
            end
            default: begin
                valid <= 1;
                finish <= 0;
                success <= 'hx;
                if(success) 
                    match <= 1;
                else 
                    match <= 0;
                str_idx <= 0;
                pat_idx <= 0;
                mode <= 0;
            end
        endcase

    end

end

always @(posedge clk or posedge reset) begin
    if (reset) cur_state <= LOAD;
    else cur_state <= next_state;
end

always @(*) begin
    if (mode == 2'b00 || mode == 2'b01) is_H = 1;
    else if (str_idx == pat_max) is_H = 1;
    else if (string[str_idx - pat_max - 1] == Space) is_H = 1;
    else is_H = 0;
        
    if (mode == 2'b00 || mode == 2'b10) is_D = 1;
    else if (str_idx == str_max) is_D = 1;
    else if (string[str_idx + 1] == Space) is_D = 1;
    else is_D = 0;
end

endmodule