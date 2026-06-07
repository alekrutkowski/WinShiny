# Native Windows clipboard tables -----------------------------------------

.clipboard_require_windows <- function() {
  if (.Platform$OS.type != "windows") {
    stop("Native clipboard support is available only on Windows.", call. = FALSE)
  }
}

.clipboard_read_payload <- function() {
  .clipboard_require_windows()
  if (!exists("readClipboard", envir = asNamespace("utils"), inherits = FALSE)) {
    stop("This R installation does not provide utils::readClipboard().", call. = FALSE)
  }
  lines <- utils::readClipboard(format = 1L)
  text <- paste(lines, collapse = "\n")
  list(
    text = text,
    metadata = list(
      formats = "CF_UNICODETEXT",
      has_html = FALSE,
      has_csv = FALSE,
      has_unicode_text = TRUE
    )
  )
}

.clipboard_active_session <- function() {
  session <- getDefaultReactiveDomain()
  if (is.null(session) || !is.function(session$sendCommand)) {
    stop(
      "Clipboard copy helpers require an active WinShiny WPF session. " ,
      "For displayed outputs, prefer copyTableButton() or copyPlotButton().",
      call. = FALSE
    )
  }
  session
}

.clipboard_write_formats <- function(text, html, csv) {
  session <- .clipboard_active_session()
  session$sendCommand("clipboardTable", list(text = text, html = html, csv = csv))
  invisible(TRUE)
}

.clipboard_write_bmp <- function(file) {
  session <- .clipboard_active_session()
  session$sendCommand("clipboardImage", list(path = normalizePath(file, winslash = "/", mustWork = TRUE)))
  invisible(TRUE)
}

.clipboard_count_fields <- function(text, sep) {
  con <- textConnection(text)
  on.exit(close(con), add = TRUE)
  tryCatch(
    utils::count.fields(con, sep = sep, quote = '"', comment.char = '',
                        blank.lines.skip = TRUE),
    error = function(e) integer()
  )
}

.clipboard_detect_separator <- function(text) {
  if (grepl('\t', text, fixed = TRUE)) return('\t')
  candidates <- c(',', ';', '|')
  scores <- vapply(candidates, function(sep) {
    fields <- .clipboard_count_fields(text, sep)
    fields <- fields[is.finite(fields) & fields > 0L]
    if (!length(fields) || max(fields) <= 1L) return(-Inf)
    mode_fields <- as.integer(names(which.max(table(fields))))
    consistency <- mean(fields == mode_fields)
    if (mode_fields <= 1L || consistency < 0.6) return(-Inf)
    mode_fields + 10 * consistency
  }, numeric(1))
  if (all(!is.finite(scores))) '\t' else candidates[[which.max(scores)]]
}

.clipboard_empty_matrix <- function(x) {
  if (!length(x)) return(matrix(TRUE, nrow = nrow(x), ncol = ncol(x)))
  values <- as.matrix(x)
  trimmed <- matrix(trimws(as.character(values)), nrow = nrow(values), ncol = ncol(values))
  is.na(values) | !nzchar(trimmed)
}

.clipboard_decimal_mark <- function(x, sep) {
  vals <- unlist(x, use.names = FALSE)
  vals <- trimws(as.character(vals))
  vals <- vals[nzchar(vals)]
  if (!length(vals) || identical(sep, ',')) return('.')
  comma_numeric <- mean(grepl('^[+-]?[0-9]+,[0-9]+([eE][+-]?[0-9]+)?$', vals))
  dot_numeric <- mean(grepl('^[+-]?[0-9]+[.][0-9]+([eE][+-]?[0-9]+)?$', vals))
  if (is.finite(comma_numeric) && comma_numeric > dot_numeric && comma_numeric >= 0.2) ',' else '.'
}

.clipboard_numeric_rate <- function(x, dec = '.') {
  x <- trimws(as.character(x))
  x <- x[nzchar(x)]
  if (!length(x)) return(0)
  if (identical(dec, ',')) x <- sub(',', '.', x, fixed = TRUE)
  mean(!is.na(suppressWarnings(as.numeric(x))))
}

.clipboard_date_rate <- function(x) {
  x <- trimws(as.character(x))
  x <- x[nzchar(x)]
  if (!length(x)) return(0)
  patterns <- c('%Y-%m-%d', '%d/%m/%Y', '%m/%d/%Y', '%d.%m.%Y')
  parsed <- Reduce(`|`, lapply(patterns, function(fmt) !is.na(as.Date(x, format = fmt))))
  mean(parsed)
}

