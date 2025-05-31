`timescale 1ns/1ps

`define BELLEK_ADRES    32'h8000_0000
`define VERI_BIT        32
`define ADRES_BIT       32
`define YAZMAC_SAYISI   32

module islemci (
    input                       clk,
    input                       rst,
    output  reg [`ADRES_BIT-1:0]    bellek_adres,
    input   [`VERI_BIT-1:0]     bellek_oku_veri,//adresi verdig?in ayný c?evrimde gelir.
    output  reg [`VERI_BIT-1:0]     bellek_yaz_veri,
    output  reg                 bellek_yaz
);

localparam GETIR        = 2'd0;
localparam COZYAZMACOKU = 2'd1;
localparam YURUTGERIYAZ = 2'd2;

reg [1:0] simdiki_asama_r;//
reg [1:0] simdiki_asama_ns;//posedgede r <= ns
reg ilerle_cmb;
//Buyruk
reg [31:0] buyruk;
//buyruk parc?alari
reg[6:0] opcode;
reg[4:0] rd;
reg[31:0] rs1_sonuc,rs2_sonuc;
reg[19:0] imm20;
reg[11:0] imm12;
reg load;
//Devre c?iz is? regleri yaz.

//Denetim tablosunu Sinyalleri:
reg [1:0] s1,s3,immSel,esitlik_kontrol;
reg s2,s4,s5,memyaz,yyaz;
reg [2:0] amb_i;

//Veri Yolu deg?is?kenleri:
reg[31:0] AMB_G1,AMB_G2,AMB_Sonuc,anlik_sext,k40;


reg [`VERI_BIT-1:0] yazmac_obegi [0:`YAZMAC_SAYISI-1];
reg [`ADRES_BIT-1:0] ps_r;
reg [`ADRES_BIT-1:0] ps_rn;

integer i;
initial begin
    for(i = 0;i<32;i = i+1)begin
        yazmac_obegi[i] = 0;
    end
end

