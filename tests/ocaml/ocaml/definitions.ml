(** Returns its input. *)
let plain x = x

let rec even n = n = 0 || odd (n - 1)
and odd n = n <> 0 && even (n - 1)

let ( +! ) a b = a + b

let () = print_endline "run"

let (first, second) = (1, 2)

let local =
  let inner = 1 in
  inner

type t = int

and u = A | B of t

type 'a box = { value : 'a }

type abstract

module M = struct
  let in_module = 1
end

module F (X : sig end) = struct end

module type S = sig
  val x : int
end

class counter = object
  method get = 0
end

external length : string -> int = "caml_ml_string_length"

exception Failed of string

exception Stop
