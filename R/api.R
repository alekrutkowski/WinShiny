# Compatibility helpers and native-Windows extensions ----------------------

shinyUI <- function(ui) ui
shinyServer <- function(func) func
is.shiny.appobj <- function(x) inherits(x, 'winshiny.app')
is.reactive <- function(x) inherits(x, 'winshiny.reactiveExpr')
is.reactivevalues <- function(x) inherits(x, 'reactivevalues')

isTruthy <- function(x) {
  if (is.null(x) || length(x) == 0L) return(FALSE)
  if (inherits(x, 'try-error')) return(FALSE)
  if (is.logical(x) && length(x) == 1L && !is.na(x) && !x) return(FALSE)
  if (is.character(x) && length(x) == 1L && !nzchar(x)) return(FALSE)
  if (is.atomic(x) && length(x) == 1L && is.na(x)) return(FALSE)
  TRUE
}

need <- function(expr, message = paste(label, 'must be provided'), label) {
  if (isTruthy(expr)) return(invisible(NULL))
  as.character(message)
}

safeError <- function(error) structure(error, class = c('shiny.silent.error', class(error)))

NS <- function(namespace, id = NULL) {
  ns <- if (is.null(namespace) || !nzchar(namespace)) '' else paste0(namespace, '-')
  if (is.null(id)) {
    function(id) paste0(ns, id)
  } else {
    paste0(ns, id)
  }
}

ns.sep <- '-'

`$.winshiny.module.input` <- function(x, name) {
  y <- unclass(x)
  y$parent[[y$ns(name)]]
}
`[[.winshiny.module.input` <- function(x, i, ...) {
  y <- unclass(x)
  y$parent[[y$ns(as.character(i))]]
}
`$<-.winshiny.module.output` <- function(x, name, value) {
  y <- unclass(x)
  y$parent[[y$ns(name)]] <- value
  x
}
`$.winshiny.module.output` <- function(x, name) {
  y <- unclass(x)
  y$parent[[y$ns(name)]]
}

moduleServer <- function(id, module, session = getDefaultReactiveDomain()) {
  if (is.null(session)) stop('moduleServer() must be called inside a WinShiny server.', call. = FALSE)
  ns <- NS(id)
  input <- structure(list(parent = session$input, ns = ns), class = 'winshiny.module.input')
  output <- structure(list(parent = session$output, ns = ns), class = 'winshiny.module.output')
  child <- new.env(parent = emptyenv())
  for (nm in ls(session, all.names = TRUE)) assign(nm, get(nm, session), child)
  child$ns <- ns
  child$input <- input
  child$output <- output
  withReactiveDomain(child, module(input, output, child))
}

callModule <- function(module, id, ..., session = getDefaultReactiveDomain()) {
  moduleServer(id, function(input, output, session) module(input, output, session, ...), session)
}

makeReactiveBinding <- function(symbol, env = parent.frame()) {
  current <- get(symbol, env, inherits = FALSE)
  rv <- reactiveVal(current)
  makeActiveBinding(symbol, function(value) {
    if (missing(value)) rv() else rv(value)
  }, env)
  invisible(rv)
}

freezeReactiveVal <- function(x) invisible(NULL)

invalidateLater <- function(millis, session = getDefaultReactiveDomain()) {
  if (is.null(session) || !is.function(session$addTimer)) return(invisible(NULL))
  ctx <- .win_reactive$current
  if (!is.null(ctx)) session$addTimer(millis, ctx)
  invisible(NULL)
}

reactiveTimer <- function(intervalMs = 1000, session = getDefaultReactiveDomain()) {
  force(intervalMs)
  force(session)
  function() {
    invalidateLater(intervalMs, session)
    Sys.time()
  }
}

reactivePoll <- function(intervalMillis, session, checkFunc, valueFunc) {
  lastToken <- NULL
  lastValue <- NULL
  reactive({
    invalidateLater(intervalMillis, session)
    token <- checkFunc()
    if (is.null(lastToken) || !identical(token, lastToken)) {
      lastToken <<- token
      lastValue <<- valueFunc()
    }
    lastValue
  })
}

