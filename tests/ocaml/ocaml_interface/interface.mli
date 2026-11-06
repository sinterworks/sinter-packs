(** A doc comment that carries no tags. *)
val plain : int -> int

(* @satisfies some-requirement *)
val ( +! ) : int -> int -> int

type t = int

and u = A | B of t

type abstract

module M : sig
  val in_module : int
end

module type S = sig
  val x : int
end

class counter : object
  method get : int
end

external length : string -> int = "caml_ml_string_length"

exception Failed of string
