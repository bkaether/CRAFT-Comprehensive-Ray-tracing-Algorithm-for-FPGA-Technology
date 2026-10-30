package tb_pkg;
    // constants
    localparam real PI = 3.141592653589793;
    localparam real RAD2DEG = 180.0 / PI;
    localparam real DEG2RAD = PI / 180.0;

    function automatic real abs_real(real x);
        return (x < 0.0) ? -x : x;
    endfunction

    function automatic real fxpt_to_real(logic signed [63:0] fxpt_value, int fractional_bits);
        if ($isunknown(fxpt_value)) begin
            $fatal(1, "Value X or Z passed into fxpt_to_real()");
        end
        return real'(fxpt_value) / (2.0 ** fractional_bits);
    endfunction

    function automatic bit is_close_real(real a, real b, real threshold);
        return abs_real(a - b) <= threshold;
    endfunction

    //////////////////////////////////////////////////////////////////////////
    // TEA hash reference model (bit-exact model of rtl/src/tea_hash.sv)
    //
    // Note: this makes tb_pkg depend on data_structs_pkg
    // (constants, salt type, HASH_ROUNDS), so data_structs_pkg must compile
    // first. That dependency is deliberate: the model and the RTL read the
    // same constants from one place.
    //
    // All values are unsigned 32-bit; all arithmetic wraps mod 2^32 (every
    // operand is 32 bits wide, so expression width is 32); shifts are logical.
    //
    // Returns both full 32-bit output halves. Callers build the key in their
    // own module's layout and slice what they need, e.g. for generate_ray:
    //     key      = {pixel_x, pixel_y, sample_idx};
    //     offset_x = r0[31:16];
    //     offset_y = r1[31:16];
    //////////////////////////////////////////////////////////////////////////
    function automatic void tea_hash_model(
        input  logic [31:0]                 key,
        input  data_structs_pkg::rng_salt_t salt,
        output logic [31:0]                 r0,
        output logic [31:0]                 r1,
        input  int                          rounds = data_structs_pkg::HASH_ROUNDS
    );
        logic [31:0] v0;
        logic [31:0] v1;
        logic [31:0] sum;

        v0  = key;
        v1  = salt;
        sum = '0;

        for (int i = 0; i < rounds; i++) begin
            sum = sum + data_structs_pkg::DELTA;
            v0  = v0 + ( ((v1 << 4) + data_structs_pkg::K0) ^ (v1 + sum) ^ ((v1 >> 5) + data_structs_pkg::K1) );
            v1  = v1 + ( ((v0 << 4) + data_structs_pkg::K2) ^ (v0 + sum) ^ ((v0 >> 5) + data_structs_pkg::K3) );  // uses the NEW v0
        end

        r0 = v0;
        r1 = v1;
    endfunction

    // Known-answer self-test for the model. Call once at the start of a test;
    // returns 1 on pass. Vectors are from tea_rounds.py --kat (ROUNDS = 6),
    // independently cross-checked with a pure-integer implementation.
    // Salt values are cast because the vectors use raw salt numbers.
    function automatic bit tea_hash_model_selftest();
        typedef struct {
            logic [31:0] key;
            logic [31:0] salt;
            logic [31:0] r0;
            logic [31:0] r1;
        } tea_kat_t;

        tea_kat_t kats[] = '{
            '{32'h00000000, 32'd0, 32'hCFC80235, 32'hE00DCA2D},  // x=0   y=0   sample=0
            '{32'h00400000, 32'd0, 32'hB73A3D83, 32'hC966B676},  // x=1   y=0   sample=0
            '{32'h00001000, 32'd0, 32'h33DA527E, 32'h8D6166FA},  // x=0   y=1   sample=0
            '{32'h00000001, 32'd0, 32'h5A0F326B, 32'h9209177B},  // x=0   y=0   sample=1
            '{32'hC7E57FFF, 32'd0, 32'hC1FEFCC2, 32'h90CA626B},  // x=799 y=599 sample=4095
            '{32'h6412C011, 32'd0, 32'h95E5237A, 32'h09500619},  // x=400 y=300 sample=17
            '{32'h1EDC8315, 32'd1, 32'h6BE80C4C, 32'h05592C23}   // x=123 y=456 sample=789, salt=1
        };

        logic [31:0] r0;
        logic [31:0] r1;
        bit          pass = 1'b1;

        foreach (kats[i]) begin
            tea_hash_model(kats[i].key, data_structs_pkg::rng_salt_t'(kats[i].salt), r0, r1, 6);
            if (r0 !== kats[i].r0 || r1 !== kats[i].r1) begin
                $error("tea_hash_model KAT %0d failed: key=%08h salt=%0d got r0=%08h r1=%08h expected r0=%08h r1=%08h",
                       i, kats[i].key, kats[i].salt, r0, r1, kats[i].r0, kats[i].r1);
                pass = 1'b0;
            end
        end

        return pass;
    endfunction

endpackage