# Lightweight compatibility helpers for public Shiny APIs that do not depend
# on a browser transport.

tag <- function(`_tag_name`, varArgs = list(), .noWS = NULL) {
  do.call(.win_tag, c(list(type = `_tag_name`), varArgs))
}
tagAppendAttributes <- function(tag, ...) {
  stopifnot(inherits(tag, 'winshiny.tag'))
  tag$attribs <- c(tag$attribs %||% list(), list(...))
  tag
}
tagAppendChild <- function(tag, child) {
  stopifnot(inherits(tag, 'winshiny.tag'))
  tag$children <- c(tag$children, .flatten_children(list(child)))
  tag
}
tagAppendChildren <- function(tag, ...) {
  stopifnot(inherits(tag, 'winshiny.tag'))
  tag$children <- c(tag$children, .flatten_children(list(...)))
  tag
}
tagGetAttribute <- function(tag, attr) tag$attribs[[attr]]
tagHasAttribute <- function(tag, attr) !is.null(tag$attribs[[attr]])
tagSetChildren <- function(tag, ...) {
  stopifnot(inherits(tag, 'winshiny.tag'))
  tag$children <- .flatten_children(list(...))
  tag
}
withTags <- function(code) {
  env <- list2env(as.list(tags), parent = parent.frame())
  eval(substitute(code), envir = env)
}
singleton <- function(x) structure(x, class = unique(c('winshiny.singleton', class(x))))
is.singleton <- function(x) inherits(x, 'winshiny.singleton')
suppressDependencies <- function(x, dependencies) x

includeText <- function(path) paste(readLines(path, warn = FALSE), collapse = '\n')
includeHTML <- function(path) HTML(includeText(path))
includeMarkdown <- function(path) .win_tag('pre', includeText(path))
includeCSS <- function(path, ...) invisible(NULL)
includeScript <- function(path, ...) invisible(NULL)
markdown <- function(md, extensions = TRUE, .noWS = NULL) .win_tag('pre', paste(md, collapse = '\n'))
withMathJax <- function(ui) ui

is.reactive <- function(x) inherits(x, 'winshiny.reactiveExpr')
is.reactivevalues <- function(x) inherits(x, 'reactivevalues')
freezeReactiveVal <- function(x) invisible(NULL)
makeReactiveBinding <- function(symbol, env = parent.frame()) {
  value <- get(symbol, envir = env)
  rv <- reactiveVal(value)
  makeActiveBinding(symbol, function(value) {
    if (missing(value)) rv() else rv(value)
  }, env)
  invisible(NULL)
}

exprToFunction <- function(expr, env = parent.frame(), quoted = FALSE) {
  force(env)
  ex <- if (quoted) expr else substitute(expr)
  function() eval(ex, envir = env)
}
quoToFunction <- function(q, label = NULL, domain = getDefaultReactiveDomain()) {
  if (is.function(q)) q else function() eval(q, envir = parent.frame())
}
installExprFunction <- function(expr, name, eval.env = parent.frame(2), quoted = FALSE,
                                assign.env = parent.frame(1), label = sys.call(-1)[[1]], wrappedWithLabel = TRUE) {
  assign(name, exprToFunction(expr, eval.env, quoted), envir = assign.env)
}
repeatable <- function(rngfunc, seed = stats::runif(1, 0, .Machine$integer.max)) {
  force(rngfunc); force(seed)
  function(...) {
    old <- if (exists('.Random.seed', .GlobalEnv, inherits = FALSE)) get('.Random.seed', .GlobalEnv) else NULL
    on.exit(if (is.null(old)) rm('.Random.seed', envir = .GlobalEnv) else assign('.Random.seed', old, .GlobalEnv), add = TRUE)
    set.seed(seed)
    rngfunc(...)
  }
}

safeError <- function(error) structure(error, class = unique(c('shiny.silent.error', class(error))))
printError <- function(cond) message(conditionMessage(cond))
withLogErrors <- function(expr, full = getOption('shiny.fullstacktrace', FALSE), offset = 0) {
  tryCatch(force(expr), error = function(e) { message(conditionMessage(e)); stop(e) })
}

.shiny_options <- new.env(parent = emptyenv())
shinyOptions <- function(...) {
  values <- list(...)
  if (!length(values)) return(as.list(.shiny_options))
  old <- lapply(names(values), function(nm) if (exists(nm, .shiny_options, inherits = FALSE)) get(nm, .shiny_options) else NULL)
  names(old) <- names(values)
  list2env(values, envir = .shiny_options)
  invisible(old)
}
getShinyOption <- function(name, default = NULL) {
  if (exists(name, .shiny_options, inherits = FALSE)) get(name, .shiny_options) else getOption(paste0('shiny.', name), default)
}

animationOptions <- function(interval = 1000, loop = FALSE, playButton = NULL, pauseButton = NULL) list(interval = interval, loop = loop, playButton = playButton, pauseButton = pauseButton)
clickOpts <- function(id, clip = TRUE, nullOutside = FALSE, coords_css = FALSE) list(id = id, clip = clip, nullOutside = nullOutside, coords_css = coords_css)
dblclickOpts <- function(id, clip = TRUE, nullOutside = FALSE, delay = 400, coords_css = FALSE) list(id = id, clip = clip, nullOutside = nullOutside, delay = delay, coords_css = coords_css)
hoverOpts <- function(id, delay = 300, delayType = c('debounce','throttle'), clip = TRUE, nullOutside = FALSE, coords_css = FALSE) list(id = id, delay = delay, delayType = match.arg(delayType), clip = clip, nullOutside = nullOutside, coords_css = coords_css)
brushOpts <- function(id, fill = '#9cf', stroke = '#036', opacity = 0.25, delay = 300, delayType = c('debounce','throttle'), clip = TRUE, direction = c('xy','x','y'), resetOnNew = FALSE, coords_css = FALSE) list(id = id, fill = fill, stroke = stroke, opacity = opacity, delay = delay, delayType = match.arg(delayType), clip = clip, direction = match.arg(direction), resetOnNew = resetOnNew, coords_css = coords_css)

getQueryString <- function(session = getDefaultReactiveDomain()) list()
parseQueryString <- function(str, nested = FALSE) {
  str <- sub('^[?#]', '', str)
  if (!nzchar(str)) return(list())
  parts <- strsplit(str, '&', fixed = TRUE)[[1]]
  out <- lapply(parts, function(p) {
    z <- strsplit(p, '=', fixed = TRUE)[[1]]
    utils::URLdecode(if (length(z) > 1) z[2] else '')
  })
  names(out) <- vapply(parts, function(p) utils::URLdecode(strsplit(p, '=', fixed = TRUE)[[1]][1]), character(1))
  out
}
getUrlHash <- function(session = getDefaultReactiveDomain()) ''
updateQueryString <- function(queryString, mode = c('replace','push'), session = getDefaultReactiveDomain()) invisible(NULL)

serverInfo <- function() list(backend = 'PowerShell/WPF', transport = 'local JSON files')