reactiveFileReader <- function(intervalMillis, session, filePath, readFunc, ...) {
  dots <- list(...)
  pathFunc <- if (is.function(filePath)) filePath else function() filePath
  reactivePoll(
    intervalMillis, session,
    checkFunc = function() {
      path <- pathFunc()
      info <- file.info(path)
      c(path = path, mtime = as.character(info$mtime), size = info$size)
    },
    valueFunc = function() do.call(readFunc, c(list(pathFunc()), dots))
  )
}

onFlush <- function(fun, once = TRUE, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$onFlush)) session$onFlush(fun, once)
  invisible(fun)
}

onFlushed <- function(fun, once = TRUE, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$onFlushed)) session$onFlushed(fun, once)
  invisible(fun)
}

onSessionEnded <- function(fun, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$onSessionEnded)) session$onSessionEnded(fun)
  invisible(fun)
}

onStop <- function(fun, session = getDefaultReactiveDomain()) onSessionEnded(fun, session)

icon <- function(name, class = NULL, lib = 'font-awesome') {
  structure(list(name = name, class = class, lib = lib), class = 'winshiny.icon')
}

animationOptions <- function(interval = 1000, loop = TRUE, playButton = NULL,
                             pauseButton = NULL) {
  list(interval = interval, loop = loop, playButton = playButton, pauseButton = pauseButton)
}

clickOpts <- function(id, clip = TRUE, nullOutside = FALSE) {
  list(id = id, clip = clip, nullOutside = nullOutside, type = 'click')
}

dblclickOpts <- function(id, clip = TRUE, nullOutside = FALSE) {
  list(id = id, clip = clip, nullOutside = nullOutside, type = 'dblclick')
}

hoverOpts <- function(id, delay = 300, delayType = c('debounce', 'throttle'),
                      clip = TRUE, nullOutside = FALSE) {
  list(
    id = id, delay = delay, delayType = match.arg(delayType),
    clip = clip, nullOutside = nullOutside, type = 'hover'
  )
}

brushOpts <- function(id, fill = '#9cf', stroke = '#036', opacity = 0.25,
                      delay = 300, delayType = c('debounce', 'throttle'),
                      clip = TRUE, direction = c('xy', 'x', 'y'),
                      resetOnNew = FALSE) {
  list(
    id = id, fill = fill, stroke = stroke, opacity = opacity,
    delay = delay, delayType = match.arg(delayType), clip = clip,
    direction = match.arg(direction), resetOnNew = resetOnNew,
    type = 'brush'
  )
}

plotPNG <- function(func, filename = tempfile(fileext = '.png'), width = 400,
                    height = 400, res = 72, ...) {
  grDevices::png(filename, width = width, height = height, res = res, ...)
  on.exit(grDevices::dev.off(), add = TRUE)
  func()
  normalizePath(filename, winslash = '/', mustWork = FALSE)
}

exprToFunction <- function(expr, env = parent.frame(), quoted = FALSE) {
  env <- .capture_render_env(env)
  expr <- if (quoted) expr else substitute(expr)
  function() eval(expr, env)
}

installExprFunction <- function(expr, name, eval.env = parent.frame(),
                                quoted = FALSE, assign.env = parent.frame(),
                                label = sys.call(-1)[[1]], wrappedWithLabel = TRUE,
                                ..stacktraceon = FALSE) {
  assign(name, exprToFunction(expr, eval.env, quoted), envir = assign.env)
}

repeatable <- function(rngfunc, seed = stats::runif(1, 0, .Machine$integer.max)) {
  force(rngfunc)
  force(seed)
  function(...) {
    old <- if (exists('.Random.seed', .GlobalEnv, inherits = FALSE)) get('.Random.seed', .GlobalEnv) else NULL
    on.exit({
      if (is.null(old)) {
        if (exists('.Random.seed', .GlobalEnv, inherits = FALSE)) rm('.Random.seed', envir = .GlobalEnv)
      } else assign('.Random.seed', old, envir = .GlobalEnv)
    }, add = TRUE)
    set.seed(seed)
    rngfunc(...)
  }
}

