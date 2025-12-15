#include "Vdemohdl_Top.h"
#include "Vdemohdl_Top___024root.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <stdio.h>

// Global simulation time
static int sim_time = 0;

// Test combinational logic gates
void test_gates(Vdemohdl_Top *dut, VerilatedVcdC *tfp) {
  printf("\n=== Logic Gates Test ===\n");
  printf(" a | b | AND | OR | XOR | NOT | NAND | NOR | XNOR\n");
  printf("---|---|-----|----|-----|-----|------|-----|-----\n");

  for (int a = 0; a <= 1; a++) {
    for (int b = 0; b <= 1; b++) {
      dut->gate_a = a;
      dut->gate_b = b;
      dut->eval();
      tfp->dump(sim_time++);

      printf(" %d | %d |  %d  | %d  |  %d  |  %d  |   %d  |  %d  |   %d\n", a,
             b, dut->gate_and, dut->gate_or, dut->gate_xor, dut->gate_not,
             dut->gate_nand, dut->gate_nor, dut->gate_xnor);
    }
  }
}

// Test sequential counter with delays
void test_counter(Vdemohdl_Top *dut, VerilatedVcdC *tfp) {
  printf("\n=== Counter & Delay Test ===\n");

  // Reset phase (active-low)
  dut->i_clk = 0;
  dut->i_rst = 0;
  for (int i = 0; i < 10; i++) {
    dut->i_clk = !dut->i_clk;
    dut->eval();
    tfp->dump(sim_time++);
  }

  // Release reset
  dut->i_rst = 1;

  printf("Cycle | cnt | delay1 | delay3\n");
  printf("------|-----|--------|-------\n");

  int cycle = 0;
  for (int i = 0; i < 50; i++) {
    dut->i_clk = !dut->i_clk;
    dut->eval();
    tfp->dump(sim_time++);

    if (dut->i_clk && cycle < 15) {
      printf("%5d | %3d | %6d | %6d\n", cycle,
             dut->rootp->demohdl_Top__DOT__cnt,
             dut->rootp->demohdl_Top__DOT__delayed_1,
             dut->rootp->demohdl_Top__DOT__delayed_3);
      cycle++;
    }
  }
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  Vdemohdl_Top *dut = new Vdemohdl_Top;
  Verilated::traceEverOn(true);

  VerilatedVcdC *tfp = new VerilatedVcdC;
  dut->trace(tfp, 99);
  tfp->open("vcd/wave.vcd");

  // Run tests
  test_gates(dut, tfp);
  test_counter(dut, tfp);

  tfp->close();
  delete dut;
  printf("\nWaveform saved to vcd/wave.vcd\n");
  return 0;
}
