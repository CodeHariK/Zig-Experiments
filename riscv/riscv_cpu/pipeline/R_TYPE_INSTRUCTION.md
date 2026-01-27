# R-type instructions

RISC-V R-type instructions perform arithmetic and logical operations (like add, sub, and, or, shifts) using three registers: two sources (rs1, rs2) and one destination (rd). They have a fixed 32-bit format with fields for opcode (identifies R-type), funct3 and funct7 (specify the exact operation), rs1, rs2, and rd, enabling flexible register-to-register data manipulation crucial for high-performance computing. 

## R-Type Format & Fields (32-bit) 
* Opcode (bits 0-6): Identifies the instruction as R-type (e.g., 0110011 for basic ALU ops).
* rd (bits 7-11): Destination register (5 bits for 32 registers).
* Funct3 (bits 12-14): Specifies the operation (e.g., 000 for add/sub).
* rs1 (bits 15-19): First source register (5 bits).
* rs2 (bits 20-24): Second source register (5 bits).
* Funct7 (bits 25-31): Further defines the operation (e.g., for add vs. subtract). 

## Key Characteristics
* Register-to-Register: Operates purely on data held in registers.
* ALU Operations: Primarily used for Arithmetic Logic Unit (ALU) tasks.

* Examples: add, sub (subtraction), sll (shift left logical), xor, or, srl (shift right logical), sra (shift right arithmetic), slt (set less than).

* Flexibility: funct3 and funct7 work together to encode many different operations within the same R-type structure. 

* Example: add x1, x2, x3 (x1 = x2 + x3)
* Opcode: 0110011 (R-type).
* rd (x1): 00001.
* funct3: 000 (for add).
* rs1 (x2): 00010.
* rs2 (x3): 00011.
* funct7: 0000000 (for add). 
