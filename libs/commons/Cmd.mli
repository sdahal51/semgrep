(* Build "commands" to be executed by CapExec.ml (or UCmd.ml) *)

(* command name, e.g. "git" *)
type name = Name of string

(* command arguments *)
type args = string list

(* the whole command *)
type t = name * args

(* Cmd is a small wrapper around Bos.Cmd so we rely on Bos for
 * most operations
 *)
val bos_apply : (Bos.Cmd.t -> 'a) -> t -> 'a

type run_status = Bos.OS.Cmd.run_status

(* for error messages *)
val to_string : t -> string
