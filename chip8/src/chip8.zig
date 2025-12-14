const std = @import("std");
const fmt = std.fmt;

const HALLOC = std.heap.page_allocator;

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

const EMPTY_GFX: [32][64]bool = std.mem.zeroes([32][64]bool);
const EMPTY_KEY: [16]bool = std.mem.zeroes([16]bool);

const PROGRAM_START = 0x200; // 512

pub const Chip8 = struct {

    // +---------------+= 0xFFF (4095) End of Chip-8 RAM
    // |               |
    // | Program / Data|
    // |     Space     |
    // |               |
    // +---------------+= 0x200 (512) Start of most Chip-8 programs
    // | 0x000 to 0x1FF|
    // | Reserved for  |
    // |  interpreter  |
    // +---------------+= 0x000 (0) Start of Chip-8 RAM
    memory: [4096]u8, // Chip8 has 4096 bytes of memory

    program_len: u16,

    registers: [16]u8, // 16 general purpose registers (V0 - VF)
    index_register: u16, // Points to memory location (12-bit used)

    gfx: [32][64]bool, // The display is 64 pixels wide and 32 pixels tall.

    // The stack is an array of 16 16-bit values (12-bit),
    // used to store the address that the interpreter should
    // return to when finished with a subroutine.
    // Chip-8 allows for up to 16 levels of nested subroutines.
    stack: [16]u16,
    stack_pointer: u8, // Points to the top of the stack

    program_counter: u16, // Points at the current instruction in memory (12-bit used)

    key: [16]bool, // Chip8 has a keyboard
    last_key: ?u8,

    delay_timer: u8, // An 8-bit delay timer which is decremented at a rate of 60 Hz until it reaches 0
    sound_timer: u8, // An 8-bit sound timer which functions like the delay timer, but also gives off a beeping sound as long as it’s not 0

    draw_flag: bool, // Chip8 has a draw flag

    pub fn init() Chip8 {
        var chip8 = Chip8{
            .memory = std.mem.zeroes([4096]u8),
            .program_len = 0,
            .registers = std.mem.zeroes([16]u8),
            .gfx = EMPTY_GFX,
            .stack = std.mem.zeroes([16]u16),
            .stack_pointer = 0,
            .program_counter = PROGRAM_START, // Program counter starts at 512
            .index_register = 0,
            .key = std.mem.zeroes([16]bool),
            .last_key = null,
            .delay_timer = 0,
            .sound_timer = 0,
            .draw_flag = false,
        };

        // Load fontset
        @memcpy(chip8.memory[0..FONTSET.len], &FONTSET);

        return chip8;
    }

    pub fn loadROM(self: *Chip8, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const program_len = try file.readAll(self.memory[PROGRAM_START..]);
        self.program_len = @as(u16, @intCast(program_len));

        try self.disassemble(path);

        try testAssemble();
    }

    // Emulate a single cycle
    // Fetch the next instruction
    // Decode the instruction
    // Execute the instruction
    pub fn emulateCycle(self: *Chip8) void {
        self.decodeAndExecute();

        if (self.delay_timer > 0) {
            self.delay_timer -= 1;
        }
        if (self.sound_timer > 0) {
            self.sound_timer -= 1;
        }
    }

    fn wait_for_key(self: *Chip8) u8 {
        if (self.last_key) |key| {
            self.last_key = null;
            return key;
        } else {
            self.program_counter -= 2;
            return 0;
        }
    }

    pub fn set_key(self: *Chip8, key: u8) void {
        // self.key = EMPTY_KEY;
        self.key[key] = true;
        self.last_key = key;
    }

    pub fn reset_keys(self: *Chip8) void {
        self.key = EMPTY_KEY;
        // Don't reset last_key here - it needs to persist for wait_for_key instruction
    }

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
    fn decodeAndExecute(self: *Chip8) void {

        // 16 bits opcode
        const opcode: u16 = @as(u16, self.memory[self.program_counter]) << 8
            //
        | self.memory[self.program_counter + 1];

        const code = opcode >> 12; // First 4 bits out of 16

        self.program_counter += 2;

        const nnn = opcode & 0x0FFF;
        const nn = opcode & 0x00FF;
        const n = opcode & 0x000F;
        const x = (opcode >> 8) & 0x000F;
        const y = (opcode >> 4) & 0x000F;

        switch (code) {
            0x0 => {
                if (opcode == 0x00E0) {
                    // CLS : Display : clear()
                    // Clears the screen
                    self.gfx = EMPTY_GFX;
                } else if (opcode == 0x00EE) {
                    // RET : Flow : PC = stack[SP]; SP--
                    // Returns from a subroutine

                    // ~~~~~~~~~~~~~~~~~~~~~~
                    self.stack_pointer -= 1;
                    self.program_counter = self.stack[self.stack_pointer];
                    // self.program_counter = self.stack[self.stack_pointer];
                    // self.stack_pointer -= 1;
                    // ~~~~~~~~~~~~~~~~~~~~~~
                }
            },
            0x1 => {
                // JP : Flow : PC = NNN
                // Jumps to the address NNN
                self.program_counter = nnn;
            },
            0x2 => {
                // CALL : Flow : stack[SP] = PC; SP++; PC = NNN
                // Calls a subroutine at the address NNN
                self.stack[self.stack_pointer] = self.program_counter;
                self.stack_pointer += 1;
                self.program_counter = nnn;
            },
            0x3 => {
                // SE : Flow : if(VX == NN) PC += 2
                // Skips the next instruction if VX equals NN
                if (self.registers[x] == nn) {
                    self.program_counter += 2;
                }
            },
            0x4 => {
                // SNE : Flow : if(VX != NN) PC += 2
                // Skips the next instruction if VX does not equal NN
                if (self.registers[x] != nn) {
                    self.program_counter += 2;
                }
            },
            0x5 => {
                // SE : Flow : if(VX == VY) PC += 2
                // Skips the next instruction if VX equals VY
                if (self.registers[x] == self.registers[y]) {
                    self.program_counter += 2;
                }
            },
            0x6 => {
                // LD : MEM : VX = NN
                // Sets VX to the value NN
                self.registers[x] = @intCast(nn);
            },
            0x7 => {
                // ADD : MEM : VX = VX + NN
                // Adds the value NN to VX
                //~~~~~~~~~~~~~~~~~~~~~~~~~~
                self.registers[x] +%= @intCast(nn);
                //~~~~~~~~~~~~~~~~~~~~~~~~~~
            },
            0x8 => {
                if (n == 0x0000) {
                    // LD : MEM : VX = VY
                    // Sets VX to the value of VY
                    self.registers[x] = self.registers[y];
                } else if (n == 0x0001) {
                    // OR : MEM : VX = VX | VY
                    // Sets VX to the value of VX OR VY
                    self.registers[x] |= self.registers[y];
                } else if (n == 0x0002) {
                    // AND : MEM : VX = VX & VY
                    // Sets VX to the value of VX AND VY
                    self.registers[x] &= self.registers[y];
                } else if (n == 0x0003) {
                    // XOR : MEM : VX = VX ^ VY
                    // Sets VX to the value of VX XOR VY
                    self.registers[x] ^= self.registers[y];
                } else if (n == 0x0004) {
                    // ADD : MEM : VX = VX + VY
                    // Adds the value of VY to VX
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                    self.registers[x], self.registers[15] = @addWithOverflow(self.registers[x], self.registers[y]);
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                } else if (n == 0x0005) {
                    // SUB : MEM : VX = VX - VY
                    // Subtracts the value of VY from VX
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                    self.registers[x], self.registers[15] = @subWithOverflow(self.registers[x], self.registers[y]);
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                } else if (n == 0x0006) {
                    // SHR : MEM : VX = VX >> 1
                    // Shifts VX right by one bit
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                    self.registers[15] = self.registers[x] & 1;
                    self.registers[x] >>= 1;
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                } else if (n == 0x0007) {
                    // SUBN : MEM : VX = VY - VX
                    // Subtracts the value of VX from VY
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                    self.registers[x], self.registers[15] = @subWithOverflow(self.registers[y], self.registers[x]);
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                } else if (n == 0x000E) {
                    // SHL : MEM : VX = VX << 1
                    // Shifts VX left by one bit
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                    self.registers[15] = self.registers[x] & 0b10000000;
                    self.registers[x] <<= 1;
                    //~~~~~~~~~~~~~~~~~~~~~~~~~~
                }
            },
            0x9 => {
                // SNE : Flow : if(VX != VY) PC += 2
                // Skips the next instruction if VX does not equal VY
                if (self.registers[x] != self.registers[y]) {
                    self.program_counter += 2;
                }
            },

            0xA => {
                // ANNN : MEM : I = NNN
                // Sets I to the address NNN
                self.index_register = nnn;
            },

            0xB => {
                // BNNN : Flow : PC = NNN + V0
                // Jumps to the address NNN + V0
                self.program_counter = nnn + self.registers[0];
            },

            0xC => {
                // CxNN : Rand : VX = random(255) & NN
                // Sets VX to the result of a bitwise and operation on a random number
                self.registers[x] = std.crypto.random.int(u8) & @as(u8, @intCast(nn));
            },

            0xD => {
                // DxyN : Display : draw(Vx, Vy, N)

                // Draws a sprite at coordinate (Vx, Vy) that has a width of 8 pixels and a height of N (1-15) pixels.
                // Each row of 8 pixels is read as bit-coded starting from memory location I;
                // I value does not change after the execution of this instruction.

                // They’re drawn to the screen by treating all 0 bits as transparent, and all the
                // 1 bits will “flip” the pixels in the locations of the screen that it’s drawn to.

                // If the pixel is in memory is already set, collision is reported by setting the
                // VF register to 1.

                const start_x = self.registers[x];
                const start_y = self.registers[y];

                // Reset collision register
                self.registers[15] = 0;

                var pixel: u8 = undefined;
                for (0..n) |y_offset| {
                    pixel = self.memory[self.index_register + y_offset];
                    for (0..8) |x_offset| {
                        if ((pixel >> @as(u3, @intCast(7 - x_offset)) & 1) == 1) {
                            const target_x = (start_x + x_offset) % 64;
                            const target_y = (start_y + y_offset) % 32;

                            if (self.gfx[target_y][target_x]) {
                                self.registers[15] = 1;
                            }

                            self.gfx[target_y][target_x] ^= true;
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
                const key_index = self.registers[x] & 0x0F;

                if ((nn == 0x009E and self.key[key_index]) or
                    (nn == 0x00A1 and !self.key[key_index]))
                {
                    self.program_counter += 2;
                }
            },

            0xF => {
                if (nn == 0x0007) {
                    // LD : MEM : VX = delay timer
                    // Sets VX to the value of the delay timer
                    self.registers[x] = self.delay_timer;
                } else if (nn == 0x000A) {
                    // LD : KeyOp : VX = get_key()
                    // A key press is awaited, and then stored in VX (blocking operation, all instruction halted until next key event, delay and sound timers should continue processing).
                    self.registers[x] = self.wait_for_key();
                } else if (nn == 0x0015) {
                    // LD : MEM : delay timer = VX
                    // Sets the delay timer to VX
                    self.delay_timer = self.registers[x];
                } else if (nn == 0x0018) {
                    // LD : MEM : sound timer = VX
                    // Sets the sound timer to VX
                    self.sound_timer = self.registers[x];
                } else if (nn == 0x001E) {
                    // ADD : MEM : I = I + VX
                    // Adds VX to I
                    self.index_register += self.registers[x];
                } else if (nn == 0x0029) {
                    // LD : MEM : I = sprite_addr(VX)
                    // Sets I to the location of the sprite for the character in VX. Characters 0-F (in hexadecimal) are represented by a 4x5 font.
                    self.index_register = self.registers[x] * 5;
                } else if (nn == 0x0033) {
                    // LD : MEM : store BCD representation of VX in memory locations I, I+1, and I+2
                    // Stores the binary-coded decimal representation of VX, with the most significant of three digits at the address in I, the middle digit at I+1, and the least significant digit at I+2.
                    self.memory[self.index_register] = (self.registers[x] / 100) % 10;
                    self.memory[self.index_register + 1] = (self.registers[x] / 10) % 10;
                    self.memory[self.index_register + 2] = self.registers[x] % 10;
                } else if (nn == 0x0055) {
                    // LD : MEM : [I] = V0 to VX
                    // Stores V0 to VX in memory starting at address I
                    for (0..x + 1) |i| {
                        self.memory[self.index_register + i] = self.registers[i];
                    }
                } else if (nn == 0x0065) {
                    // LD : MEM : V0 to VX = [I]
                    // Fills V0 to VX with values from memory starting at address I
                    for (0..x + 1) |i| {
                        self.registers[i] = self.memory[self.index_register + i];
                    }
                }
            },
            else => {
                std.debug.print("Unknown opcode: {X:0>4}\n", .{opcode});
            },
        }
    }

    pub fn disassemble(self: *Chip8, path: []const u8) !void {
        const disassemblyFilePath = try fmt.allocPrint(HALLOC, "{s}.txt", .{path});
        defer HALLOC.free(disassemblyFilePath);

        const buffer_size = 16 * 1024; // 16 KB buffer
        var buffer: [buffer_size]u8 = undefined;
        var file = try std.fs.cwd().createFile(disassemblyFilePath, .{});
        defer file.close();
        var out = file.writer(&buffer);

        for (PROGRAM_START..PROGRAM_START + self.program_len) |i| {
            const opcode: u16 = @as(u16, self.memory[i]) << 8 | self.memory[i + 1];

            const code = opcode >> 12; // First 4 bits out of 16

            const nnn = opcode & 0x0FFF;
            const nn = opcode & 0x00FF;
            const n = opcode & 0x000F;
            const x = (opcode >> 8) & 0x000F;
            const y = (opcode >> 4) & 0x000F;

            switch (code) {
                0x0 => {
                    if (opcode == 0x00E0) {
                        // CLS : Display : clear()
                        // Clears the screen
                        try out.interface.print("CLS\n", .{});
                    } else if (opcode == 0x00EE) {
                        // RET : Flow : PC = stack[SP]; SP--
                        // Returns from a subroutine
                        try out.interface.print("RET\n", .{});
                    }
                },
                0x1 => {
                    // JP : Flow : PC = NNN
                    // Jumps to the address NNN
                    try out.interface.print("JP {X:0>4}\n", .{nnn});
                },
                0x2 => {
                    // CALL : Flow : stack[SP] = PC; SP++; PC = NNN
                    // Calls a subroutine at the address NNN
                    try out.interface.print("CALL {X:0>4}\n", .{nnn});
                },
                0x3 => {
                    // SE : Flow : if(VX == NN) PC += 2
                    // Skips the next instruction if VX equals NN
                    try out.interface.print("SE V{X} {X:0>4}\n", .{ x, nn });
                },
                0x4 => {
                    // SNE : Flow : if(VX != NN) PC += 2
                    // Skips the next instruction if VX does not equal NN
                    try out.interface.print("SNE V{X} {X:0>4}\n", .{ x, nn });
                },
                0x5 => {
                    // SE : Flow : if(VX == VY) PC += 2
                    // Skips the next instruction if VX equals VY
                    try out.interface.print("SE V{X} V{X}\n", .{ x, y });
                },
                0x6 => {
                    // LD : MEM : VX = NN
                    // Sets VX to the value NN
                    try out.interface.print("LD V{X} {X:0>4}\n", .{ x, nn });
                },
                0x7 => {
                    // ADD : MEM : VX = VX + NN
                    // Adds the value NN to VX
                    try out.interface.print("ADD V{X} {X:0>4}\n", .{ x, nn });
                },
                0x8 => {
                    if (n == 0x0000) {
                        // LD : MEM : VX = VY
                        // Sets VX to the value of VY
                        try out.interface.print("LD V{X} V{X}\n", .{ x, y });
                    } else if (n == 0x0001) {
                        // OR : MEM : VX = VX | VY
                        // Sets VX to the value of VX OR VY
                        try out.interface.print("OR V{X} V{X}\n", .{ x, y });
                    } else if (n == 0x0002) {
                        // AND : MEM : VX = VX & VY
                        // Sets VX to the value of VX AND VY
                        try out.interface.print("AND V{X} V{X}\n", .{ x, y });
                    } else if (n == 0x0003) {
                        // XOR : MEM : VX = VX ^ VY
                        // Sets VX to the value of VX XOR VY
                        try out.interface.print("XOR V{X} V{X}\n", .{ x, y });
                    } else if (n == 0x0004) {
                        // ADD : MEM : VX = VX + VY
                        // Adds the value of VY to VX
                        try out.interface.print("ADD V{X} V{X}\n", .{ x, y });
                    } else if (n == 0x0005) {
                        // SUB : MEM : VX = VX - VY
                        // Subtracts the value of VY from VX
                        try out.interface.print("SUB V{X} V{X}\n", .{ x, y });
                    } else if (n == 0x0006) {
                        // SHR : MEM : VX = VX >> 1
                        // Shifts VX right by one bit
                        try out.interface.print("SHR V{X} V{X}\n", .{ x, y });
                    } else if (n == 0x0007) {
                        // SUBN : MEM : VX = VY - VX
                        // Subtracts the value of VX from VY
                        try out.interface.print("SUBN V{X} V{X}\n", .{ x, y });
                    } else if (n == 0x000E) {
                        // SHL : MEM : VX = VX << 1
                        // Shifts VX left by one bit
                        try out.interface.print("SHL V{X} V{X}\n", .{ x, y });
                    }
                },
                0x9 => {
                    // SNE : Flow : if(VX != VY) PC += 2
                    // Skips the next instruction if VX does not equal VY
                    try out.interface.print("SNE V{X} V{X}\n", .{ x, y });
                },
                0xA => {
                    // ANNN : MEM : I = NNN
                    // Sets I to the address NNN
                    try out.interface.print("LD I {X:0>4}\n", .{nnn});
                },
                0xB => {
                    // BNNN : Flow : PC = NNN + V0
                    // Jumps to the address NNN + V0
                    try out.interface.print("JP V0 {X:0>4}\n", .{nnn});
                },
                0xC => {
                    // CxNN : Rand : VX = random(255) & NN
                    // Sets VX to the result of a bitwise and operation on a random number
                    try out.interface.print("RND V{X} {X:0>4}\n", .{ x, nn });
                },

                0xD => {
                    // DxyN : Display : draw(Vx, Vy, N)
                    try out.interface.print("DRW V{X} V{X} {X:0>4}\n", .{ x, y, n });
                },
                0xE => {
                    // Ex9E : KeyOp
                    // Skip next instruction if key with the value of VX is pressed
                    // ExA1 : KeyOp
                    // Skip next instruction if key with the value of VX is not pressed

                    if (nn == 0x009E) {
                        try out.interface.print("SKP V{X}\n", .{x});
                    }
                    if (nn == 0x00A1) {
                        try out.interface.print("SKNP V{X}\n", .{x});
                    }
                },

                0xF => {
                    if (nn == 0x0007) {
                        // LD : MEM : VX = delay timer
                        // Sets VX to the value of the delay timer
                        try out.interface.print("LD V{X} DT\n", .{x});
                    } else if (nn == 0x000A) {
                        // LD : KeyOp : VX = get_key()
                        // A key press is awaited, and then stored in VX (blocking operation, all instruction halted until next key event, delay and sound timers should continue processing).
                        try out.interface.print("LD V{X} K\n", .{x});
                    } else if (nn == 0x0015) {
                        // LD : MEM : delay timer = VX
                        // Sets the delay timer to VX
                        try out.interface.print("LD DT V{X}\n", .{x});
                    } else if (nn == 0x0018) {
                        // LD : MEM : sound timer = VX
                        // Sets the sound timer to VX
                        try out.interface.print("LD ST V{X}\n", .{x});
                    } else if (nn == 0x001E) {
                        // ADD : MEM : I = I + VX
                        // Adds VX to I
                        try out.interface.print("ADD I V{X}\n", .{x});
                    } else if (nn == 0x0029) {
                        // LD : MEM : I = sprite_addr(VX)
                        // Sets I to the location of the sprite for the character in VX. Characters 0-F (in hexadecimal) are represented by a 4x5 font.
                        try out.interface.print("LD I sprite_addr(V{X})\n", .{x});
                    } else if (nn == 0x0033) {
                        // LD : MEM : store BCD representation of VX in memory locations I, I+1, and I+2
                        // Stores the binary-coded decimal representation of VX, with the most significant of three digits at the address in I, the middle digit at I+1, and the least significant digit at I+2.
                        try out.interface.print("LD BCD V{X}\n", .{x});
                    } else if (nn == 0x0055) {
                        // LD : MEM : [I] = V0 to VX
                        // Stores V0 to VX in memory starting at address I
                        try out.interface.print("LD [I] V{X}\n", .{x});
                    } else if (nn == 0x0065) {
                        // LD : MEM : V0 to VX = [I]
                        // Fills V0 to VX with values from memory starting at address I
                        try out.interface.print("LD V{X} [I]\n", .{x});
                    }
                },
                else => {},
            }
        }

        // Flush buffer to file
        try out.interface.flush();
    }
};

fn assemble(program: []const u16, path: []const u8) !void {
    const buffer_size = 16 * 1024; // 16 KB buffer
    var buffer: [buffer_size]u8 = undefined;
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    var out = file.writer(&buffer);

    for (program) |byte| {
        try out.interface.writeByte(@intCast(byte >> 8));
        try out.interface.writeByte(@intCast(byte & 0xFF));
    }

    // Flush buffer to file
    try out.interface.flush();
}

fn testAssemble() !void {
    // Converts the Hex number at address 0003H to Decimal. Displays the result on the screen.
    // 0200 00E0 6380 6400 6500 A500 F333 F265 F029
    // 0210 D455 F129 7408 D455 F229 7408 D455 F000
    const HexToDecimal: []const u16 = &[_]u16{ 0x200, 0x00E0, 0x6380, 0x6400, 0x6500, 0xA500, 0xF333, 0xF265, 0xF029, 0x0210, 0xD455, 0xF129, 0x7408, 0xD455, 0xF229, 0x7408, 0xD455, 0xF000 };
    try assemble(HexToDecimal, "roms/HexToDecimal.ch8");

    const LittleLamb: []const u16 = &[_]u16{ 0x6500, 0xA300, 0x7501, 0x2210, 0x3523, 0x1204, 0xF000, 0x0000, 0x6000, 0x6110, 0x6201, 0xF065, 0xF017, 0xF118, 0xF21E, 0x63F4, 0x6400, 0x7401, 0x34FF, 0x1222, 0x7301, 0x33FF, 0x1220, 0x00EE, 0x1110, 0x0F10, 0x1111, 0x1100, 0x0010, 0x1010, 0x0011, 0x1313, 0x0000, 0x1110, 0x0F10, 0x1111, 0x1100, 0x0011, 0x1010, 0x1110, 0x0F00, 0x0000 };
    try assemble(LittleLamb, "roms/LittleLamb.ch8");
}
