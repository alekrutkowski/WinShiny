.make_output_proxy <- function(session) {
  env <- new.env(parent = emptyenv())
  structure(env, class = 'winshiny.output', session = session)
}

`$.winshiny.output` <- function(x, name) {
  if (exists(name, x, inherits = FALSE)) get(name, x, inherits = FALSE) else NULL
}
