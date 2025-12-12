const std = @import("std");

// Note: only the first four bits (nibble) are used for drawing a number or character
const FONTSET = [80]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

const EMPTY_GFX = [64][32]bool{false} ** 64 * 32;

const Chip8 = struct {
    memory: [4096]u8, // Chip8 has 4096 bytes of memory

    registers: [16]u8, // 16 general purpose registers (V0 - VF)

    gfx: [64][32]bool, // The display is 64 pixels wide and 32 pixels tall.

    stack: []u16, // CHIP-8 uses it to call and return from subroutines (“functions”) and nothing else, so you will be saving addresses there; 16-bit (or really only 12-bit) numbers.
    stack_pointer: u16,

    program_counter: u16, // Points at the current instruction in memory (12-bit used)
    index_register: u16, // Points to memory location (12-bit used)

    key: [16]bool, // Chip8 has a keyboard

    delay_timer: u8, // An 8-bit delay timer which is decremented at a rate of 60 Hz until it reaches 0
    sound_timer: u8, // An 8-bit sound timer which functions like the delay timer, but also gives off a beeping sound as long as it’s not 0

    draw_flag: bool, // Chip8 has a draw flag

    pub fn init() Chip8 {
        const chip8 = Chip8{
            .memory = [4096]u8,
            .registers = [16]u8,
            .gfx = [64][32]u8,
            .opcode = 0,
            .stack = [16]u16,
            .stack_pointer = 0,
            .program_counter = 512, // Program counter starts at 512
            .index_register = 0,
            .key = [16]bool,
            .delay_timer = 0,
            .sound_timer = 0,
            .draw_flag = false,
        };

        // Load fontset
        for (0..80) |i| {
            chip8.memory[i] = FONTSET[i];
        }

        // Load program

        return chip8;
    }

    // Emulate a single cycle
    // Fetch the next instruction
    // Decode the instruction
    // Execute the instruction
    pub fn emulateCycle(self: *Chip8) void {

        // 16 bits opcode
        const opcode: u16 = self.memory[self.program_counter] << 8
            //
        | self.memory[self.program_counter + 1];

        self.program_counter += 2;

        self.decode(opcode);
    }

    pub fn loadROM(self: *Chip8, path: []const u8) void {}

    // CHIP-8 has 35 opcodes, which are all two bytes long and stored big-endian.
    // The opcodes are listed below, in hexadecimal and with the following symbols:
    //
    // NNN: address
    // NN: 8-bit constant
    // N: 4-bit constant
    // X and Y: 4-bit register identifier
    // PC : Program Counter
    // I : 12bit register (For memory address) (Similar to void pointer);
    // VN: One of the 16 available variables. N may be 0 to F (hexadecimal);
    fn decode(self: *Chip8, opcode: u16) void {
        const code = opcode >> 12; // First 4 bits out of 16

        switch (code) {
            0x0 => {
                if (opcode == 0x00E0) {
                    // CLS : Display : clear()
                    // Clears the screen
                    self.gfx = EMPTY_GFX;
                } else if (opcode == 0x00EE) {
                    // RET : Flow : PC = stack[SP]; SP--
                    // Returns from a subroutine
                    self.program_counter = self.stack[self.stack_pointer];
                    self.stack_pointer -= 1;
                }
            },
            0x1 => {
                // JP : Flow : PC = NNN
                // Jumps to the address NNN
                const nnn = opcode & 0x0FFF;
                self.program_counter = nnn;
            },
            0x2 => {
                // CALL : Flow : stack[SP] = PC; SP++; PC = NNN
                // Calls a subroutine at the address NNN
                const nnn = opcode & 0x0FFF;
                self.stack[self.stack_pointer] = self.program_counter;
                self.stack_pointer += 1;
                self.program_counter = nnn;
            },
            0x3 => {
                // SE : Flow : if(VX == NN) PC += 2
                // Skips the next instruction if VX equals NN
                const nn = opcode & 0x00FF;
                const x = (opcode >> 8) & 0x0F;
                if (self.registers[x] == nn) {
                    self.program_counter += 2;
                }
            },
            0x4 => {
                // SNE : Flow : if(VX != NN) PC += 2
                // Skips the next instruction if VX does not equal NN
                const nn = opcode & 0x00FF;
                const x = (opcode >> 8) & 0x0F;
                if (self.registers[x] != nn) {
                    self.program_counter += 2;
                }
            },
            0x5 => {
                // SE : Flow : if(VX == VY) PC += 2
                // Skips the next instruction if VX equals VY
                const x = (opcode >> 8) & 0x0F;
                const y = (opcode >> 4) & 0x0F;
                if (self.registers[x] == self.registers[y]) {
                    self.program_counter += 2;
                }
            },
            0x6 => {
                // LD : MEM : VX = NN
                // Sets VX to the value NN
                const nn = opcode & 0x00FF;
                const x = (opcode >> 8) & 0x0F;
                self.registers[x] = nn;
            },
            0x7 => {
                // ADD : MEM : VX = VX + NN
                // Adds the value NN to VX
                const nn = opcode & 0x00FF;
                const x = (opcode >> 8) & 0x0F;
                self.registers[x] += nn;
            },
            0x8 => {
                const x = (opcode >> 8) & 0x0F;
                const y = (opcode >> 4) & 0x0F;
                if (opcode & 0x000F == 0x0000) {
                    // LD : MEM : VX = VY
                    // Sets VX to the value of VY
                    self.registers[x] = self.registers[y];
                } else if (opcode & 0x000F == 0x0001) {
                    // OR : MEM : VX = VX | VY
                    // Sets VX to the value of VX OR VY
                    self.registers[x] |= self.registers[y];
                } else if (opcode & 0x000F == 0x0002) {
                    // AND : MEM : VX = VX & VY
                    // Sets VX to the value of VX AND VY
                    self.registers[x] &= self.registers[y];
                } else if (opcode & 0x000F == 0x0003) {
                    // XOR : MEM : VX = VX ^ VY
                    // Sets VX to the value of VX XOR VY
                    self.registers[x] ^= self.registers[y];
                } else if (opcode & 0x000F == 0x0004) {
                    // ADD : MEM : VX = VX + VY
                    // Adds the value of VY to VX
                    self.registers[x] += self.registers[y];
                } else if (opcode & 0x000F == 0x0005) {
                    // SUB : MEM : VX = VX - VY
                    // Subtracts the value of VY from VX
                    self.registers[x] -= self.registers[y];
                } else if (opcode & 0x000F == 0x0006) {
                    // SHR : MEM : VX = VX >> 1
                    // Shifts VX right by one bit
                    self.registers[x] >>= 1;
                } else if (opcode & 0x000F == 0x0007) {
                    // SUBN : MEM : VX = VY - VX
                    // Subtracts the value of VX from VY
                    self.registers[x] = self.registers[y] - self.registers[x];
                } else if (opcode & 0x000F == 0x000E) {
                    // SHL : MEM : VX = VX << 1
                    // Shifts VX left by one bit
                    self.registers[x] <<= 1;
                }
            },
            0x9 => {
                // SNE : Flow : if(VX != VY) PC += 2
                // Skips the next instruction if VX does not equal VY
                const x = (opcode >> 8) & 0x0F;
                const y = (opcode >> 4) & 0x0F;
                if (self.registers[x] != self.registers[y]) {
                    self.program_counter += 2;
                }
            },

            0xA => {
                // ANNN : MEM : I = NNN
                // Sets I to the address NNN
                const nnn = opcode & 0x0FFF;
                self.index_register = nnn;
            },

            0xB => {
                // BNNN : Flow : PC = NNN + V0
                // Jumps to the address NNN + V0
                const nnn = opcode & 0x0FFF;
                self.program_counter = nnn + self.registers[0];
            },

            0xC => {
                // CxNN : Rand : VX = random(255) & NN
                // Sets VX to the result of a bitwise and operation on a random number
                const nn = opcode & 0x00FF;
                const x = (opcode >> 8) & 0x0F;
                self.registers[x] = std.math.random().randomBytes() & nn;
            },

            // DxyN : Display : draw(Vx, Vy, N)
            // Draws a sprite at coordinate (Vx, Vy) that has a width of 8 pixels and a height of N pixels. Each row of 8 pixels is read as bit-coded starting from memory location I; I value does not change after the execution of this instruction. As described above, VF is set to 1 if any screen pixels are flipped from set to unset when the sprite is drawn, and to 0 if that does not happen
            // Each sprite consists of 8-bit bytes, where each bit corresponds to a horizontal pixel; sprites are between 1 and 15 bytes tall. They’re drawn to the screen by treating all 0 bits as transparent, and all the 1 bits will “flip” the pixels in the locations of the screen that it’s drawn to.
            0xD => {
                const x = (opcode >> 8) & 0x0F;
                const y = (opcode >> 4) & 0x0F;
                const n = opcode & 0x0F;

                const sprite = self.memory[self.index_register .. self.index_register + n];

                for (0..n) |i| {
                    const row = sprite[i];
                    for (0..8) |j| {
                        const pixel = row & (1 << (7 - j));
                        if (pixel != 0) {
                            self.gfx[self.registers[x] + j][self.registers[y] + i] = 1;
                        }
                    }
                }

                self.draw_flag = true;
            },

            0xE => {
                // Ex9E : KeyOp
                // Skip next instruction if key with the value of VX is pressed
                // ExA1 : KeyOp
                // Skip next instruction if key with the value of VX is not pressed
                const x = (opcode >> 8) & 0x0F;
                const key_index = self.registers[x] & 0x0F;

                if ((opcode & 0x00FF == 0x009E and self.key[key_index]) or
                    (opcode & 0x00FF == 0x00A1 and !self.key[key_index]))
                {
                    self.program_counter += 2;
                }
            },

            0xF => {
                if (opcode & 0x00FF == 0x0007) {
                    // LD : MEM : VX = delay timer
                    // Sets VX to the value of the delay timer
                    const x = (opcode >> 8) & 0x0F;
                    self.registers[x] = self.delay_timer;
                } else if (opcode & 0x00FF == 0x000A) {
                    // LD : KeyOp : VX = get_key()
                    // A key press is awaited, and then stored in VX (blocking operation, all instruction halted until next key event, delay and sound timers should continue processing).
                    const x = (opcode >> 8) & 0x0F;
                    self.registers[x] = self.get_key();
                } else if (opcode & 0x00FF == 0x0015) {
                    // LD : MEM : delay timer = VX
                    // Sets the delay timer to VX
                    const x = (opcode >> 8) & 0x0F;
                    self.delay_timer = self.registers[x];
                } else if (opcode & 0x00FF == 0x0018) {
                    // LD : MEM : sound timer = VX
                    // Sets the sound timer to VX
                    const x = (opcode >> 8) & 0x0F;
                    self.sound_timer = self.registers[x];
                } else if (opcode & 0x00FF == 0x001E) {
                    // ADD : MEM : I = I + VX
                    // Adds VX to I
                    const x = (opcode >> 8) & 0x0F;
                    self.index_register += self.registers[x];
                } else if (opcode & 0x00FF == 0x0029) {
                    // LD : MEM : I = sprite_addr(VX)
                    // Sets I to the location of the sprite for the character in VX. Characters 0-F (in hexadecimal) are represented by a 4x5 font.
                    const x = (opcode >> 8) & 0x0F;
                    self.index_register = self.registers[x] * 5;
                } else if (opcode & 0x00FF == 0x0033) {
                    // LD : MEM : store BCD representation of VX in memory locations I, I+1, and I+2
                    // Stores the binary-coded decimal representation of VX, with the most significant of three digits at the address in I, the middle digit at I+1, and the least significant digit at I+2.
                    const x = (opcode >> 8) & 0x0F;
                    self.memory[self.index_register] = self.registers[x] / 100;
                    self.memory[self.index_register + 1] = (self.registers[x] / 10) % 10;
                    self.memory[self.index_register + 2] = self.registers[x] % 10;
                } else if (opcode & 0x00FF == 0x0055) {
                    // LD : MEM : [I] = V0 to VX
                    // Stores V0 to VX in memory starting at address I
                    const x = (opcode >> 8) & 0x0F;
                    for (0..x + 1) |i| {
                        self.memory[self.index_register + i] = self.registers[i];
                    }
                } else if (opcode & 0x00FF == 0x0065) {
                    // LD : MEM : V0 to VX = [I]
                    // Fills V0 to VX with values from memory starting at address I
                    const x = (opcode >> 8) & 0x0F;
                    for (0..x + 1) |i| {
                        self.registers[i] = self.memory[self.index_register + i];
                    }
                }
            },
        }
    }
};

fn setupGraphics() void {}

fn setupKeyboard() void {}

pub fn main() void {
    setupGraphics();
    setupKeyboard();

    const chip8 = Chip8.init();

    chip8.loadROM("roms/SpaceInvaders.ch8");

    std.debug.print("Chip8 initialized\n", .{});

    while (true) {
        chip8.emulateCycle();

        if (chip8.draw_flag) {
            // TODO: Draw to screen
        }
    }
}
