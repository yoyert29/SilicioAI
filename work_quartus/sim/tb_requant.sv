// Testbench de requant: ReLU + reescalado + recorte a 0..127
// Cada caso compara la salida del modulo con un valor esperado
// calculado aqui mismo con la misma formula que train.py.
`timescale 1ns/1ps
`default_nettype none

module tb_requant;
  import nn_params_pkg::*;

  logic signed [31:0] acc;
  logic        [7:0]  h_q;

  int pass_count = 0;
  int fail_count = 0;

  // Modulo bajo prueba
  requant dut (.acc(acc), .h_q(h_q));

  // Modelo de referencia: igual que int_inference() en Python
  function automatic int modelo(input int a);
    longint r;
    if (a <= 0) return 0;                    // ReLU
    r = (longint'(a) * M1) >>> SHIFT;        // reescalado
    if (r > 127) return 127;                 // recorte
    return int'(r);
  endfunction

  // Aplica un valor, espera y compara
  task automatic probar(input int a);
    int esperado;
    acc = a;
    #10;
    esperado = modelo(a);
    if (h_q === esperado[7:0]) begin
      pass_count++;
      $display("PASS  acc = %6d  ->  h_q = %3d", a, h_q);
    end else begin
      fail_count++;
      $display("FAIL  acc = %6d  ->  h_q = %3d  (esperado %3d)", a, h_q, esperado);
    end
  endtask

  initial begin
    $display("M1 = %0d, SHIFT = %0d", M1, SHIFT);

    // 1) ReLU: negativos y cero deben dar 0
    probar(-100000);
    probar(-100);
    probar(-1);
    probar(0);

    // 2) Valores pequenos (el resultado redondea hacia abajo)
    probar(1);
    probar(4);
    probar(5);
    probar(100);

    // 3) Justo alrededor del limite de 127
    //    127 * 65536 / M1 = acc maximo que todavia no se recorta
    probar((127 * 65536) / M1);
    probar((127 * 65536) / M1 + 1);
    probar((128 * 65536) / M1 + 1);

    // 4) Valores grandes: deben quedarse en 127
    probar(700);
    probar(2500);
    probar(100000);

    // 5) 200 valores aleatorios entre -2000 y 2000
    repeat (200) probar($urandom_range(4000) - 2000);

    $display("--------------------------------");
    $display("Resultado: %0d PASS, %0d FAIL", pass_count, fail_count);
    if (fail_count == 0) $display("TODO CORRECTO");
    $finish;
  end
endmodule