# Native notifications, modal windows, and progress -----------------------
showNotification <- function(ui, action = NULL, duration = 5, closeButton = TRUE,
                             id = NULL, type = c('default', 'message', 'warning', 'error'),
                             session = getDefaultReactiveDomain()) {
  type <- match.arg(type)
  id <- id %||% paste0('notification_', sample.int(.Machine$integer.max, 1L))
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('notification', list(
      id = id, text = .render_ui_text(ui), duration = duration,
      closeButton = closeButton, type = type
    ))
  }
  id
}

removeNotification <- function(id, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('removeNotification', list(id = id))
  }
  invisible(NULL)
}

modalButton <- function(label, icon = NULL) {
  actionButton(paste0('modal_', sample.int(.Machine$integer.max, 1L)), label, icon = icon)
}

modalDialog <- function(..., title = NULL, footer = modalButton('Dismiss'),
                        size = c('m', 's', 'l', 'xl'), easyClose = FALSE,
                        fade = TRUE) {
  structure(list(
    title = title,
    body = .ui_to_spec(tagList(...)),
    footer = .ui_to_spec(footer),
    size = match.arg(size),
    easyClose = easyClose,
    fade = fade
  ), class = 'winshiny.modal')
}

showModal <- function(ui, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    payload <- if (inherits(ui, 'winshiny.modal')) unclass(ui) else list(
      title = NULL, body = .ui_to_spec(ui), footer = NULL,
      size = 'm', easyClose = FALSE, fade = TRUE
    )
    session$sendCommand('showModal', payload)
  }
  invisible(NULL)
}

removeModal <- function(session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('removeModal', list())
  }
  invisible(NULL)
}

withProgress <- function(expr, min = 0, max = 1, value = min + (max - min) * 0.1,
                         message = NULL, detail = NULL,
                         style = getShinyOption('progress.style', default = 'notification'),
                         session = getDefaultReactiveDomain(), env = parent.frame()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('progress', list(
      visible = TRUE, min = min, max = max, value = value,
      message = message, detail = detail, style = style
    ))
  }
  on.exit({
    if (!is.null(session) && is.function(session$sendCommand)) {
      session$sendCommand('progress', list(visible = FALSE))
    }
  }, add = TRUE)
  eval(substitute(expr), env)
}

setProgress <- function(value = NULL, message = NULL, detail = NULL,
                        session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('progress', list(
      visible = TRUE, value = value, message = message, detail = detail
    ))
  }
  invisible(NULL)
}

incProgress <- function(amount = 0.1, message = NULL, detail = NULL,
                        session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('progressIncrement', list(
      amount = amount, message = message, detail = detail
    ))
  }
  invisible(NULL)
}

Progress <- function(session = getDefaultReactiveDomain(), min = 0, max = 1) {
  e <- new.env(parent = emptyenv())
  e$session <- session
  e$min <- min
  e$max <- max
  e$value <- min
  e$set <- function(value = NULL, message = NULL, detail = NULL) {
    if (!is.null(value)) e$value <- value
    setProgress(value, message, detail, e$session)
  }
  e$inc <- function(amount = 0.1, message = NULL, detail = NULL) {
    e$value <- e$value + amount
    e$set(e$value, message, detail)
  }
  e$close <- function() {
    if (!is.null(e$session) && is.function(e$session$sendCommand)) {
      e$session$sendCommand('progress', list(visible = FALSE))
    }
  }
  class(e) <- 'WinShinyProgress'
  e
}

# Tab manipulation ---------------------------------------------------------
showTab <- function(inputId, target, select = FALSE,
                    session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('showTab', list(
      id = inputId, target = target, select = select
    ))
  }
  invisible(NULL)
}

hideTab <- function(inputId, target, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('hideTab', list(id = inputId, target = target))
  }
  invisible(NULL)
}

insertTab <- function(inputId, tab, target = NULL,
                      position = c('after', 'before'), select = FALSE,
                      session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('insertTab', list(
      id = inputId, tab = .ui_to_spec(tab), target = target,
      position = match.arg(position), select = select
    ))
  }
  invisible(NULL)
}

