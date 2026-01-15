open! Core
open! Hardcaml
open! Signal

let max_distance = 1000
let lock_width = 100
let input_dist_bits = Int.ceil_log2 max_distance
let dist_bits = Int.ceil_log2 lock_width
let ctr_bits = Int.ceil_log2 (max_distance * 5000/ lock_width)

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; valid_in : 'a
    ; is_left : 'a
    ; distance : 'a [@bits input_dist_bits]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { zero_cnt : 'a [@bits ctr_bits]
    ; cur_pos : 'a [@bits dist_bits]
    }
  [@@deriving hardcaml]
end

let create scope ({ clock; clear; valid_in; is_left; distance } : _ I.t) : _ O.t =

  let%hw input_filtered, tmp_zero_cross_input =
    let rec mod100 depth x count =
      if depth <= 0
      then (x, count)
      else
        let%hw next_val, next_count = mod100 (depth - 1) (x -:. lock_width) (count +:. 1) in
        (mux2 (x <:. lock_width) x next_val, mux2 (x <:. lock_width) count next_count)
    in
    let%hw result, crossings = mod100 (max_distance/lock_width) distance (of_int_trunc ~width:ctr_bits 0) in
    (uresize ~width:dist_bits result, crossings)
  in

  let spec = Reg_spec.create ~clock ~clear () in

  let compute_next_pos cur =
    let%hw incremented = uresize ~width:(dist_bits+1) cur +: uresize ~width:(dist_bits+1) input_filtered in
    let%hw ret_dist_o = uresize ~width:dist_bits (mux2 (incremented >:. 99) (incremented -:. lock_width) incremented) in
    let%hw ret_dist_u = mux2 (cur <: input_filtered) (cur +:. lock_width -: input_filtered) (cur -: input_filtered) in
    mux2 is_left (ret_dist_u) (ret_dist_o)
  in

  let%hw cur_pos = reg_fb spec ~width:dist_bits ~enable:valid_in ~clear_to:(of_int_trunc ~width:dist_bits 50) ~f:compute_next_pos in

  let%hw incremented = uresize ~width:(dist_bits+1) cur_pos +: uresize ~width:(dist_bits+1) input_filtered in
  let%hw cross_from_increment = incremented >:. 99 in
  let%hw cross_from_left = (cur_pos <=: input_filtered) &: (cur_pos <>:. 0) in

  let%hw tmp_zero_cross_pos = uresize ~width:ctr_bits (mux2 is_left cross_from_left cross_from_increment) in
  let%hw tmp_zero_cross = tmp_zero_cross_input +: tmp_zero_cross_pos in

  let%hw zero_cnt = reg_fb spec ~width:ctr_bits ~enable:valid_in ~f:(
    fun d -> (d +: tmp_zero_cross)
  ) in
  { zero_cnt; cur_pos }
;;

let hierarchical scope =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~scope ~name:"zero_ctr" create
;;