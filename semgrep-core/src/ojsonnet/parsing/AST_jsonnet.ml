(* Yoann Padioleau
 *
 * Copyright (C) 2022 r2c
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

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* An Abstract Syntax Tree for Jsonnet (well kinda concrete actually).
 *
 * This AST/CST is mostly derived from the tree-sitter-jsonnet grammar:
 * https://github.com/sourcegraph/tree-sitter-jsonnet
 * I tried to keep the original terms (e.g., Local, hidden) instead of the
 * terms we use in AST_generic (e.g., Let, annotation).
 * See also the excellent spec: https://jsonnet.org/ref/spec.html
 * There is also an ANTLR grammar here:
 * https://gist.github.com/ironchefpython/84380aa60871853dc86719dd598c35e4
 * used in https://github.com/sourcegraph/lsif-jsonnet
 *
 * The main uses for this file are:
 *  - for Semgrep to allow people to use jsonnet patterns to match
 *    over Jsonnet code
 *  - TODO: potentially for implementing a Jsonnet interpreter in OCaml,
 *    so we can use it in osemgrep instead of having to write an OCaml
 *    binding to the Jsonnet C library. This could allow in turn to provide
 *    better error messages when there is an error in a Jsonnet
 *    semgrep rule. Indeed right now the error will be mostly
 *    reported on the resulting JSON.
 *)

(*****************************************************************************)
(* Token (leaf) *)
(*****************************************************************************)

type tok = Parse_info.t [@@deriving show]
type 'a wrap = 'a * tok [@@deriving show]
type 'a bracket = tok * 'a * tok [@@deriving show]

(*****************************************************************************)
(* Names *)
(*****************************************************************************)
(* very simple language, no qualified names here *)
type ident = string wrap [@@deriving show]

(*****************************************************************************)
(* Expressions *)
(*****************************************************************************)

(* Using a record from the start. This is not needed yet, but if
 * we implement a jsonnet interpreter, this might become useful.
 *)
type expr = { e : expr_kind }

(* very simple language, just expressions! no statement, no class def *)
and expr_kind =
  (* values *)
  | L of literal
  | O of obj_inside bracket
  | A of arr_inside bracket
  (* entities *)
  | Id of string wrap
  | IdSpecial of special wrap
  (* =~ Let. Note that a series of 'local x = 1; local y = 2; x+y'
   * will be interpreted as nested Local. There is no real
   * sequence operator in Jsonnet. The ';' is used only for
   * Local and for Assert.
   *)
  | Local of tok (* 'local' *) * bind list * tok (* ; *) * expr
  (* accesses *)
  | DotAccess of expr * tok (* '.' *) * ident
  | ArrayAccess of expr * expr bracket
  (* TODO: | SliceAccess of expr *  *)
  (* control flow *)
  | Call of expr * argument list bracket
  | UnaryOp of unary_op wrap * expr
  | BinaryOp of expr * binary_op wrap * expr
  | If of tok (* 'if' *) * expr * expr * (tok (* 'else' *) * expr) option
  (* TODO: expr { objinside } ?? *)
  (* TODO: expr in super ?? *)
  | Lambda of function_definition
  (* directives *)
  | I of import
  (* builtins *)
  | Assert of assert_ * tok (* ';' *) * expr
  | Error of tok (* 'error' *) * expr
  (* for the CST *)
  | ParenExpr of expr bracket
  | TodoExpr of string wrap * expr list

and literal =
  | Null of tok
  | Bool of bool wrap
  (* for integers and floats; no difference in jsonnet *)
  | Number of string wrap
  | Str of string_

and string_ = verbatim option * string_kind * string_content bracket
and verbatim = tok (* @ *)
and string_kind = SingleQuote | DoubleQuote | TripleBar (* a.k.a Text block *)

(* The string can contain escape sequences and also special chars (e.g., '%')
 * which are interpreted in a special way by certain builtins (e.g., format).
 * There is no string interpolation in Jsonnet, but the '%' can
 * be used for a similar purpose.
 *)
and string_content = string wrap list

(* Super can appear only in DotAccess/ArrayAccess/InSuper.
 * alt: we could make special constructs for those special Super cases.
 * However, in the spec they unsugar those constructs to a
 * "core" language where super is at the expression level, so this is
 * probably simpler to have it here instead of in 3 special constructs.
 *)
and special = Self | Super | Dollar (* ??? *)
and argument = Arg of expr | NamedArg of ident * tok (* = *) * expr

(* alt: we could reuse AST_generic_.ml, but because we might want to
 * make a jsonnet interpreter, better to be as precise as possible.
 *)
and unary_op = UPlus | UMinus | UBang | UTilde

and binary_op =
  | Plus
  | Minus
  | Mult
  | Div
  | Mod
  | LSL
  | LSR
  | Lt
  | LtE
  | Gt
  | GtE
  | Eq
  | NotEq
  (* TODO? in *)
  | And
  | Or
  | BitAnd
  | BitOr
  | BitXor

and assert_ = tok (* 'assert' *) * expr * (tok (* ':' *) * expr) option
and arr_inside = Array of expr list
(* TODO: ArrayComprenhension *)

(*****************************************************************************)
(* Definitions *)
(*****************************************************************************)

(* ------------------------------------------------------------------------- *)
(* Local binding *)
(* ------------------------------------------------------------------------- *)
and bind = unit

(* ------------------------------------------------------------------------- *)
(* Functions  *)
(* ------------------------------------------------------------------------- *)
and function_definition = {
  f_tok : tok;
  f_params : parameter list bracket;
  f_body : expr;
}

and parameter = unit

(* ------------------------------------------------------------------------- *)
(* Objects  *)
(* ------------------------------------------------------------------------- *)
and obj_inside = Object of object_member list
(* TODO: Object comprehension *)

and object_member = unit

and field = {
  fld_name : field_name;
  fld_attr : attribute option;
  fld_hidden : hidden wrap;
  (* can be a Lambda for methods *)
  fld_value : expr;
}

and field_name = FId of ident | FStr of string_ | FDynamic of expr bracket

(* =~ visibility *)
and hidden = Colon | TwoColons | ThreeColons

and attribute =
  (* concatenate fields, not valid for methods *)
  | PlusField of tok

(*****************************************************************************)
(* Directives *)
(*****************************************************************************)
and import =
  | Import of tok (* 'import' *) * string_ (* filename *)
  | ImportStr of tok (* 'importstr' *) * string_ (* content to evaluate? *)
[@@deriving show { with_path = false }]

(*****************************************************************************)
(* Program *)
(*****************************************************************************)

type program = expr [@@deriving show]

(*****************************************************************************)
(* Any (for semgrep) *)
(*****************************************************************************)
(* Right now there is just one case, but at some point we may want to
 * allow field patterns.
 *)
type any = E of expr

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

let e ekind = { e = ekind }