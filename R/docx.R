# Native Word document export ----------------------------------------------

.docx_xml_escape <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ''
  x <- gsub('&', '&amp;', x, fixed = TRUE)
  x <- gsub('<', '&lt;', x, fixed = TRUE)
  x <- gsub('>', '&gt;', x, fixed = TRUE)
  x <- gsub('"', '&quot;', x, fixed = TRUE)
  x <- gsub("'", '&apos;', x, fixed = TRUE)
  x
}

.docx_paragraph <- function(text = '', style = NULL, bold = FALSE,
                            size = NULL, color = NULL,
                            space_after = 100L) {
  text <- paste(as.character(text), collapse = '\n')
  lines <- strsplit(text, '\n', fixed = TRUE)[[1]]

  ppr <- paste0(
    '<w:pPr>',
    if (!is.null(style)) paste0('<w:pStyle w:val="', .docx_xml_escape(style), '"/>') else '',
    '<w:spacing w:after="', as.integer(space_after), '"/>',
    '</w:pPr>'
  )

  runs <- vapply(seq_along(lines), function(i) {
    rpr <- paste0(
      '<w:rPr>',
      if (isTRUE(bold)) '<w:b/>' else '',
      if (!is.null(size)) paste0('<w:sz w:val="', as.integer(size), '"/><w:szCs w:val="', as.integer(size), '"/>') else '',
      if (!is.null(color)) paste0('<w:color w:val="', .docx_xml_escape(color), '"/>') else '',
      '</w:rPr>'
    )
    paste0(
      if (i > 1L) '<w:r><w:br/></w:r>' else '',
      '<w:r>', rpr, '<w:t xml:space="preserve">',
      .docx_xml_escape(lines[[i]]), '</w:t></w:r>'
    )
  }, character(1))

  paste0('<w:p>', ppr, paste0(runs, collapse = ''), '</w:p>')
}

.docx_format_column <- function(x, digits = 3L) {
  if (inherits(x, 'Date')) return(format(x, '%Y-%m-%d'))
  if (inherits(x, c('POSIXct', 'POSIXlt'))) return(format(x, '%Y-%m-%d %H:%M:%S'))
  if (is.factor(x)) return(as.character(x))
  if (is.numeric(x)) {
    out <- formatC(x, digits = as.integer(digits), format = 'fg', flag = '#')
    out[is.na(x)] <- ''
    return(out)
  }
  out <- as.character(x)
  out[is.na(x)] <- ''
  out
}

.docx_cell <- function(text, width, header = FALSE, align = 'left') {
  fill <- if (isTRUE(header)) '<w:shd w:val="clear" w:color="auto" w:fill="D9EAF7"/>' else ''
  paste0(
    '<w:tc><w:tcPr><w:tcW w:w="', as.integer(width), '" w:type="dxa"/>',
    fill, '<w:vAlign w:val="center"/></w:tcPr>',
    '<w:p><w:pPr><w:jc w:val="', align, '"/><w:spacing w:after="0"/></w:pPr>',
    '<w:r><w:rPr>', if (isTRUE(header)) '<w:b/>' else '',
    '<w:sz w:val="19"/><w:szCs w:val="19"/></w:rPr>',
    '<w:t xml:space="preserve">', .docx_xml_escape(text), '</w:t></w:r></w:p></w:tc>'
  )
}

