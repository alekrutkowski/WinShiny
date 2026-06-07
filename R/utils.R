`%||%` <- function(x, y) if (is.null(x)) y else x
.win_id <- function(x) gsub('[^A-Za-z0-9_]', '_', as.character(x))
.as_chr <- function(x) if (is.null(x)) NULL else as.character(x)
.first_choice <- function(choices) {
  ch <- .normalize_choices(choices)
  if (length(ch)) unname(ch)[[1]] else NULL
}
.normalize_choices <- function(choices) {
  if (is.null(choices)) return(character())
  if (is.data.frame(choices)) choices <- choices[[1]]
  if (is.list(choices)) choices <- unlist(choices, recursive = TRUE, use.names = TRUE)
  vals <- as.character(choices)
  nms <- names(choices)
  if (is.null(nms) || all(is.na(nms) | !nzchar(nms))) names(vals) <- vals else names(vals) <- ifelse(is.na(nms) | !nzchar(nms), vals, nms)
  vals
}
.flatten_children <- function(x) {
  out <- list()
  add <- function(z) {
    if (is.null(z)) return(NULL)
    if (is.list(z) && !inherits(z, c('winshiny.tag','winshiny.ui_input','winshiny.ui_output')) && !is.data.frame(z)) lapply(z, add)
    else out[[length(out)+1L]] <<- z
    NULL
  }
  lapply(x, add)
  out
}
.json_escape <- function(x) {
  x <- as.character(x %||% '')
  x <- gsub('\\', '\\\\', x, fixed = TRUE)
  x <- gsub('"', '\\"', x, fixed = TRUE)
  x <- gsub('\r', '\\r', x, fixed = TRUE)
  x <- gsub('\n', '\\n', x, fixed = TRUE)
  x
}
.json_value <- function(x) {
  if (length(x) == 0) '[]'
  else if (length(x) > 1) paste0('[', paste(vapply(x, .json_value, character(1)), collapse = ','), ']')
  else if (isTRUE(x)) 'true'
  else if (identical(x, FALSE)) 'false'
  else if (is.numeric(x) && !is.na(x)) as.character(x)
  else paste0('"', .json_escape(x), '"')
}
.write_json_state <- function(path, state) {
  nms <- ls(state, all.names = TRUE)
  pieces <- vapply(nms, function(nm) {
    z <- get(nm, state)
    paste0('"', .json_escape(nm), '":{"kind":"', .json_escape(z$kind %||% 'text'), '","value":', .json_value(z$value), '}')
  }, character(1))
  payload <- paste0('{', paste(pieces, collapse = ','), '}')
  tmp <- paste0(path, '.new')
  cat(payload, file = tmp)
  if (file.exists(path)) unlink(path)
  if (!file.rename(tmp, path)) {
    ok <- file.copy(tmp, path, overwrite = TRUE)
    unlink(tmp)
    if (!ok) stop('Could not update WinShiny state file: ', path, call. = FALSE)
  }
  invisible(path)
}
.parse_event_line <- function(s) {
  s <- paste(as.character(s), collapse = "")
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    z <- jsonlite::fromJSON(s, simplifyVector = FALSE)
    val <- z$value
    if (is.list(val) && !is.data.frame(val)) val <- unlist(val, recursive = TRUE, use.names = FALSE)
    return(list(id = as.character(z$id), value = val))
  }
  id <- base::sub('.*"id"[[:space:]]*:[[:space:]]*"([^"]*)".*', '\\1', s)
  raw <- base::sub('.*"value"[[:space:]]*:[[:space:]]*', '', s)
  raw <- base::sub('}[[:space:]]*$', '', raw)
  raw <- paste(raw, collapse = '')
  val <- raw
  if (length(raw) && base::grepl('^"', raw)) val <- base::gsub('\\"', '"', base::sub('^"(.*)"$', '\\1', raw))
  else if (length(raw) && base::grepl('^\\[', raw)) {
    z <- base::gsub('^\\[|\\]$', '', raw)
    val <- if (!nzchar(z)) character() else base::trimws(base::gsub('^"|"$', '', base::strsplit(z, ',', fixed = TRUE)[[1]]))
  } else if (raw %in% c('true','false')) val <- identical(raw, 'true')
  else val <- suppressWarnings(as.numeric(raw))
  list(id = id, value = val)
}
.ps_quote <- function(x) paste0("'", gsub("'", "''", as.character(x %||% ''), fixed = TRUE), "'")
.ps_bool <- function(x) if (isTRUE(x)) '$true' else '$false'

.parse_condition <- function(condition) {
  if (is.null(condition) || !nzchar(condition)) return(NULL)
  condition <- gsub("[[:space:]]+", "", as.character(condition)[1])
  m <- regexec("^input[.]([A-Za-z0-9_]+)(==|===|!=|!==)(true|false|['\"][^'\"]+['\"]|[0-9.]+)$", condition)
  z <- regmatches(condition, m)[[1]]
  if (length(z) < 4) return(NULL)
  val <- z[4]
  val <- if (val == "true") TRUE else if (val == "false") FALSE else gsub("^['\"]|['\"]$", "", val)
  if (z[3] %in% c("!=", "!==") && is.logical(val)) val <- !val
  list(source = z[2], value = val)
}
.ps_jsonish <- function(x) {
  if (is.null(x) || length(x) == 0) return('$null')
  if (length(x) > 1) return(paste0('@(', paste(vapply(x, .ps_jsonish, character(1)), collapse = ','), ')'))
  if (isTRUE(x)) return('$true')
  if (identical(x, FALSE)) return('$false')
  if (is.numeric(x) && !is.na(x)) return(as.character(x))
  .ps_quote(as.character(x))
}
.ps_num <- function(x) {
  x <- suppressWarnings(as.numeric(x)[1])
  if (is.na(x)) x <- 0
  format(x, scientific = FALSE, trim = TRUE, decimal.mark = '.')
}
.px <- function(x, default = 400) {
  if (is.null(x) || !length(x)) return(default)
  while (is.list(x) && length(x) == 1L) x <- x[[1L]]
  if (is.list(x)) x <- unlist(x, recursive = TRUE, use.names = FALSE)
  if (!length(x)) return(default)
  z <- suppressWarnings(as.numeric(base::sub('px$', '', as.character(x[[1L]]), ignore.case = TRUE)))
  if (!length(z) || is.na(z) || z <= 0) default else z
}
