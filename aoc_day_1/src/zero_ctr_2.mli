open! Core
open! Hardcaml

val input_dist_bits : int
val ctr_bits : int

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; valid_in : 'a
    ; is_left : 'a
    ; distance : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { zero_cnt : 'a
    ; cur_pos : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical : Scope.t -> Signal.t I.t -> Signal.t O.t