.docx_table <- function(x, digits = 3L) {
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  if (!ncol(x)) stop('A Word table must contain at least one column.', call. = FALSE)

  formatted <- lapply(x, .docx_format_column, digits = digits)
  names(formatted) <- names(x)

  max_chars <- vapply(seq_along(formatted), function(i) {
    values <- c(names(formatted)[[i]], formatted[[i]])
    max(4L, min(28L, max(nchar(values, type = 'width'), na.rm = TRUE)))
  }, integer(1))
  widths <- pmax(720L, as.integer(round(9000 * max_chars / sum(max_chars))))

  header <- paste0(
    '<w:tr><w:trPr><w:tblHeader/></w:trPr>',
    paste0(vapply(seq_along(formatted), function(i) {
      .docx_cell(names(formatted)[[i]], widths[[i]], header = TRUE)
    }, character(1)), collapse = ''),
    '</w:tr>'
  )

  rows <- if (!nrow(x)) '' else paste0(vapply(seq_len(nrow(x)), function(row) {
    cells <- vapply(seq_along(formatted), function(col) {
      align <- if (is.numeric(x[[col]])) 'right' else 'left'
      .docx_cell(formatted[[col]][[row]], widths[[col]], align = align)
    }, character(1))
    paste0('<w:tr>', paste0(cells, collapse = ''), '</w:tr>')
  }, character(1)), collapse = '')

  paste0(
    '<w:tbl>',
    '<w:tblPr><w:tblW w:w="9000" w:type="dxa"/>',
    '<w:tblLayout w:type="fixed"/>',
    '<w:tblBorders>',
    '<w:top w:val="single" w:sz="4" w:color="A6A6A6"/>',
    '<w:left w:val="single" w:sz="4" w:color="A6A6A6"/>',
    '<w:bottom w:val="single" w:sz="4" w:color="A6A6A6"/>',
    '<w:right w:val="single" w:sz="4" w:color="A6A6A6"/>',
    '<w:insideH w:val="single" w:sz="3" w:color="D9D9D9"/>',
    '<w:insideV w:val="single" w:sz="3" w:color="D9D9D9"/>',
    '</w:tblBorders><w:tblCellMar>',
    '<w:top w:w="70" w:type="dxa"/><w:left w:w="100" w:type="dxa"/>',
    '<w:bottom w:w="70" w:type="dxa"/><w:right w:w="100" w:type="dxa"/>',
    '</w:tblCellMar></w:tblPr>',
    header, rows, '</w:tbl>'
  )
}

.docx_write_file <- function(path, text) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  base::writeLines(text, path, useBytes = TRUE)
}