.clipboard_detect_header <- function(raw, source, sep, dec) {
  if (nrow(raw) < 2L || ncol(raw) < 1L) return(FALSE)
  first <- trimws(as.character(raw[1L, , drop = TRUE]))
  rest <- raw[-1L, , drop = FALSE]
  nonempty <- !is.na(first) & nzchar(first)
  unique_names <- all(nonempty) && !anyDuplicated(tolower(first))
  name_like <- unique_names && mean(grepl('[[:alpha:]_]', first)) >= 0.5

  contrasts <- vapply(seq_len(ncol(raw)), function(j) {
    first_numeric <- .clipboard_numeric_rate(first[[j]], dec) == 1
    first_date <- .clipboard_date_rate(first[[j]]) == 1
    rest_numeric <- .clipboard_numeric_rate(rest[[j]], dec)
    rest_date <- .clipboard_date_rate(rest[[j]])
    !first_numeric && !first_date && (rest_numeric >= 0.6 || rest_date >= 0.6)
  }, logical(1))

  any(contrasts) || (name_like && source %in% c('Excel range', 'TSV', 'CSV', 'semicolon-delimited text', 'pipe-delimited text'))
}

.clipboard_source_name <- function(meta, sep) {
  formats <- paste(meta$formats %||% character(), collapse = '|')
  excel <- isTRUE(meta$has_html) || grepl('Biff|XML Spreadsheet|Excel|Link Source|EnhancedMetafile', formats, ignore.case = TRUE)
  if (excel && identical(sep, '\t')) return('Excel range')
  switch(sep,
    '\t' = 'TSV',
    ',' = 'CSV',
    ';' = 'semicolon-delimited text',
    '|' = 'pipe-delimited text',
    'plain text'
  )
}

#' Read tabular data from the Windows clipboard
#'
#' Reads a copied Excel cell range or plain CSV/TSV text and converts it to a
#' data frame. Delimiter, decimal mark, and header presence can be detected
#' automatically.
#'
#' @param header `TRUE`, `FALSE`, or `"auto"`.
#' @param sep Field separator, or `"auto"`.
#' @param stringsAsFactors Passed to the final data-frame conversion.
#' @param check.names Whether to make syntactically valid column names.
#' @param details If `TRUE`, return data and detection metadata in a list.
#' @param ... Additional arguments passed to `utils::read.table()`.
#' @return A data frame, or a list with `data` and `metadata` when
#'   `details = TRUE`.
parseClipboardTable <- function(payload, header = 'auto', sep = 'auto',
                                stringsAsFactors = FALSE,
                                check.names = FALSE, details = FALSE, ...) {
  if (is.character(payload) && length(payload) == 1L) {
    payload <- list(text = payload, metadata = list())
  }
  if (!is.list(payload)) {
    stop('`payload` must be clipboard text or a clipboard payload list.', call. = FALSE)
  }
  if (!is.null(payload$error) && nzchar(as.character(payload$error)[1L])) {
    stop(as.character(payload$error)[1L], call. = FALSE)
  }
  text <- as.character(payload$text %||% '')[1L]
  metadata <- payload$metadata %||% list()
  if (!is.list(metadata)) metadata <- as.list(metadata)
  metadata$formats <- as.character(unlist(metadata$formats %||% character(), use.names = FALSE))
  metadata$has_html <- isTRUE(as.logical(metadata$has_html %||% FALSE))
  metadata$has_csv <- isTRUE(as.logical(metadata$has_csv %||% FALSE))
  metadata$has_unicode_text <- isTRUE(as.logical(metadata$has_unicode_text %||% FALSE))

  text <- gsub('\r\n?', '\n', text)
  text <- sub('[[:space:]]+$', '', text)
  if (!nzchar(trimws(text))) stop('The Windows clipboard does not contain tabular text.', call. = FALSE)

  if (length(sep) != 1L) stop('`sep` must be a single separator or "auto".', call. = FALSE)
  detected_sep <- if (identical(sep, 'auto')) .clipboard_detect_separator(text) else as.character(sep)
  source <- .clipboard_source_name(metadata, detected_sep)

  raw <- utils::read.table(
    text = text, header = FALSE, sep = detected_sep, quote = '"',
    comment.char = '', fill = TRUE, colClasses = 'character',
    stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = c('', 'NA', 'N/A', 'NULL'), strip.white = TRUE, ...
  )
  if (!nrow(raw) || !ncol(raw)) stop('No table could be parsed from the Windows clipboard.', call. = FALSE)

  empty <- .clipboard_empty_matrix(raw)
  raw <- raw[rowSums(!empty) > 0L, colSums(!empty) > 0L, drop = FALSE]
  if (!nrow(raw) || !ncol(raw)) stop('The clipboard table contains no non-empty cells.', call. = FALSE)

  dec <- .clipboard_decimal_mark(raw, detected_sep)
  header_flag <- if (identical(header, 'auto')) {
    .clipboard_detect_header(raw, source, detected_sep, dec)
  } else {
    isTRUE(header)
  }

  if (header_flag) {
    column_names <- trimws(as.character(raw[1L, , drop = TRUE]))
    raw <- raw[-1L, , drop = FALSE]
    blank <- is.na(column_names) | !nzchar(column_names)
    column_names[blank] <- paste0('V', which(blank))
  } else {
    column_names <- paste0('V', seq_len(ncol(raw)))
  }
  column_names <- if (isTRUE(check.names)) {
    make.names(column_names, unique = TRUE)
  } else {
    make.unique(column_names)
  }
  names(raw) <- column_names

  converted <- lapply(raw, function(x) {
    utils::type.convert(x, as.is = !isTRUE(stringsAsFactors), dec = dec,
                        na.strings = c('', 'NA', 'N/A', 'NULL'))
  })
  data <- as.data.frame(converted, stringsAsFactors = stringsAsFactors,
                        check.names = FALSE, optional = TRUE)
  names(data) <- column_names

  detection <- c(metadata, list(
    source = source,
    separator = detected_sep,
    separator_label = switch(detected_sep, '\t' = 'tab', ',' = 'comma', ';' = 'semicolon', '|' = 'pipe', detected_sep),
    decimal_mark = dec,
    header = header_flag,
    rows = nrow(data),
    columns = ncol(data)
  ))
  result <- list(data = data, metadata = detection)
  class(result) <- c('winshiny.clipboard_table', 'list')
  if (isTRUE(details)) result else data
}