appendTab <- function(inputId, tab, select = FALSE, menuName = NULL,
                      session = getDefaultReactiveDomain()) {
  insertTab(inputId, tab, target = NULL, position = 'after',
            select = select, session = session)
}

prependTab <- function(inputId, tab, select = FALSE, menuName = NULL,
                       session = getDefaultReactiveDomain()) {
  insertTab(inputId, tab, target = NULL, position = 'before',
            select = select, session = session)
}

removeTab <- function(inputId, target, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && is.function(session$sendCommand)) {
    session$sendCommand('removeTab', list(id = inputId, target = target))
  }
  invisible(NULL)
}

# Tag manipulation ---------------------------------------------------------
tag <- function(name, varArgs) do.call(.make_tag(name), varArgs)
tagAppendChild <- function(tag, child) { tag$children <- c(tag$children, list(child)); tag }
tagAppendChildren <- function(tag, ...) { tag$children <- c(tag$children, .flatten_children(list(...))); tag }
tagSetChildren <- function(tag, ...) { tag$children <- .flatten_children(list(...)); tag }
tagGetAttribute <- function(tag, attr) tag$attribs[[attr]]
tagHasAttribute <- function(tag, attr) !is.null(tag$attribs[[attr]])
tagAppendAttributes <- function(tag, ...) { tag$attribs <- utils::modifyList(tag$attribs, list(...)); tag }
singleton <- function(x) structure(x, class = c('winshiny.singleton', class(x)))
is.singleton <- function(x) inherits(x, 'winshiny.singleton')
suppressDependencies <- function(x, ...) x

# Options and lightweight resource compatibility --------------------------
shinyOptions <- function(...) {
  dots <- list(...)
  if (!length(dots)) {
    opts <- options()
    return(opts[startsWith(names(opts), 'winshiny.shiny.')])
  }
  names(dots) <- paste0('winshiny.shiny.', names(dots))
  do.call(options, dots)
}

getShinyOption <- function(name, default = NULL) getOption(paste0('winshiny.shiny.', name), default)

resourcePaths <- function() getOption('winshiny.resourcePaths', character())
addResourcePath <- function(prefix, directoryPath) {
  paths <- resourcePaths()
  paths[[prefix]] <- normalizePath(directoryPath, winslash = '/', mustWork = FALSE)
  options(winshiny.resourcePaths = paths)
  invisible(NULL)
}
removeResourcePath <- function(prefix) {
  paths <- resourcePaths()
  paths <- paths[names(paths) != prefix]
  options(winshiny.resourcePaths = paths)
  invisible(NULL)
}

getQueryString <- function(session = getDefaultReactiveDomain()) list()
parseQueryString <- function(str, nested = FALSE) {
  str <- sub('^[?#]', '', str)
  if (!nzchar(str)) return(list())
  pieces <- strsplit(str, '&', fixed = TRUE)[[1L]]
  out <- lapply(pieces, function(x) {
    kv <- strsplit(x, '=', fixed = TRUE)[[1L]]
    c(utils::URLdecode(kv[1L]), utils::URLdecode(paste(kv[-1L], collapse = '=')))
  })
  stats::setNames(lapply(out, `[[`, 2L), vapply(out, `[[`, character(1), 1L))
}
getUrlHash <- function(session = getDefaultReactiveDomain()) ''
updateQueryString <- function(queryString, mode = c('replace', 'push'), session = getDefaultReactiveDomain()) invisible(NULL)

# Compatibility inventory -------------------------------------------------
winShinyCapabilities <- function(status = NULL) {
  path <- system.file('SHINY_API_COMPATIBILITY.csv', package = 'WinShiny')
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.null(status)) x <- x[x$status %in% status, , drop = FALSE]
  x
}

getCurrentTheme <- function(session = getDefaultReactiveDomain()) {
  if (is.null(session) || is.null(session$input)) return(NULL)
  session$input[['winshiny_theme']]
}
