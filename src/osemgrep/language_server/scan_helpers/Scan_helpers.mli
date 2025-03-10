val run_semgrep :
  ?targets:Fpath.t list option ->
  ?rules:Rule.rules option ->
  ?git_ref:string option ->
  RPC_server.t ->
  Semgrep_output_v1_t.cli_match list * Fpath.t list
(** [run_semgrep server] runs semgrep on the given server. If [targets] is
  * provided, it will be used as the targets for semgrep. If [rules] is
  * provided, it will be used as the rules for semgrep. Otherwise, the rules
  * will be read from the config file. If [git_ref] is provided, it will be
  * used as the git ref for what matches are filtered out based on git diff.
  *)

val scan_workspace : RPC_server.t -> unit
(** [scan_workspace server] scans the workspace of the given session. *)

val scan_open_documents : RPC_server.t -> unit
(** [scan_open_documents server] scans the open documents of the given session. *)

val scan_file : RPC_server.t -> Lsp__Uri0.t -> unit
(** [scan_file server] scans the given file. If [content] is provided, it will
  * be used as the content of the file. Otherwise, the content will be read
  * from the file system.
  *)

val refresh_rules : RPC_server.t -> unit
(** [refresh_rules server] refreshes the rules of the given session. *)
