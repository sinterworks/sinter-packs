open Alcotest

let unit_tests =
  [
    Alcotest.test_case "adds" `Quick (fun () -> ());
    test_case "subtracts" `Slow (fun () -> ());
    Alcotest.test_case "quote \"in\" name" `Quick (fun () -> ());
    test_case "" `Quick (fun () -> ());
    Alcotest.test_case "infix" `Quick @@ fun () -> ();
  ]

let property =
  QCheck.Test.make ~count:10 ~name:"reverses twice" QCheck.(list int) (fun l ->
      List.rev (List.rev l) = l)

let other = QCheck.Test.make ~name:"tab\there" QCheck.int (fun _ -> true)

let not_a_test = List.map (fun x -> x) [ "a" ]

let no_name = QCheck.Test.make QCheck.int (fun _ -> true)

let generated =
  List.map
    (fun i -> Alcotest.test_case (Printf.sprintf "case %d" i) `Quick (fun () -> ()))
    [ 1; 2 ]

let named name = Alcotest.test_case name `Slow (fun () -> ())

let quoted = Alcotest.test_case {|quoted "text"|} `Quick (fun () -> ())

let punned name = QCheck.Test.make ~name QCheck.int (fun _ -> true)

let computed = QCheck.Test.make ~name:(prefix ^ "x") QCheck.int (fun _ -> true)

let quoted_property = QCheck.Test.make ~name:{|quoted|} QCheck.int (fun _ -> true)

let quoted_slow = Alcotest.test_case {|quoted slow|} `Slow (fun () -> ())

let from_field t = Alcotest.test_case t.name `Quick (fun () -> ())

let from_field_slow t = test_case t.name `Slow (fun () -> ())

let property_of_field t = QCheck.Test.make ~name:t.name QCheck.int (fun _ -> true)

let property_of_value n = QCheck.Test.make ~name:n QCheck.int (fun _ -> true)

let () =
  Alcotest.run "suite"
    [
      ("unit", unit_tests);
      ("inline", [ Alcotest.test_case "inline test" `Slow (fun () -> ()) ]);
      "bare pair", [ test_case "bare" `Quick (fun () -> ()) ];
      ("qcheck", [ QCheck_alcotest.to_alcotest property ]);
      ("tab\tgroup", [ test_case "in tab group" `Quick (fun () -> ()) ]);
      ({|quoted group|}, [ test_case "in quoted group" `Quick (fun () -> ()) ]);
      {|bare quoted group|}, [ test_case "in bare quoted group" `Quick (fun () -> ()) ];
      (group_name, [ test_case "in named group" `Quick (fun () -> ()) ]);
      config.title, [ test_case "in field group" `Quick (fun () -> ()) ];
      (Printf.sprintf "group %d" 1, [ test_case "in computed group" `Quick (fun () -> ()) ]);
      (prefix ^ " group", [ test_case "in joined group" `Quick (fun () -> ()) ]);
      ((prefix ^ " bracketed"), [ test_case "in bracketed group" `Quick (fun () -> ()) ]);
    ]