.docx_zip_directory <- function(source, destination) {
  exe <- Sys.which('powershell.exe')
  if (!nzchar(exe)) exe <- Sys.which('powershell')
  if (!nzchar(exe)) exe <- Sys.which('pwsh')
  if (!nzchar(exe)) stop('PowerShell is required to package the Word document.', call. = FALSE)

  script <- tempfile('winshiny_docx_', fileext = '.ps1')
  on.exit(unlink(script), add = TRUE)
  base::writeLines(c(
    'param([string]$Source, [string]$Destination)',
    '$ErrorActionPreference = "Stop"',
    'Add-Type -AssemblyName System.IO.Compression.FileSystem',
    'if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }',
    '[System.IO.Compression.ZipFile]::CreateFromDirectory($Source, $Destination, [System.IO.Compression.CompressionLevel]::Optimal, $false)'
  ), script, useBytes = TRUE)

  result <- suppressWarnings(system2(
    exe,
    c('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-File', shQuote(script), shQuote(source), shQuote(destination)),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(result, 'status') %||% 0L
  if (!identical(as.integer(status), 0L) || !file.exists(destination) || file.info(destination)$size <= 0) {
    stop('Could not create the Word document. PowerShell output: ',
         paste(result, collapse = '\n'), call. = FALSE)
  }
  invisible(destination)
}

#' Write one or more data frames to a Word document
#'
#' A WinShiny-specific export helper that creates a simple standards-based
#' Office Open XML document without requiring officer, flextable, or Word COM.
#'
#' @param x A data frame or a named list of data frames.
#' @param file Output `.docx` path.
#' @param title Optional document title.
#' @param subtitle Optional paragraph below the title.
#' @param notes Optional notes written after the tables.
#' @param digits Significant digits used for numeric cells.
#' @return The normalized output path, invisibly.
writeDocxTable <- function(x, file, title = NULL, subtitle = NULL,
                           notes = NULL, digits = 3L) {
  tables <- if (is.data.frame(x)) list(x) else x
  if (!is.list(tables) || !length(tables) || !all(vapply(tables, is.data.frame, logical(1)))) {
    stop('`x` must be a data frame or a non-empty list of data frames.', call. = FALSE)
  }
  table_names <- names(tables)
  if (is.null(table_names)) table_names <- rep('', length(tables))
  table_names[is.na(table_names)] <- ''

  file <- normalizePath(file, winslash = '/', mustWork = FALSE)
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  work <- tempfile('winshiny_docx_')
  dir.create(work, recursive = TRUE)
  on.exit(unlink(work, recursive = TRUE, force = TRUE), add = TRUE)

  body <- character()
  if (!is.null(title) && nzchar(as.character(title)[1])) {
    body <- c(body, .docx_paragraph(as.character(title)[1], style = 'Title', space_after = 160L))
  }
  if (!is.null(subtitle) && nzchar(as.character(subtitle)[1])) {
    body <- c(body, .docx_paragraph(as.character(subtitle)[1], color = '595959', space_after = 180L))
  }
  for (i in seq_along(tables)) {
    if (nzchar(table_names[[i]])) {
      body <- c(body, .docx_paragraph(table_names[[i]], style = 'Heading1', space_after = 80L))
    }
    body <- c(body, .docx_table(tables[[i]], digits = digits), .docx_paragraph('', space_after = 80L))
  }
  if (!is.null(notes) && length(notes)) {
    body <- c(body, .docx_paragraph(paste(as.character(notes), collapse = '\n'), color = '595959', space_after = 0L))
  }

  document <- paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    '<w:body>', paste0(body, collapse = ''),
    '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>',
    '<w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" ',
    'w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>',
    '</w:body></w:document>'
  )

  styles <- paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/>',
    '<w:sz w:val="21"/><w:szCs w:val="21"/></w:rPr></w:rPrDefault>',
    '<w:pPrDefault><w:pPr/></w:pPrDefault></w:docDefaults>',
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">',
    '<w:name w:val="Normal"/><w:qFormat/></w:style>',
    '<w:style w:type="paragraph" w:styleId="Title">',
    '<w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/>',
    '<w:qFormat/><w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/>',
    '<w:color w:val="1F4E79"/></w:rPr></w:style>',
    '<w:style w:type="paragraph" w:styleId="Heading1">',
    '<w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/>',
    '<w:qFormat/><w:rPr><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/>',
    '<w:color w:val="1F4E79"/></w:rPr></w:style>',
    '</w:styles>'
  )

  created <- format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')
  core_title <- if (!is.null(title) && length(title) && nzchar(as.character(title)[1])) as.character(title)[1] else 'WinShiny table export'
  core <- paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" ',
    'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" ',
    'xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
    '<dc:title>', .docx_xml_escape(core_title), '</dc:title>',
    '<dc:creator>WinShiny</dc:creator><cp:lastModifiedBy>WinShiny</cp:lastModifiedBy>',
    '<dcterms:created xsi:type="dcterms:W3CDTF">', created, '</dcterms:created>',
    '<dcterms:modified xsi:type="dcterms:W3CDTF">', created, '</dcterms:modified>',
    '</cp:coreProperties>'
  )

  .docx_write_file(file.path(work, '[Content_Types].xml'), paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    '<Default Extension="xml" ContentType="application/xml"/>',
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>',
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>',
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
    '</Types>'
  ))
  .docx_write_file(file.path(work, '_rels', '.rels'), paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>',
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>',
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>',
    '</Relationships>'
  ))
  .docx_write_file(file.path(work, 'word', 'document.xml'), document)
  .docx_write_file(file.path(work, 'word', 'styles.xml'), styles)
  .docx_write_file(file.path(work, 'word', '_rels', 'document.xml.rels'), paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>'
  ))
  .docx_write_file(file.path(work, 'docProps', 'core.xml'), core)
  .docx_write_file(file.path(work, 'docProps', 'app.xml'), paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" ',
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">',
    '<Application>WinShiny</Application><AppVersion>0.4</AppVersion>',
    '</Properties>'
  ))

  .docx_zip_directory(work, file)
  invisible(file)
}
