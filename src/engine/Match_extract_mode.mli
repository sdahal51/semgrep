(*
   Generates a list of targets corresponding to extract mode rule matches in
   the provided original target file. Each "extracted" generated target will
   also have a function which can transform match results in the extracted
   target to match results corresponding to the file from which that
   extraction occured (the original target).

   Note that this internally calls Match_rules.check(), hence the
   few label arguments.
*)
val extract :
  match_hook:(string -> Pattern_match.t -> unit) ->
  timeout:float ->
  timeout_threshold:int ->
  Rule.extract_rule list ->
  Xtarget.t ->
  Extract.extracted_target_and_adjuster list
