.win_reactive <- new.env(parent = emptyenv())
.win_reactive$current <- NULL
.win_reactive$queue <- list()
.win_reactive$next_id <- 0L
.win_reactive$deps <- new.env(parent = emptyenv())

.reset_reactive_graph <- function() {
  .win_reactive$current <- NULL
  .win_reactive$queue <- list()
  .win_reactive$next_id <- 0L
  .win_reactive$deps <- new.env(parent = emptyenv())
  .win_reactive$domain <- NULL
  invisible(NULL)
}

.ctx <- function(kind, run = NULL) {
  .win_reactive$next_id <- .win_reactive$next_id + 1L
  ctx <- new.env(parent = emptyenv())
  ctx$id <- paste0(kind, '_', .win_reactive$next_id)
  ctx$kind <- kind
  ctx$dirty <- TRUE
  ctx$run <- run
  class(ctx) <- 'winshiny.context'
  ctx
}
.dep_add <- function(key, ctx = .win_reactive$current) {
  if (is.null(ctx)) return(invisible(NULL))
  if (!exists(key, .win_reactive$deps, inherits = FALSE)) assign(key, list(), .win_reactive$deps)
  z <- get(key, .win_reactive$deps, inherits = FALSE)
  z[[ctx$id]] <- ctx
  assign(key, z, .win_reactive$deps)
  invisible(NULL)
}
.dep_invalidate <- function(key) {
  if (!exists(key, .win_reactive$deps, inherits = FALSE)) return(invisible(NULL))
  z <- get(key, .win_reactive$deps, inherits = FALSE)
  lapply(z, function(ctx) {
    ctx$dirty <- TRUE
    if (identical(ctx$kind, 'reactive')) .dep_invalidate(ctx$id)
    if (identical(ctx$kind, 'observer') || identical(ctx$kind, 'output')) .schedule(ctx)
  })
  invisible(NULL)
}
.schedule <- function(ctx) {
  .win_reactive$queue[[ctx$id]] <- ctx
  invisible(ctx)
}
.run_ctx <- function(ctx) {
  old <- .win_reactive$current
  old_domain <- .win_reactive$domain
  .win_reactive$current <- ctx
  if (!is.null(ctx$domain)) .win_reactive$domain <- ctx$domain
  on.exit({
    .win_reactive$current <- old
    .win_reactive$domain <- old_domain
  }, add = TRUE)
  ctx$dirty <- FALSE
  ctx$run()
}
flushReact <- function() {
  guard <- 0L
  while (length(.win_reactive$queue)) {
    guard <- guard + 1L
    if (guard > 10000L) stop('Reactive flush did not converge')
    q <- .win_reactive$queue
    .win_reactive$queue <- list()
    lapply(q, .run_ctx)
  }
  invisible(NULL)
}
reactiveVal <- function(value = NULL, label = NULL) {
  key <- paste0('rv_', paste(sample(c(letters, 0:9), 12, TRUE), collapse = ''))
  force(key)
  function(value_) {
    if (missing(value_)) {
      .dep_add(key)
      value
    } else {
      value <<- value_
      .dep_invalidate(key)
      invisible(value)
    }
  }
}
reactiveValues <- function(...) {
  env <- new.env(parent = emptyenv())
  vals <- list(...)
  for (nm in names(vals)) env[[nm]] <- vals[[nm]]
  structure(list(.env = env, .prefix = paste0('rvs_', paste(sample(c(letters, 0:9), 8, TRUE), collapse = ''))), class = 'reactivevalues')
}
.rv_env <- function(x) unclass(x)$.env
.rv_prefix <- function(x) unclass(x)$.prefix
`$.reactivevalues` <- function(x, name) {
  if (name %in% c('.env', '.prefix')) return(unclass(x)[[name]])
  .dep_add(paste0(.rv_prefix(x), '$', name))
  e <- .rv_env(x)
  if (exists(name, e, inherits = FALSE)) get(name, e, inherits = FALSE) else NULL
}
`$<-.reactivevalues` <- function(x, name, value) {
  assign(name, value, .rv_env(x))
  .dep_invalidate(paste0(.rv_prefix(x), '$', name))
  x
}
`[[.reactivevalues` <- function(x, i, ...) {
  nm <- as.character(i)
  if (nm %in% c('.env', '.prefix')) return(unclass(x)[[nm]])
  .dep_add(paste0(.rv_prefix(x), '$', nm))
  e <- .rv_env(x)
  if (exists(nm, e, inherits = FALSE)) get(nm, e, inherits = FALSE) else NULL
}
`[[<-.reactivevalues` <- function(x, i, value) {
  nm <- as.character(i)
  assign(nm, value, .rv_env(x))
  .dep_invalidate(paste0(.rv_prefix(x), '$', nm))
  x
}
reactiveValuesToList <- function(x, all.names = FALSE) as.list(.rv_env(x), all.names = all.names)
reactive <- function(x, env = parent.frame(), quoted = FALSE, ..., label = NULL, domain = getDefaultReactiveDomain()) {
  force(env)
  force(domain)
  expr <- if (quoted) x else substitute(x)
  val <- NULL
  ctx <- .ctx('reactive')
  ctx$domain <- domain
  ctx$run <- function() { val <<- eval(expr, envir = env); val }
  f <- function() {
    .dep_add(ctx$id)
    if (isTRUE(ctx$dirty)) .run_ctx(ctx)
    val
  }
  class(f) <- c('winshiny.reactiveExpr', 'function')
  f
}
observe <- function(x, env = parent.frame(), quoted = FALSE, ..., label = NULL, suspended = FALSE, priority = 0, domain = getDefaultReactiveDomain(), autoDestroy = TRUE) {
  force(env)
  force(domain)
  expr <- if (quoted) x else substitute(x)
  ctx <- .ctx('observer')
  ctx$domain <- domain
  ctx$run <- function() eval(expr, envir = env)
  if (!isTRUE(suspended)) .schedule(ctx)
  class(ctx) <- c('winshiny.observer', 'winshiny.context')
  ctx
}
isolate <- function(expr) {
  old <- .win_reactive$current
  .win_reactive$current <- NULL
  on.exit(.win_reactive$current <- old, add = TRUE)
  eval.parent(substitute(expr))
}
req <- function(..., cancelOutput = FALSE) {
  vals <- list(...)
  ok <- all(vapply(vals, function(x) !is.null(x) && length(x) > 0 && !identical(x, FALSE) && !(is.character(x) && !nzchar(x[1])) && !(is.numeric(x) && is.na(x[1])), logical(1)))
  if (!ok) stop('Required value missing', call. = FALSE)
  if (length(vals) == 1) vals[[1]] else invisible(vals)
}
bindEvent <- function(x, ..., ignoreNULL = TRUE, ignoreInit = FALSE, once = FALSE, label = NULL) {
  events <- substitute(list(...))[-1]
  force(x); force(events)
  fired <- FALSE
  wrapper <- function() {
    lapply(events, function(e) eval(e, parent.frame(2)))
    if (ignoreInit && !fired) { fired <<- TRUE; return(invisible(NULL)) }
    fired <<- TRUE
    if (is.function(x)) x() else x
  }
  if (inherits(x, 'winshiny.observer')) { x$run <- wrapper; x } else wrapper
}
observeEvent <- function(eventExpr, handlerExpr, event.env = parent.frame(), event.quoted = FALSE, handler.env = parent.frame(), handler.quoted = FALSE, ..., ignoreNULL = TRUE, ignoreInit = FALSE, once = FALSE) {
  force(event.env)
  force(handler.env)
  e <- if (event.quoted) eventExpr else substitute(eventExpr)
  h <- if (handler.quoted) handlerExpr else substitute(handlerExpr)
  observe({ eval(e, envir = event.env); eval(h, envir = handler.env) }, ...)
}
eventReactive <- function(eventExpr, valueExpr, event.env = parent.frame(), event.quoted = FALSE, value.env = parent.frame(), value.quoted = FALSE, ..., ignoreNULL = TRUE, ignoreInit = FALSE) {
  force(event.env)
  force(value.env)
  e <- if (event.quoted) eventExpr else substitute(eventExpr)
  v <- if (value.quoted) valueExpr else substitute(valueExpr)
  reactive({ eval(e, envir = event.env); eval(v, envir = value.env) }, quoted = TRUE)
}
debounce <- function(r, millis, priority = 100, domain = getDefaultReactiveDomain()) r
throttle <- function(r, millis, priority = 100, domain = getDefaultReactiveDomain()) r
freezeReactiveValue <- function(x, name) invisible(NULL)
getDefaultReactiveDomain <- function() .win_reactive$domain %||% NULL
withReactiveDomain <- function(domain, expr) { old <- .win_reactive$domain; .win_reactive$domain <- domain; on.exit(.win_reactive$domain <- old, add = TRUE); force(expr) }
onReactiveDomainEnded <- function(domain, callback, failIfNull = FALSE) invisible(NULL)
