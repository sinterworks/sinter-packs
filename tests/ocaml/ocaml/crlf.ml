(* A comment. *)
(** A doc comment. *)
let crlf x =
  x

let tests = [ Alcotest.test_case "crlf" `Quick (fun () -> ()) ]