readClipboardTable <- function(header = 'auto', sep = 'auto',
                               stringsAsFactors = FALSE,
                               check.names = FALSE, details = FALSE, ...) {
  payload <- .clipboard_read_payload()
  parseClipboardTable(
    payload, header = header, sep = sep,
    stringsAsFactors = stringsAsFactors, check.names = check.names,
    details = details, ...
  )
}

.clipboard_html_escape <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ''
  x <- gsub('&', '&amp;', x, fixed = TRUE)
  x <- gsub('<', '&lt;', x, fixed = TRUE)
  x <- gsub('>', '&gt;', x, fixed = TRUE)
  x <- gsub('"', '&quot;', x, fixed = TRUE)
  x
}

.clipboard_table_html <- function(x, digits = 3L) {
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  if (!ncol(x)) stop('A clipboard table must contain at least one column.', call. = FALSE)
  formatted <- lapply(x, .docx_format_column, digits = digits)
  names(formatted) <- names(x)
  headers <- paste0('<th>', .clipboard_html_escape(names(formatted)), '</th>', collapse = '')
  rows <- if (!nrow(x)) '' else paste0(vapply(seq_len(nrow(x)), function(i) {
    cells <- vapply(seq_along(formatted), function(j) {
      cls <- if (is.numeric(x[[j]])) ' class="number"' else ''
      paste0('<td', cls, '>', .clipboard_html_escape(formatted[[j]][[i]]), '</td>')
    }, character(1))
    paste0('<tr>', paste0(cells, collapse = ''), '</tr>')
  }, character(1)), collapse = '')
  paste0('<table><thead><tr>', headers, '</tr></thead><tbody>', rows, '</tbody></table>')
}

.clipboard_plain_table <- function(x) {
  out <- character()
  con <- textConnection('out', 'w', local = TRUE)
  on.exit(if (isOpen(con)) close(con), add = TRUE)
  utils::write.table(x, con, sep = '\t', row.names = FALSE, col.names = TRUE,
                     quote = FALSE, na = '')
  close(con)
  paste(out, collapse = '\r\n')
}

.clipboard_cf_html <- function(fragment) {
  fragment <- enc2utf8(as.character(fragment)[1L])
  prefix <- '<html><head><meta charset="utf-8"></head><body><!--StartFragment-->'
  suffix <- '<!--EndFragment--></body></html>'
  html <- paste0(prefix, fragment, suffix)
  blank_header <- sprintf(
    'Version:0.9\r\nStartHTML:%010d\r\nEndHTML:%010d\r\nStartFragment:%010d\r\nEndFragment:%010d\r\n',
    0L, 0L, 0L, 0L
  )
  start_html <- nchar(blank_header, type = 'bytes')
  start_fragment <- start_html + nchar(prefix, type = 'bytes')
  end_fragment <- start_fragment + nchar(fragment, type = 'bytes')
  end_html <- start_html + nchar(html, type = 'bytes')
  header <- sprintf(
    'Version:0.9\r\nStartHTML:%010d\r\nEndHTML:%010d\r\nStartFragment:%010d\r\nEndFragment:%010d\r\n',
    start_html, end_html, start_fragment, end_fragment
  )
  paste0(header, html)
}