always @ * begin
    ps_rn = ps_r;
    bellek_adres = ps_r;
    bellek_yaz_veri=0;
    bellek_yaz=0;
    ilerle_cmb = 0;
    simdiki_asama_ns = simdiki_asama_r;
    if(simdiki_asama_r == GETIR) begin
        buyruk = bellek_oku_veri;
        ps_rn = ps_r+4;
        simdiki_asama_ns = COZYAZMACOKU;
        ilerle_cmb = 1;
    end
    else if(simdiki_asama_r == COZYAZMACOKU) begin
        opcode = buyruk[6:0];
        case(opcode)
            7'b0110111:begin//LUI
                s1=2'b00; s4=1'b0; s5=1'b0; memyaz=1'b0; yyaz=1'b1; immSel=1'b1; esitlik_kontrol=1'b0;
                rd=buyruk[11:7];
                imm20=buyruk[31:12];
                load = 0;
            end
            7'b0010111:begin//AUIPC
                s1=2'b01; s2=1'b0; s3=2'b10; s4=1'b0; s5=1'b0; memyaz=1'b0; yyaz=1'b1; amb_i=3'b000; immSel=1'b1;esitlik_kontrol=1'b0;
                rd=buyruk[11:7];
                imm20=buyruk[31:12];
                load = 0;
            end
            7'b1101111:begin//JAL
                s1=2'b01; s2=1'b0; s3=2'b01; s4=1'b0; s5=1'b1; memyaz=1'b0; yyaz=1'b1; amb_i=3'b000; immSel=1'b1;esitlik_kontrol=1'b0;
                rd=buyruk[11:7];
                imm20={buyruk[31],buyruk[19:12],buyruk[20],buyruk[30:21]};
                load = 0;
            end
            7'b1100111: begin//JALR
                s1=2'b01; s2=1'b0; s3=2'b01; s4=1'b1; memyaz=1'b0; yyaz=1'b1; amb_i=3'b000; immSel=1'b0;esitlik_kontrol=1'b0;
                rd=buyruk[11:7];
                rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                imm12=buyruk[31:20];
                load = 0;
            end
            7'b1100011: begin//BEQ
                //s5???
                s2=1'b0; s3=2'b00; s4=1'b0; memyaz=1'b0; yyaz=1'b0; amb_i=3'b001; immSel=1'b0; esitlik_kontrol=1'b1;
                rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                rs2_sonuc=yazmac_obegi[buyruk[24:20]];
                imm12={buyruk[31],buyruk[7],buyruk[30:25],buyruk[11:8]};
                load = 0;
            end
            7'b0000011: begin//LW
                s1=2'b10; s2=1'b1; s3=2'b10; s4=1'b0; s5=1'b0; memyaz=1'b0; yyaz=1'b1; amb_i=3'b000; immSel=1'b0; esitlik_kontrol=1'b0;
                rd=buyruk[11:7];
                rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                imm12=buyruk[31:20];
                load = 1;
            end
            7'b0100011: begin//SW
                s2=1'b1; s3=2'b10; s4=1'b0; s5=1'b0; memyaz=1'b1; yyaz=1'b0; amb_i=3'b000; immSel=1'b0;esitlik_kontrol=1'b0;
                imm12={buyruk[31:25],buyruk[11:7]};
                rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                rs2_sonuc=yazmac_obegi[buyruk[24:20]];
                load = 0;
            end
            7'b0010011: begin//ADDI
                s1=2'b01; s2=1'b1; s3=2'b10; s4=1'b0; s5=1'b0; memyaz=1'b0; yyaz=1'b1; amb_i=3'b000; immSel=1'b0;esitlik_kontrol=1'b0;
                rd=buyruk[11:7];
                rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                imm12=buyruk[31:20];
                load = 0;
            end
            7'b0110011: begin//ADD,SUB,OR,AND,XOR
                load = 0;
                case(buyruk[14:12])
                    3'b000:begin
                        if(buyruk[31:25]==7'b0000000)begin//ADD
                            s1=2'b01; s2=1'b1; s3=2'b00; s4=1'b0; s5=1'b0; memyaz=1'b0; yyaz=1'b1; amb_i=3'b000;esitlik_kontrol=1'b0;
                            rd=buyruk[11:7];
                            rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                            rs2_sonuc=yazmac_obegi[buyruk[24:20]];
                        end
                        else begin//SUB
                            s1=2'b01; s2=1'b1; s3=2'b00; s4=1'b0; s5=1'b0; memyaz=1'b0; yyaz=1'b1; amb_i=3'b001;esitlik_kontrol=1'b0;
                            rd=buyruk[11:7];
                            rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                            rs2_sonuc=yazmac_obegi[buyruk[24:20]];
                        end
                    end
                    3'b110:begin//OR
                        s1=2'b01; s2=1'b1; s3=2'b00; s4=1'b0; s5=1'b0; memyaz=1'b0; yyaz=1'b1; amb_i=3'b010;esitlik_kontrol=1'b0;
                        rd=buyruk[11:7];
                        rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                        rs2_sonuc=yazmac_obegi[buyruk[24:20]];
                    end
                    3'b111:begin//AND
                        s1=2'b01; s2=1'b1; s3=2'b00; s4=1'b0; s5=1'b0; memyaz=1'b0; yyaz=1'b1; amb_i=3'b011;esitlik_kontrol=1'b0;
                        rd=buyruk[11:7];
                        rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                        rs2_sonuc=yazmac_obegi[buyruk[24:20]];
                    end
                    3'b100:begin//XOR
                        s1=2'b01; s2=1'b1; s3=2'b00; s4=1'b0; s5=1'b0; memyaz=1'b0; yyaz=1'b1; amb_i=3'b100;esitlik_kontrol=1'b0;
                        rd=buyruk[11:7];
                        rs1_sonuc=yazmac_obegi[buyruk[19:15]];
                        rs2_sonuc=yazmac_obegi[buyruk[24:20]];
                    end
                endcase
            end
            default: begin end
          endcase
          simdiki_asama_ns = YURUTGERIYAZ;
          ilerle_cmb = 1;
    end
    else if(simdiki_asama_r==YURUTGERIYAZ) begin
        case(s2)
            1'b0:begin
                AMB_G1=ps_r;
            end
            1'b1:begin
                AMB_G1=rs1_sonuc;
            end
            default:begin end
        endcase
        case(s3)
            2'b00:begin
                AMB_G2=rs2_sonuc;
            end
            2'b01:begin
                AMB_G2=32'd4;
            end
            2'b10:begin
                if(immSel==1'b0)begin//12yi 32ye genis?let
                    AMB_G2={{20{imm12[11]}},imm12};
                end
                if(immSel==1'b1)begin//20yi 32ye genis?let
                    AMB_G2={imm20,12'd0};
                end
            end
            default:begin end
        endcase
        case(amb_i)
            3'b000:begin
                AMB_Sonuc=AMB_G1 + AMB_G2;
            end
            3'b001:begin
                AMB_Sonuc=AMB_G1 - AMB_G2;
            end
            3'b010:begin
                AMB_Sonuc=AMB_G1 | AMB_G2;
            end
            3'b011:begin
                AMB_Sonuc=AMB_G1 & AMB_G2;
            end
            3'b100:begin
                AMB_Sonuc=AMB_G1 ^ AMB_G2;
            end
        endcase
        
        if(load)begin
            bellek_adres = rs1_sonuc + AMB_G2;
        end
        
        if(memyaz)begin
            bellek_yaz = 1;
            bellek_yaz_veri = rs2_sonuc;
            bellek_adres = AMB_Sonuc;
        end

        case(s1)
            2'b00:begin
                yazmac_obegi[rd]={{20{imm12[11]}},imm12};             
            end
            2'b01:begin
                yazmac_obegi[rd]=AMB_Sonuc;
            end
            2'b10:begin
                yazmac_obegi[rd]=bellek_oku_veri;
            end
        endcase
        if(esitlik_kontrol==1)begin
            if(AMB_Sonuc==32'd0)begin//es?it
                 s5=1'b1;
            end
            else begin//deg?il
                 s5=1'b0;
            end
        end
        case(s5)
            1'b0:begin
                k40=ps_r;
            end
            1'b1:begin
                if(immSel==1'b0)begin//12yi 32ye genis?let
                    k40=ps_r+{imm12,20'd0};
                end
                if(immSel==1'b1)begin//20yi 32ye genis?let
                    k40=ps_r+{imm20,12'd0};
                end
            end
        endcase
        case(s4)
            1'b0:begin
                ps_rn=k40;
            end
            1'b1:begin
                if(immSel==1'b0)begin//12yi 32ye genis?let
                    ps_rn=rs1_sonuc+{imm12,20'd0};
                end
                if(immSel==1'b1)begin//20yi 32ye genis?let
                    ps_rn=rs1_sonuc+{imm20,12'd0};
                end
            end
        endcase
        simdiki_asama_ns = GETIR;
        ilerle_cmb = 1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        ps_r <= `BELLEK_ADRES;
        simdiki_asama_r <= GETIR;
    end
    else begin
        simdiki_asama_r <= simdiki_asama_ns;
        ps_r <= ps_rn;
    end
end

endmodule