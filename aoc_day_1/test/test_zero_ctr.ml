open! Core
open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness
module Zero_ctr = Aoc_1.Zero_ctr
module Harness = Cyclesim_harness.Make (Zero_ctr.I) (Zero_ctr.O)

let ( <--. ) = Bits.( <--. )

let parse_puzzle_input filename =
  In_channel.read_lines filename
  |> List.map ~f:(fun line ->
    let direction = String.get line 0 in
    let distance = String.sub line ~pos:1 ~len:(String.length line - 1) |> Int.of_string in
    (Char.equal direction 'L', distance)
  )
  |> Array.of_list
;;

let puzzle_data = parse_puzzle_input "puzzle_input.txt"

let simple_testbench (sim : Harness.Sim.t) =
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  let cycle () = Cyclesim.cycle sim in

  let out_channel = Out_channel.create "/Users/pkarmehan/Desktop/HardCaml/aoc_day_1/test/hw_out.txt" in

  let feed_input n =
    let is_left, distance = puzzle_data.(n) in
    let direction_str = if is_left then "L" else "R" in
    inputs.valid_in := Bits.vdd;
    inputs.distance <--. distance;
    inputs.is_left <--. (if is_left then 1 else 0);
    cycle ();
    inputs.valid_in := Bits.gnd;
    let zero_cnt = Bits.to_unsigned_int !(outputs.zero_cnt) in
    let cur_pos = Bits.to_unsigned_int !(outputs.cur_pos) in
    Out_channel.fprintf out_channel "Move %d: %s%d -> pos: %d, zeros: %d\n" n direction_str distance cur_pos zero_cnt;
    cycle ();

  in

  (* reset *)
  inputs.clear := Bits.vdd;
  cycle ();
  inputs.clear := Bits.gnd;
  cycle ();

  for i = 0 to Int.min 100000 (Array.length puzzle_data - 1) do
    feed_input i
  done;

  cycle();
  Out_channel.close out_channel;
;;

let waves_config =
  Waves_config.to_directory "/tmp/"
  |> Waves_config.as_wavefile_format ~format:Vcd
;;

let%expect_test "Register 4-bit test - count 0 to 15 and back" =
  Harness.run_advanced ~waves_config ~create:Zero_ctr.hierarchical simple_testbench;
  [%expect {| Saved waves to /tmp/test_zero_ctr_ml_Register_4_bit_test___count_0_to_15_and_back.vcd |}]
;;