#' Copy native table output to the Windows clipboard
#'
#' Places a styled HTML table on the Windows clipboard for direct pasting into
#' Word, together with TSV and CSV fallbacks for Excel and text applications.
#'
#' @param x A data frame or a named list of data frames.
#' @param title Optional document-style title.
#' @param subtitle Optional subtitle.
#' @param notes Optional notes displayed after the tables.
#' @param digits Significant digits used for numeric cells.
#' @return Clipboard format and table-size information, invisibly.
copyTableToClipboard <- function(x, title = NULL, subtitle = NULL,
                                 notes = NULL, digits = 3L) {
  tables <- if (is.data.frame(x)) list(x) else x
  if (!is.list(tables) || !length(tables) || !all(vapply(tables, is.data.frame, logical(1)))) {
    stop('`x` must be a data frame or a non-empty list of data frames.', call. = FALSE)
  }
  table_names <- names(tables)
  if (is.null(table_names)) table_names <- rep('', length(tables))
  table_names[is.na(table_names)] <- ''

  style <- paste0(
    '<style>',
    'body{font-family:Aptos,Calibri,Arial,sans-serif;font-size:10.5pt;color:#1f1f1f;}',
    'h1{font-size:16pt;color:#1f4e79;margin:0 0 6pt 0;}',
    'h2{font-size:12pt;color:#1f4e79;margin:10pt 0 4pt 0;}',
    'p{margin:0 0 6pt 0;}',
    'table{border-collapse:collapse;margin:0 0 10pt 0;}',
    'th,td{border:1px solid #b7b7b7;padding:4pt 6pt;vertical-align:middle;}',
    'th{background:#d9eaf7;font-weight:bold;text-align:left;}',
    'td.number{text-align:right;}',
    '.notes{font-size:9pt;color:#555;margin-top:6pt;}',
    '</style>'
  )
  pieces <- c(style)
  if (!is.null(title) && length(title) && nzchar(as.character(title)[1])) {
    pieces <- c(pieces, paste0('<h1>', .clipboard_html_escape(as.character(title)[1]), '</h1>'))
  }
  if (!is.null(subtitle) && length(subtitle)) {
    pieces <- c(pieces, paste0('<p>', .clipboard_html_escape(paste(subtitle, collapse = ' ')), '</p>'))
  }
  for (i in seq_along(tables)) {
    if (nzchar(table_names[[i]])) {
      pieces <- c(pieces, paste0('<h2>', .clipboard_html_escape(table_names[[i]]), '</h2>'))
    }
    pieces <- c(pieces, .clipboard_table_html(tables[[i]], digits = digits))
  }
  if (!is.null(notes) && length(notes)) {
    pieces <- c(pieces, paste0('<p class="notes">', .clipboard_html_escape(paste(notes, collapse = ' ')), '</p>'))
  }
  fragment <- paste0(pieces, collapse = '')
  cf_html <- .clipboard_cf_html(fragment)

  text_parts <- character()
  if (!is.null(title) && length(title)) text_parts <- c(text_parts, as.character(title)[1], '')
  if (!is.null(subtitle) && length(subtitle)) text_parts <- c(text_parts, paste(subtitle, collapse = ' '), '')
  for (i in seq_along(tables)) {
    if (nzchar(table_names[[i]])) text_parts <- c(text_parts, table_names[[i]])
    text_parts <- c(text_parts, .clipboard_plain_table(tables[[i]]), '')
  }
  if (!is.null(notes) && length(notes)) text_parts <- c(text_parts, paste(notes, collapse = ' '))
  plain_text <- paste(text_parts, collapse = '\r\n')

  csv_lines <- character()
  csv_con <- textConnection('csv_lines', 'w', local = TRUE)
  on.exit(if (isOpen(csv_con)) close(csv_con), add = TRUE)
  utils::write.csv(tables[[1]], csv_con, row.names = FALSE, na = '')
  close(csv_con)
  csv_text <- paste(csv_lines, collapse = '\r\n')

  .clipboard_write_formats(plain_text, cf_html, csv_text)

  invisible(list(
    formats = c('HTML Format', 'UnicodeText', 'Csv'),
    tables = length(tables),
    rows = sum(vapply(tables, nrow, integer(1))),
    columns = vapply(tables, ncol, integer(1))
  ))
}

#' Copy a BMP image file to the Windows clipboard
#'
#' Requests that the active WPF host place a BMP image on the Windows clipboard.
#'
#' @param file Path to a BMP image file.
#' @return The normalized image path, invisibly.
copyImageToClipboard <- function(file) {
  file <- normalizePath(file, winslash = "/", mustWork = TRUE)
  if (!identical(tolower(tools::file_ext(file)), "bmp")) {
    stop("Native clipboard image copying currently requires a BMP file.",
         call. = FALSE)
  }
  .clipboard_write_bmp(file)
  invisible(file)
}

#' @rdname copyTableToClipboard
copyWordTable <- copyTableToClipboard
