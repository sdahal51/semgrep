(* Yoann Padioleau
 *
 * Copyright (C) 2020 r2c
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file LICENSE.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * LICENSE for more details.
 *)

let tags = Logs_.create_tags [ __MODULE__ ]

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* A few helpers to help factorize code between the different
 * Parse_xxx_tree_sitter.ml files.
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)
type 'a env = {
  (* TODO: use Fpath.t *)
  file : string; (* filename *)
  (* get the charpos (offset) in file given a line x col *)
  conv : int * int -> int;
  extra : 'a;
}

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(* mostly a copy-paste of Pos.full_charpos_to_pos_large *)
let line_col_to_pos file =
  let size = UFile.filesize (Fpath.v file) + 2 in
  let h = Hashtbl.create size in
  UCommon.with_open_infile file (fun chan ->
      let charpos = ref 0 in
      let line = ref 0 in

      let full_charpos_to_pos_aux () =
        try
          while true do
            let s = input_line chan in
            incr line;

            (* '... +1 do'  cos input_line dont return the trailing \n *)
            for i = 0 to String.length s - 1 + 1 do
              Hashtbl.add h (!line, i) (!charpos + i)
            done;
            charpos := !charpos + String.length s + 1
          done
        with
        | End_of_file ->
            (* We need to add this in case there is a trailing \n in the
               end of the file *)
            Hashtbl.add h (!line + 1, 0) !charpos
      in
      full_charpos_to_pos_aux ());
  Hashtbl.find h

(* Patterns are given as a one line string with `\n` characters *)
let line_col_to_pos_pattern _str (_line, col) = col

let token env (tok : Tree_sitter_run.Token.t) =
  let loc, str = tok in
  let h = env.conv in
  let start = loc.Tree_sitter_run.Loc.start in
  (* Parse_info is 1-line based and 0-column based, like Emacs *)
  let line = start.Tree_sitter_run.Loc.row + 1 in
  let column = start.Tree_sitter_run.Loc.column in
  let file = env.file in
  let bytepos =
    try h (line, column) with
    | Not_found ->
        raise
          (Tok.NoTokenLocation
             (Printf.sprintf
                "Could not convert from location %d:%d in %s to a position" line
                column file))
  in
  let pos = Pos.make ~line ~column ~file bytepos in
  let tok_loc = { Tok.str; pos } in
  Tok.tok_of_loc tok_loc

let str env (tok : Tree_sitter_run.Token.t) =
  let _, s = tok in
  (s, token env tok)

let debug_sexp_cst_after_error sexp_cst =
  let s = Printexc.get_backtrace () in
  UCommon.pr2 "Some constructs are not handled yet";
  UCommon.pr2 "CST was:";
  (* bugfix: do not use CST.dump_tree because it prints on stdout
   * and will mess up our interaction with semgrep python wrapper and
   * also for the parsing_stat CI job.
   *
   * alt: Use Print_sexp.to_stderr of martin
   *)
  UCommon.pr2 (Sexplib.Sexp.to_string_hum sexp_cst);
  UCommon.pr2 "Original backtrace:";
  UCommon.pr2 s

let wrap_parser tree_sitter_parser ast_mapper =
  let res : 'a Tree_sitter_run.Parsing_result.t = tree_sitter_parser () in
  let program =
    match res.program with
    | Some cst ->
        (if res.errors <> [] then
           let error_strs =
             List.map
               (fun err -> err.Tree_sitter_run.Tree_sitter_error.msg)
               res.errors
           in
           let error_str = String.concat "\n" error_strs in
           Logs.err (fun m ->
               m ~tags "Partial errors returned by Tree-sitter parser\n%s"
                 error_str));
        Some (ast_mapper cst)
    | None -> None
  in
  { res with program }

(* Stuff to put in entry point at the beginning:
   let todo _env _x = failwith "not implemented"

   let todo_any str t any =
     pr2 (AST.show_any any);
     raise (Parse_info.Ast_builder_error (str, t))

   let program =
   ...
   try
     program ...
   with
    (Failure "not implemented") as exn ->
      H.debug_sexp_cst_after_error (CST.sexp_of_program cst);
      raise exn
*)
