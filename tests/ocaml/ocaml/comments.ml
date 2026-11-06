(* A plain comment. *)
(** A doc comment that carries no tags.
    @satisfies not-read *)
(* @satisfies some-requirement
   A tagged comment over two lines. *)
(* outer (* nested *) outer *)
(***)
let s = "(* not a comment *)" (* A comment after code. *)
