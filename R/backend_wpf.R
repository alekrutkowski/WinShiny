# Native WPF backend used by WinShiny.

.write_json_state <- function(path, state) {
  payload <- as.list(state, all.names = TRUE)
  json <- jsonlite::toJSON(
    payload,
    auto_unbox = TRUE,
    null = 'null',
    na = 'string',
    dataframe = 'rows',
    digits = NA,
    POSIXt = 'ISO8601',
    Date = 'ISO8601',
    pretty = FALSE
  )
  tmp <- paste0(
    path, '.', Sys.getpid(), '.',
    paste(sample(c(letters, 0:9), 10L, replace = TRUE), collapse = ''),
    '.new'
  )
  writeLines(json, tmp, useBytes = TRUE)
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)

  # On Windows, the PowerShell polling timer may briefly have the previous
  # snapshot open. Retry the atomic replacement rather than failing the R
  # event loop during rapid interaction.
  for (attempt in seq_len(60L)) {
    removed <- !file.exists(path) || identical(suppressWarnings(unlink(path)), 0L)
    if (removed && isTRUE(file.rename(tmp, path))) return(invisible(path))
    Sys.sleep(0.01)
  }

  # Last-resort non-atomic copy. PowerShell catches transient JSON parse
  # failures and will read the completed snapshot on its next polling tick.
  ok <- suppressWarnings(file.copy(tmp, path, overwrite = TRUE))
  if (!isTRUE(ok)) stop('Could not update WinShiny state file: ', path, call. = FALSE)
  invisible(path)
}


.table_payload <- function(value) {
  value <- as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE)
  labels <- names(value)
  keys <- sprintf('c%04d', seq_along(labels))

  scalar <- function(column, i) {
    x <- column[[i]]
    if (is.factor(x) || inherits(x, c('Date', 'POSIXt'))) x <- as.character(x)
    if (length(x) == 0L) return(NULL)
    if (length(x) > 1L) return(paste(as.character(x), collapse = ', '))
    unname(x)
  }

  rows <- if (nrow(value)) {
    lapply(seq_len(nrow(value)), function(i) {
      row <- lapply(value, scalar, i = i)
      names(row) <- keys
      row
    })
  } else {
    list()
  }

  list(
    columns = unname(Map(function(key, label) list(key = key, label = label), keys, labels)),
    rows = unname(rows)
  )
}

.append_json_command <- function(path, type, payload = list()) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  json <- jsonlite::toJSON(
    list(type = type, payload = payload),
    auto_unbox = TRUE, null = 'null', na = 'null',
    dataframe = 'rows', digits = NA
  )
  stamp <- sprintf('%020.0f', as.numeric(Sys.time()) * 1e6)
  token <- paste(sample(c(letters, 0:9), 16L, replace = TRUE), collapse = '')
  final <- file.path(path, paste0('command_', stamp, '_', token, '.json'))
  temp <- paste0(final, '.tmp')
  writeLines(json, temp, useBytes = TRUE)
  if (!isTRUE(file.rename(temp, final))) {
    ok <- file.copy(temp, final, overwrite = TRUE)
    unlink(temp)
    if (!isTRUE(ok)) stop('Could not queue WinShiny command.', call. = FALSE)
  }
  invisible(final)
}

collect_nodes <- function(ui) {
  out <- list(inputs = list(), outputs = list(), title = 'WinShiny', ui = ui,
              initialTheme = 'light', navValues = list(), themeIds = character())
  walk <- function(x, visibleWhen = NULL) {
    if (inherits(x, 'winshiny.ui_input')) {
      x$visibleWhen <- visibleWhen
      out$inputs[[length(out$inputs) + 1L]] <<- x
      if (identical(x$kind, 'theme')) {
        out$themeIds <<- unique(c(out$themeIds, x$id))
        if (isTRUE(x$value)) out$initialTheme <<- 'dark'
      }
    } else if (inherits(x, 'winshiny.ui_output')) {
      x$visibleWhen <- visibleWhen
      out$outputs[[length(out$outputs) + 1L]] <<- x
    } else if (inherits(x, 'winshiny.tag')) {
      if (identical(x$type, 'titlePanel') && length(x$children)) {
        out$title <<- paste(as.character(x$children[[1]]), collapse = ' ')
      }
      if (x$type %in% c('navbarPage', 'tabsetPanel', 'navlistPanel') && !is.null(x$attribs$id)) {
        tab_values <- vapply(x$children, function(child) {
          if (inherits(child, 'winshiny.tag') && identical(child$type, 'tabPanel')) {
            as.character(child$attribs$value %||% child$attribs$title %||% '')
          } else ''
        }, character(1))
        tab_values <- tab_values[nzchar(tab_values)]
        selected <- as.character(x$attribs$selected %||% if (length(tab_values)) tab_values[[1]] else '')
        out$navValues[[as.character(x$attribs$id)]] <<- selected
      }
      if (identical(x$type, 'navbarPage')) {
        out$title <<- as.character(x$attribs$windowTitle %||% x$attribs$title %||% out$title)
        theme <- x$attribs$theme
        if (is.character(theme) && length(theme) && grepl('dark', theme[[1]], ignore.case = TRUE)) {
          out$initialTheme <<- 'dark'
        }
      }
      if (identical(x$type, 'fluidPage')) {
        theme <- x$attribs$theme
        if (is.character(theme) && length(theme) && grepl('dark', theme[[1]], ignore.case = TRUE)) {
          out$initialTheme <<- 'dark'
        }
      }
      childVisible <- visibleWhen
      if (identical(x$type, 'conditionalPanel')) childVisible <- x$attribs$condition %||% visibleWhen
      lapply(x$children, walk, visibleWhen = childVisible)
    }
    invisible(NULL)
  }
  walk(ui)
  out
}

.ui_input_defaults <- function(spec) {
  result <- list()
  walk <- function(x) {
    if (is.null(x)) return()
    if (is.list(x) && identical(x$nodeType, 'input')) {
      result[[as.character(x$id)]] <<- x$value
    } else if (is.list(x)) {
      ch <- x$children %||% list()
      lapply(ch, walk)
    }
  }
  walk(spec)
  result
}

`$<-.winshiny.output` <- function(x, name, value) {
  session <- attr(x, 'session')
  if (inherits(value, 'winshiny.downloadHandler')) {
    session$registerDownload(name, value)
  } else if (is.function(value)) {
    ctx <- .ctx('output')
    ctx$run <- function() {
      kind <- if (inherits(value, 'winshiny.render.plot')) {
        'plot'
      } else if (inherits(value, 'winshiny.render.image')) {
        'image'
      } else if (inherits(value, 'winshiny.render.datatable')) {
        'datatable'
      } else if (inherits(value, 'winshiny.render.table')) {
        'table'
      } else if (inherits(value, 'winshiny.render.ui')) {
        'ui'
      } else {
        'text'
      }
      tryCatch({
        if (identical(kind, 'plot')) {
          size <- session$getPlotSize(name)
          v <- value(width_px = size$width, height_px = size$height, theme = session$getTheme())
        } else {
          v <- value()
        }
        if (identical(kind, 'ui')) session$registerUiDefaults(v)
        session$sendOutput(name, v, kind)
      }, error = function(e) {
        session$sendOutput(name, conditionMessage(e), 'error')
      })
    }
    assign(name, ctx, envir = x)
    .schedule(ctx)
  } else {
    session$sendOutput(name, value, 'text')
  }
  x
}

.ps_gen_state <- function() {
  e <- new.env(parent = emptyenv())
  e$n <- 0L
  e
}
.ps_new_var <- function(st, prefix = 'v') {
  st$n <- st$n + 1L
  paste0('$', .win_id(prefix), '_', st$n)
}
.ps_add_child <- function(parent, child) paste0('  [void]', parent, '.Children.Add(', child, ')')
.ps_set_grid <- function(child, col = NULL, row = NULL, colspan = NULL, rowspan = NULL) {
  c(
    if (!is.null(col)) paste0('  [Windows.Controls.Grid]::SetColumn(', child, ',', col, ')'),
    if (!is.null(row)) paste0('  [Windows.Controls.Grid]::SetRow(', child, ',', row, ')'),
    if (!is.null(colspan)) paste0('  [Windows.Controls.Grid]::SetColumnSpan(', child, ',', colspan, ')'),
    if (!is.null(rowspan)) paste0('  [Windows.Controls.Grid]::SetRowSpan(', child, ',', rowspan, ')')
  )
}
.ps_condition_lines <- function(var, condition) {
  ci <- .parse_condition(condition)
  if (is.null(ci)) return(character())
  expected <- if (isTRUE(ci$value)) '$true' else if (identical(ci$value, FALSE)) '$false' else .ps_quote(ci$value)
  c(
    paste0('  $controls[', .ps_quote(paste0('conditional_', .win_id(var))), ']=', var),
    paste0('  [void]$conditionalRules.Add(@{target=', .ps_quote(paste0('conditional_', .win_id(var))),
           ';source=', .ps_quote(ci$source), ';expected=', expected, '})')
  )
}

.ps_text_value <- function(x) {
  if (inherits(x, 'winshiny.icon')) return(paste0('[', x$name, ']'))
  paste(as.character(x), collapse = '\n')
}

.date_dotnet_format <- function(format) {
  x <- as.character(format %||% 'yyyy-mm-dd')[1L]
  key <- tolower(x)
  known <- c(
    'yyyy-mm-dd' = 'yyyy-MM-dd',
    'yyyy/mm/dd' = 'yyyy/MM/dd',
    'dd/mm/yyyy' = 'dd/MM/yyyy',
    'd/m/yyyy' = 'd/M/yyyy',
    'dd-mm-yyyy' = 'dd-MM-yyyy',
    'd-m-yyyy' = 'd-M-yyyy',
    'dd.mm.yyyy' = 'dd.MM.yyyy',
    'd.m.yyyy' = 'd.M.yyyy',
    'mm/dd/yyyy' = 'MM/dd/yyyy',
    'm/d/yyyy' = 'M/d/yyyy'
  )
  if (key %in% names(known)) return(unname(known[[key]]))

  # Translate the numeric date tokens used by Shiny/bootstrap-datepicker to
  # their .NET equivalents. In .NET, upper-case M is month and lower-case m
  # is minute, so this conversion is required even when separators are kept.
  placeholders <- c(
    'yyyy' = '__WS_YEAR4__', 'yy' = '__WS_YEAR2__',
    'mm' = '__WS_MONTH2__', 'm' = '__WS_MONTH1__',
    'dd' = '__WS_DAY2__', 'd' = '__WS_DAY1__'
  )
  out <- tolower(x)
  for (token in names(placeholders)) out <- gsub(token, placeholders[[token]], out, fixed = TRUE)
  replacements <- c(
    '__WS_YEAR4__' = 'yyyy', '__WS_YEAR2__' = 'yy',
    '__WS_MONTH2__' = 'MM', '__WS_MONTH1__' = 'M',
    '__WS_DAY2__' = 'dd', '__WS_DAY1__' = 'd'
  )
  for (token in names(replacements)) out <- gsub(token, replacements[[token]], out, fixed = TRUE)
  out
}

.date_picker_culture <- function(format, language = NULL) {
  lang <- as.character(language %||% '')[1L]
  if (grepl('^[A-Za-z]{2,3}-[A-Za-z]{2}$', lang)) return(lang)
  mapped <- c(
    en = 'en-GB', pl = 'pl-PL', de = 'de-DE', fr = 'fr-FR',
    nl = 'nl-NL', es = 'es-ES', it = 'it-IT', pt = 'pt-PT',
    cs = 'cs-CZ', sk = 'sk-SK', hu = 'hu-HU'
  )
  if (tolower(lang) %in% names(mapped) && tolower(lang) != 'en') return(unname(mapped[[tolower(lang)]]))
  key <- tolower(as.character(format %||% 'yyyy-mm-dd')[1L])
  if (grepl('^m', key)) return('en-US')
  if (grepl('^y', key)) return('sv-SE')
  'en-GB'
}

.ps_emit_input <- function(inp, parent, st, visibleWhen = NULL) {
  id <- inp$id
  safe <- .win_id(id)
  kind <- inp$kind
  lab <- .ps_text_value(inp$label %||% id)
  wrap <- .ps_new_var(st, paste0('wrap_', safe))
  ctrl <- .ps_new_var(st, paste0('input_', safe))
  label <- .ps_new_var(st, paste0('label_', safe))
  lines <- c(
    paste0('  ', wrap, '=New-Object Windows.Controls.StackPanel'),
    paste0('  ', wrap, '.Margin="0,4,0,8"'),
    paste0('  $controls[', .ps_quote(paste0('wrap_', id)), ']=', wrap),
    paste0('  $inputValues[', .ps_quote(id), ']=', .ps_jsonish(inp$value))
  )

  add_label <- !kind %in% c('checkbox', 'theme', 'button', 'link', 'submit', 'clipboard', 'copytable', 'copyplot')
  if (add_label) {
    lines <- c(lines,
      paste0('  ', label, '=New-Object Windows.Controls.TextBlock'),
      paste0('  ', label, '.Text=', .ps_quote(lab)),
      paste0('  ', label, '.FontWeight="SemiBold"; ', label, '.Margin="0,0,0,3"'),
      paste0('  $controls[', .ps_quote(paste0('label_', id)), ']=', label),
      paste0('  [void]', wrap, '.Children.Add(', label, ')')
    )
  }

  if (kind %in% c('text', 'textarea')) {
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.TextBox'),
      paste0('  ', ctrl, '.Text=', .ps_quote(inp$value %||% '')),
      if (kind == 'textarea') paste0('  ', ctrl, '.MinHeight=', .px(inp$args$height, 90), '; ', ctrl, '.AcceptsReturn=$true; ', ctrl, '.TextWrapping="Wrap"') else '',
      paste0('  ', ctrl, '.Add_TextChanged({ Send-Event ', .ps_quote(id), ' $this.Text; Flush-PendingEvents })')
    )
  } else if (kind == 'password') {
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.PasswordBox'),
      paste0('  ', ctrl, '.Password=', .ps_quote(inp$value %||% '')),
      paste0('  ', ctrl, '.Add_PasswordChanged({ Send-Event ', .ps_quote(id), ' $this.Password; Flush-PendingEvents })')
    )
  } else if (kind == 'numeric') {
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.TextBox'),
      paste0('  ', ctrl, '.Text=', .ps_quote(inp$value %||% '')),
      paste0('  ', ctrl, '.Add_TextChanged({ $number=0.0; if([double]::TryParse($this.Text,[ref]$number)){ Send-Event ', .ps_quote(id), ' $number; Flush-PendingEvents } })')
    )
  } else if (kind %in% c('checkbox', 'theme')) {
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.CheckBox'),
      paste0('  ', ctrl, '.Content=', .ps_quote(lab)),
      paste0('  ', ctrl, '.IsChecked=', .ps_bool(inp$value)),
      if (kind == 'theme') {
        paste0('  ', ctrl, '.Add_Click({ $script:isDark=[bool]$this.IsChecked; Apply-Theme $win $script:isDark; Send-Event ', .ps_quote(id), ' $script:isDark; Flush-PendingEvents })')
      } else {
        paste0('  ', ctrl, '.Add_Click({ Send-Event ', .ps_quote(id), ' ([bool]$this.IsChecked); Flush-PendingEvents })')
      }
    )
  } else if (kind == 'slider') {
    smin <- suppressWarnings(as.numeric(inp$args$min %||% 0)); if (is.na(smin)) smin <- 0
    smax <- suppressWarnings(as.numeric(inp$args$max %||% 100)); if (is.na(smax)) smax <- 100
    sstep <- suppressWarnings(as.numeric(inp$args$step %||% 1)); if (is.na(sstep) || sstep <= 0) sstep <- 1
    sval <- suppressWarnings(as.numeric(if (length(inp$value) > 1) inp$value[[1]] else inp$value %||% smin)); if (is.na(sval)) sval <- smin
    fmt <- if (abs(sstep - round(sstep)) < .Machine$double.eps^0.5) '0' else '0.######'
    pre <- as.character(inp$args$pre %||% '')
    post <- as.character(inp$args$post %||% '')
    slider <- .ps_new_var(st, paste0('slider_', safe))
    row <- .ps_new_var(st, paste0('sliderrow_', safe))
    mn <- .ps_new_var(st, 'min')
    cv <- .ps_new_var(st, 'current')
    mx <- .ps_new_var(st, 'max')
    timer <- paste0('$sliderTimer_', safe)
    valvar <- paste0('$script:sliderValue_', safe)
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.StackPanel'),
      paste0('  ', slider, '=New-Object Windows.Controls.Slider'),
      paste0('  ', slider, '.Minimum=', .ps_num(smin), '; ', slider, '.Maximum=', .ps_num(smax), '; ', slider, '.Value=', .ps_num(sval)),
      paste0('  ', slider, '.TickFrequency=', .ps_num(sstep), '; ', slider, '.SmallChange=', .ps_num(sstep), '; ', slider, '.LargeChange=', .ps_num(max(sstep, (smax-smin)/10))),
      paste0('  ', slider, '.IsSnapToTickEnabled=$true; ', slider, '.IsMoveToPointEnabled=$true; ', slider, '.TickPlacement="BottomRight"'),
      paste0('  ', slider, '.AutoToolTipPlacement="TopLeft"; ', slider, '.AutoToolTipPrecision=', if (fmt == '0') 0 else 4),
      paste0('  [void]', ctrl, '.Children.Add(', slider, ')'),
      paste0('  ', row, '=New-Object Windows.Controls.Grid'),
      paste0('  [void]', row, '.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))'),
      paste0('  [void]', row, '.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))'),
      paste0('  [void]', row, '.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))'),
      paste0('  ', mn, '=New-Object Windows.Controls.TextBlock; ', mn, '.Text=', .ps_quote(paste0(pre, format(smin, scientific = FALSE, trim = TRUE), post))),
      paste0('  ', cv, '=New-Object Windows.Controls.TextBlock; ', cv, '.TextAlignment="Center"'),
      paste0('  ', mx, '=New-Object Windows.Controls.TextBlock; ', mx, '.TextAlignment="Right"; ', mx, '.Text=', .ps_quote(paste0(pre, format(smax, scientific = FALSE, trim = TRUE), post))),
      .ps_set_grid(mn, col = 0), .ps_set_grid(cv, col = 1), .ps_set_grid(mx, col = 2),
      paste0('  [void]', row, '.Children.Add(', mn, '); [void]', row, '.Children.Add(', cv, '); [void]', row, '.Children.Add(', mx, ')'),
      paste0('  [void]', ctrl, '.Children.Add(', row, ')'),
      paste0('  function UpdateSliderLabel_', safe, ' { param($v) ', cv, '.Text=', .ps_quote(pre), ' + ([double]$v).ToString(', .ps_quote(fmt), ') + ', .ps_quote(post), ' }'),
      paste0('  UpdateSliderLabel_', safe, ' ', slider, '.Value'),
      paste0('  ', valvar, '=', slider, '.Value'),
      paste0('  ', timer, '=New-Object Windows.Threading.DispatcherTimer; ', timer, '.Interval=[TimeSpan]::FromMilliseconds(150)'),
      paste0('  ', timer, '.Add_Tick({ ', timer, '.Stop(); Send-Event ', .ps_quote(id), ' ([math]::Round([double]', valvar, ',8)) })'),
      paste0('  ', slider, '.Add_ValueChanged({ UpdateSliderLabel_', safe, ' $this.Value; ', valvar, '=$this.Value; ', timer, '.Stop(); ', timer, '.Start() })'),
      paste0('  $inputControls[', .ps_quote(id), ']=', slider)
    )
  } else if (kind %in% c('select', 'selectize', 'varselectize')) {
    choices <- inp$args$choices %||% character()
    multiple <- isTRUE(inp$args$multiple)
    selected <- as.character(inp$value %||% character())
    use_selectize <- kind %in% c('selectize', 'varselectize') || isTRUE(inp$args$selectize)

    if (use_selectize) {
      options <- inp$args$options %||% list()
      prompt <- as.character(options$placeholder %||% if (multiple) {
        'Search and select one or more items...'
      } else {
        'Search and select an item...'
      })[[1L]]
      choice_values <- as.character(choices)
      choice_labels <- names(choices)
      if (is.null(choice_labels)) choice_labels <- choice_values
      choice_labels[!nzchar(choice_labels)] <- choice_values[!nzchar(choice_labels)]
      ps_entries <- Map(function(label, value) {
        paste0(
          '[pscustomobject]@{Display=', .ps_quote(label),
          ';Value=', .ps_quote(value), '}'
        )
      }, choice_labels, choice_values)
      ps_choices <- paste0(
        '([object[]]@(', paste(unlist(ps_entries), collapse = ','), '))'
      )
      ps_selected <- paste0(
        '([object[]]@(',
        paste(vapply(selected, .ps_quote, character(1)), collapse = ','),
        '))'
      )
      lines <- c(lines,
        paste0(
          ' ', ctrl, '=New-WinShinySelectizeControl -Items ', ps_choices,
          ' -SelectedValues ', ps_selected,
          ' -Multiple ', .ps_bool(multiple),
          ' -Prompt ', .ps_quote(prompt),
          ' -InputId ', .ps_quote(id),
          ' -DarkMode $script:isDark',
          ' -DisplayProperty ', .ps_quote('Display'),
          ' -ValueProperty ', .ps_quote('Value')
        )
      )
    } else if (multiple) {
      visible_items <- suppressWarnings(as.integer(inp$args$size %||% min(6L, max(3L, length(choices)))))
      if (is.na(visible_items) || visible_items < 1L) visible_items <- 6L
      lines <- c(lines,
        paste0(' ', ctrl, '=New-Object Windows.Controls.ListBox'),
        paste0(' ', ctrl, '.SelectionMode="Multiple"; ', ctrl, '.MinHeight=', max(72L, 26L * visible_items), '; ', ctrl, '.MaxHeight=', max(72L, 26L * visible_items)),
        unname(vapply(choices, function(v) paste0(' [void]', ctrl, '.Items.Add(', .ps_quote(v), ')'), character(1))),
        unname(vapply(selected, function(v) paste0(' if(', ctrl, '.Items.Contains(', .ps_quote(v), ')){ [void]', ctrl, '.SelectedItems.Add(', .ps_quote(v), ') }'), character(1))),
        paste0(' ', ctrl, '.Add_SelectionChanged({ $vals=[string[]]@($this.SelectedItems | ForEach-Object { [string]$_ }); Send-Event ', .ps_quote(id), ' $vals; Flush-PendingEvents })')
      )
    } else {
      lines <- c(lines,
        paste0(' ', ctrl, '=New-Object Windows.Controls.ComboBox'),
        paste0(' ', ctrl, '.IsEditable=$false; ', ctrl, '.IsTextSearchEnabled=$true'),
        unname(vapply(choices, function(v) paste0(' [void]', ctrl, '.Items.Add(', .ps_quote(v), ')'), character(1))),
        paste0(' ', ctrl, '.SelectedItem=', .ps_quote(if (length(selected)) selected[[1]] else '')),
        paste0(' ', ctrl, '.Add_SelectionChanged({ if($this.SelectedItem -ne $null){ Send-Event ', .ps_quote(id), ' ([string]$this.SelectedItem); Flush-PendingEvents } })')
      )
    }

  } else if (kind == 'radio') {
    choices <- inp$args$choices %||% character()
    lines <- c(lines, paste0('  ', ctrl, '=New-Object Windows.Controls.', if (isTRUE(inp$args$inline)) 'WrapPanel' else 'StackPanel'))
    for (j in seq_along(choices)) {
      rb <- .ps_new_var(st, paste0('radio_', safe, '_', j))
      nm <- names(choices)[j]; val <- unname(choices)[j]
      lines <- c(lines,
        paste0('  ', rb, '=New-Object Windows.Controls.RadioButton'),
        paste0('  ', rb, '.Content=', .ps_quote(nm), '; ', rb, '.Tag=', .ps_quote(val), '; ', rb, '.Margin="0,2,12,2"'),
        paste0('  ', rb, '.IsChecked=', .ps_bool(identical(as.character(inp$value), as.character(val)))),
        paste0('  ', rb, '.Add_Click({ Send-Event ', .ps_quote(id), ' ([string]$this.Tag); Flush-PendingEvents })'),
        paste0('  [void]', ctrl, '.Children.Add(', rb, ')')
      )
    }
  } else if (kind == 'checkboxgroup') {
    choices <- inp$args$choices %||% character(); selected <- as.character(inp$value)
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.', if (isTRUE(inp$args$inline)) 'WrapPanel' else 'StackPanel'),
      paste0('  ', ctrl, '.Tag="winshiny-checkboxgroup"')
    )
    for (j in seq_along(choices)) {
      cb <- .ps_new_var(st, paste0('check_', safe, '_', j))
      nm <- names(choices)[j]; val <- unname(choices)[j]
      lines <- c(lines,
        paste0('  ', cb, '=New-Object Windows.Controls.CheckBox'),
        paste0('  ', cb, '.Content=', .ps_quote(nm), '; ', cb, '.Tag=', .ps_quote(val), '; ', cb, '.Margin="0,2,12,2"'),
        paste0('  ', cb, '.IsChecked=', .ps_bool(val %in% selected)),
        paste0('  ', cb, '.Add_Click({ $vals=@(); foreach($child in ', ctrl, '.Children){ if($child.IsChecked){ $vals += [string]$child.Tag } }; Send-Event ', .ps_quote(id), ' $vals; Flush-PendingEvents })'),
        paste0('  [void]', ctrl, '.Children.Add(', cb, ')')
      )
    }
  } else if (kind == 'date') {
    display_format <- .date_dotnet_format(inp$args$format)
    culture <- .date_picker_culture(inp$args$format, inp$args$language)
    week_start <- suppressWarnings(as.integer(inp$args$weekstart %||% 0L))
    if (is.na(week_start)) week_start <- 0L
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.DatePicker'),
      paste0('  Initialize-WinShinyDatePicker ', ctrl, ' ', .ps_quote(display_format), ' ', .ps_quote(culture), ' ', week_start),
      if (!is.null(inp$args$min) && nzchar(inp$args$min)) paste0('  ', ctrl, '.DisplayDateStart=[datetime]', .ps_quote(inp$args$min)),
      if (!is.null(inp$args$max) && nzchar(inp$args$max)) paste0('  ', ctrl, '.DisplayDateEnd=[datetime]', .ps_quote(inp$args$max)),
      paste0('  ', ctrl, '.SelectedDate=[datetime]', .ps_quote(inp$value)),
      paste0('  ', ctrl, '.Add_SelectedDateChanged({ if($this.SelectedDate){ Send-Event ', .ps_quote(id), ' $this.SelectedDate.ToString("yyyy-MM-dd"); Flush-PendingEvents } })')
    )
  } else if (kind == 'daterange') {
    d1 <- .ps_new_var(st, paste0('date1_', safe)); d2 <- .ps_new_var(st, paste0('date2_', safe))
    display_format <- .date_dotnet_format(inp$args$format)
    culture <- .date_picker_culture(inp$args$format, inp$args$language)
    week_start <- suppressWarnings(as.integer(inp$args$weekstart %||% 0L))
    if (is.na(week_start)) week_start <- 0L
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.WrapPanel'),
      paste0('  ', d1, '=New-Object Windows.Controls.DatePicker'),
      paste0('  ', d2, '=New-Object Windows.Controls.DatePicker'),
      paste0('  Initialize-WinShinyDatePicker ', d1, ' ', .ps_quote(display_format), ' ', .ps_quote(culture), ' ', week_start),
      paste0('  Initialize-WinShinyDatePicker ', d2, ' ', .ps_quote(display_format), ' ', .ps_quote(culture), ' ', week_start),
      if (!is.null(inp$args$min) && nzchar(inp$args$min)) paste0('  ', d1, '.DisplayDateStart=[datetime]', .ps_quote(inp$args$min), '; ', d2, '.DisplayDateStart=[datetime]', .ps_quote(inp$args$min)),
      if (!is.null(inp$args$max) && nzchar(inp$args$max)) paste0('  ', d1, '.DisplayDateEnd=[datetime]', .ps_quote(inp$args$max), '; ', d2, '.DisplayDateEnd=[datetime]', .ps_quote(inp$args$max)),
      paste0('  ', d1, '.SelectedDate=[datetime]', .ps_quote(inp$value[[1]])),
      paste0('  ', d2, '.SelectedDate=[datetime]', .ps_quote(inp$value[[2]])),
      paste0('  ', d1, '.Margin="0,0,8,0"'),
      paste0('  ', d1, '.Add_SelectedDateChanged({ if(', d1, '.SelectedDate -and ', d2, '.SelectedDate){ Send-Event ', .ps_quote(id), ' @(', d1, '.SelectedDate.ToString("yyyy-MM-dd"),', d2, '.SelectedDate.ToString("yyyy-MM-dd")); Flush-PendingEvents } })'),
      paste0('  ', d2, '.Add_SelectedDateChanged({ if(', d1, '.SelectedDate -and ', d2, '.SelectedDate){ Send-Event ', .ps_quote(id), ' @(', d1, '.SelectedDate.ToString("yyyy-MM-dd"),', d2, '.SelectedDate.ToString("yyyy-MM-dd")); Flush-PendingEvents } })'),
      paste0('  [void]', ctrl, '.Children.Add(', d1, '); [void]', ctrl, '.Children.Add(', d2, ')')
    )
  } else if (kind == 'file') {
    pathbox <- .ps_new_var(st, paste0('filepath_', safe)); button <- .ps_new_var(st, paste0('filebtn_', safe))
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.Grid'),
      paste0('  ', ctrl, '.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{Width="*"})) | Out-Null'),
      paste0('  ', ctrl, '.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{Width="Auto"})) | Out-Null'),
      paste0('  ', pathbox, '=New-Object Windows.Controls.TextBox; ', pathbox, '.IsReadOnly=$true; ', pathbox, '.Text=', .ps_quote(inp$args$placeholder %||% 'No file selected')),
      paste0('  ', button, '=New-Object Windows.Controls.Button; ', button, '.Content=', .ps_quote(inp$args$buttonLabel %||% 'Browse...'), '; ', button, '.Margin="8,0,0,0"'),
      paste0('  ', button, '.Add_Click({ $dlg=New-Object System.Windows.Forms.OpenFileDialog; $dlg.Multiselect=', .ps_bool(inp$args$multiple), '; if($dlg.ShowDialog() -eq "OK"){ ', pathbox, '.Text=($dlg.FileNames -join "; "); Send-Event ', .ps_quote(id), ' $dlg.FileNames; Flush-PendingEvents } })'),
      .ps_set_grid(button, col = 1),
      paste0('  [void]', ctrl, '.Children.Add(', pathbox, '); [void]', ctrl, '.Children.Add(', button, ')')
    )
  } else if (kind == 'clipboard') {
    clipprefix <- paste0('clipboard_', safe, '_')
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.Button'),
      paste0('  ', ctrl, '.Content=', .ps_quote(lab), '; ', ctrl, '.MinWidth=150; ', ctrl, '.HorizontalAlignment="Left"'),
      paste0('  ', ctrl, '.Add_Click({ try { Log ', .ps_quote(paste0('Clipboard import clicked: ', id)), '; '),
      paste0('    $text=$null; $last=$null; for($attempt=0;$attempt -lt 30;$attempt++){ try { if([System.Windows.Forms.Clipboard]::ContainsText([System.Windows.Forms.TextDataFormat]::UnicodeText)){ $text=[System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::UnicodeText) } elseif([System.Windows.Forms.Clipboard]::ContainsText()){ $text=[System.Windows.Forms.Clipboard]::GetText() } elseif([System.Windows.Clipboard]::ContainsText()){ $text=[System.Windows.Clipboard]::GetText() }; $last=$null; break } catch { $last=$_.Exception; Start-Sleep -Milliseconds 50 } }; if($null -ne $last){ throw $last }; if([string]::IsNullOrWhiteSpace([string]$text)){ throw "The Windows clipboard does not contain text." }; '),
      paste0('    Log ("Clipboard text characters: "+([string]$text).Length); $name=', .ps_quote(clipprefix), '+[DateTime]::UtcNow.Ticks+"_"+[Guid]::NewGuid().ToString("N")+".txt"; $final=Join-Path $clipboardDir $name; $temp=$final+".tmp"; $utf8=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($temp,[string]$text,$utf8); Move-Item -LiteralPath $temp -Destination $final -Force; Log ("Clipboard transfer file: "+$final); Send-Event ', .ps_quote(id), ' ([string]$final); Flush-PendingEvents; Log ', .ps_quote(paste0('Clipboard import event flushed: ', id)), ' '),
      paste0('  } catch { Send-Event ', .ps_quote(id), ' ("__WINSHINY_CLIPBOARD_ERROR__"+[string]$_.Exception.Message); Flush-PendingEvents } })')
    )
  } else if (kind == 'copytable') {
    ids <- inp$args$outputIds %||% character()
    labels <- inp$args$outputLabels %||% ids
    ps_ids <- paste0('@(', paste(vapply(ids, .ps_quote, character(1)), collapse = ','), ')')
    ps_labels <- paste0('@(', paste(vapply(labels, .ps_quote, character(1)), collapse = ','), ')')
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.Button'),
      paste0('  ', ctrl, '.Content=', .ps_quote(lab), '; ', ctrl, '.MinWidth=150; ', ctrl, '.HorizontalAlignment="Left"'),
      paste0('  ', ctrl, '.Add_Click({ Copy-WinShinyTables ', ps_ids, ' ', ps_labels, ' ', .ps_quote(inp$args$title %||% ''), ' ', .ps_quote(inp$args$subtitle %||% ''), ' ', .ps_quote(inp$args$notes %||% ''), ' })')
    )
  } else if (kind == 'copyplot') {
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.Button'),
      paste0('  ', ctrl, '.Content=', .ps_quote(lab), '; ', ctrl, '.MinWidth=150; ', ctrl, '.HorizontalAlignment="Left"'),
      paste0('  ', ctrl, '.Add_Click({ Copy-WinShinyPlot ', .ps_quote(inp$args$outputId %||% ''), ' })')
    )
  } else if (kind %in% c('button', 'link', 'submit')) {
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.Button'),
      paste0('  ', ctrl, '.Content=', .ps_quote(lab), '; ', ctrl, '.MinWidth=90; ', ctrl, '.HorizontalAlignment="Left"'),
      paste0('  $script:button_', safe, '=0'),
      paste0('  ', ctrl, '.Add_Click({ $script:button_', safe, '++; Send-Event ', .ps_quote(id), ' $script:button_', safe, '; Flush-PendingEvents })')
    )
  } else {
    lines <- c(lines,
      paste0('  ', ctrl, '=New-Object Windows.Controls.TextBlock'),
      paste0('  ', ctrl, '.Text=', .ps_quote(paste0('Unsupported input: ', kind)))
    )
  }

  if (!kind %in% c('slider')) lines <- c(lines, paste0('  $inputControls[', .ps_quote(id), ']=', ctrl))
  lines <- c(lines,
    paste0('  $controls[', .ps_quote(id), ']=', ctrl),
    paste0('  [void]', wrap, '.Children.Add(', ctrl, ')'),
    .ps_condition_lines(wrap, visibleWhen %||% inp$visibleWhen),
    .ps_add_child(parent, wrap)
  )
  list(lines = lines[nzchar(lines)], var = wrap)
}

.ps_emit_output <- function(out, parent, st, visibleWhen = NULL) {
  id <- out$id
  safe <- .win_id(id)
  kind <- out$kind
  lines <- character()

  if (kind %in% c('plot', 'image')) {
    border <- .ps_new_var(st, paste0('plotborder_', safe))
    grid <- .ps_new_var(st, paste0('plotgrid_', safe))
    image <- .ps_new_var(st, paste0('plotimage_', safe))
    status <- .ps_new_var(st, paste0('plotstatus_', safe))
    min_height <- .px(out$args$height %||% '300px', 300)
    lines <- c(lines,
      paste0('  ', border, '=New-Object Windows.Controls.Border'),
      paste0('  ', border, '.BorderBrush=$themeBorder; ', border, '.BorderThickness="1"; ', border, '.Margin="0,6,0,8"; ', border, '.MinHeight=', min_height),
      paste0('  ', border, '.HorizontalAlignment="Stretch"'),
      paste0('  ', grid, '=New-Object Windows.Controls.Grid'),
      paste0('  ', image, '=New-Object Windows.Controls.Image; ', image, '.Stretch="Fill"; ', image, '.HorizontalAlignment="Stretch"; ', image, '.VerticalAlignment="Stretch"; ', image, '.SnapsToDevicePixels=$true'),
      paste0('  ', status, '=New-Object Windows.Controls.TextBlock; ', status, '.Text="Waiting for plot..."; ', status, '.TextWrapping="Wrap"; ', status, '.Margin="12"; ', status, '.HorizontalAlignment="Center"; ', status, '.VerticalAlignment="Center"'),
      paste0('  [void]', grid, '.Children.Add(', image, '); [void]', grid, '.Children.Add(', status, ')'),
      paste0('  ', border, '.Child=', grid),
      paste0('  $controls[', .ps_quote(paste0('out_', id)), ']=', image),
      paste0('  $controls[', .ps_quote(paste0('outstatus_', id)), ']=', status),
      paste0('  $controls[', .ps_quote(paste0('outwrap_', id)), ']=', border),
      paste0('  $responsivePlots.Add([pscustomobject]@{Id=', .ps_quote(id), ';Border=', border, ';Image=', image, ';Status=', status, ';MinHeight=', min_height, ';LastWidth=0;LastHeight=0}) | Out-Null'),
      .ps_condition_lines(border, visibleWhen %||% out$visibleWhen),
      .ps_add_child(parent, border)
    )
    return(list(lines = lines[nzchar(lines)], var = border))
  }

  if (kind %in% c('table', 'datatable')) {
    border <- .ps_new_var(st, paste0('tableborder_', safe))
    grid <- .ps_new_var(st, paste0('tablegrid_', safe))
    table <- .ps_new_var(st, paste0('table_', safe))
    status <- .ps_new_var(st, paste0('tablestatus_', safe))
    fill <- isTRUE(out$args$fill) || identical(out$args$height, 'fill')
    lines <- c(lines,
      paste0('  ', border, '=New-Object Windows.Controls.Border; ', border, '.BorderBrush=$themeBorder; ', border, '.BorderThickness="1"; ', border, '.Margin="0,6,0,8"; ', border, '.VerticalAlignment="', if (fill) 'Stretch' else 'Top', '"'),
      paste0('  ', grid, '=New-Object Windows.Controls.Grid'),
      paste0('  ', table, '=New-Object Windows.Controls.DataGrid'),
      paste0('  ', table, '.AutoGenerateColumns=$false; ', table, '.IsReadOnly=$true; ', table, '.CanUserAddRows=$false; ', table, '.CanUserDeleteRows=$false; ', table, '.HeadersVisibility="Column"; ', table, '.RowHeaderWidth=0; ', table, '.RowDetailsVisibilityMode="Collapsed"; ', table, '.MinHeight=0; ', table, '.ColumnHeaderHeight=30; ', table, '.RowHeight=27'),
      paste0('  ', table, '.EnableRowVirtualization=$true; ', table, '.EnableColumnVirtualization=$true; ', table, '.GridLinesVisibility="All"; ', table, '.MinColumnWidth=72; ', table, '.CanUserResizeColumns=$true; ', table, '.HorizontalScrollBarVisibility="', if (fill) 'Disabled' else 'Auto', '"; ', table, '.VerticalScrollBarVisibility="Auto"; ', table, '.VerticalAlignment="', if (fill) 'Stretch' else 'Top', '"; ', table, '.MaxHeight=', if (fill) '[double]::PositiveInfinity' else '500'),
      paste0('  ', table, ' | Add-Member -NotePropertyName WinShinyFill -NotePropertyValue ', .ps_bool(fill), ' -Force'),
      paste0('  ', status, '=New-Object Windows.Controls.TextBlock; ', status, '.Text="Waiting for table..."; ', status, '.Margin="12"; ', status, '.HorizontalAlignment="Center"; ', status, '.VerticalAlignment="Center"'),
      paste0('  [void]', grid, '.Children.Add(', table, '); [void]', grid, '.Children.Add(', status, ')'),
      paste0('  ', border, '.Child=', grid),
      paste0('  $controls[', .ps_quote(paste0('out_', id)), ']=', table),
      paste0('  $controls[', .ps_quote(paste0('outstatus_', id)), ']=', status),
      if (fill) paste0('  $responsiveTables.Add([pscustomobject]@{Id=', .ps_quote(id), ';Border=', border, ';Grid=', table, '}) | Out-Null') else '',
      .ps_condition_lines(border, visibleWhen %||% out$visibleWhen),
      .ps_add_child(parent, border)
    )
    return(list(lines = lines[nzchar(lines)], var = border))
  }

  if (kind == 'ui') {
    border <- .ps_new_var(st, paste0('uiborder_', safe))
    host <- .ps_new_var(st, paste0('uihost_', safe))
    status <- .ps_new_var(st, paste0('uistatus_', safe))
    grid <- .ps_new_var(st, paste0('uigrid_', safe))
    lines <- c(lines,
      paste0('  ', border, '=New-Object Windows.Controls.Border; ', border, '.BorderBrush=$themeBorder; ', border, '.BorderThickness="1"; ', border, '.Padding="8"; ', border, '.Margin="0,6,0,8"'),
      paste0('  ', grid, '=New-Object Windows.Controls.Grid'),
      paste0('  ', host, '=New-Object Windows.Controls.ContentControl'),
      paste0('  ', status, '=New-Object Windows.Controls.TextBlock; ', status, '.Text="Waiting for UI..."; ', status, '.HorizontalAlignment="Center"; ', status, '.VerticalAlignment="Center"'),
      paste0('  [void]', grid, '.Children.Add(', host, '); [void]', grid, '.Children.Add(', status, ')'),
      paste0('  ', border, '.Child=', grid),
      paste0('  $controls[', .ps_quote(paste0('out_', id)), ']=', host),
      paste0('  $controls[', .ps_quote(paste0('outstatus_', id)), ']=', status),
      .ps_condition_lines(border, visibleWhen %||% out$visibleWhen),
      .ps_add_child(parent, border)
    )
    return(list(lines = lines[nzchar(lines)], var = border))
  }

  if (kind == 'download') {
    button <- .ps_new_var(st, paste0('download_', safe))
    label <- out$args$label %||% 'Download'
    lines <- c(lines,
      paste0('  ', button, '=New-Object Windows.Controls.Button; ', button, '.Content=', .ps_quote(label), '; ', button, '.HorizontalAlignment="Left"; ', button, '.MinWidth=100; ', button, '.Margin="0,6,0,8"'),
      paste0('  ', button, '.Add_Click({ $meta=$downloadMeta[', .ps_quote(id), ']; $dlg=New-Object Microsoft.Win32.SaveFileDialog; if($meta -and $meta.filename){ $dlg.FileName=[string]$meta.filename }; if($meta -and $meta.filter){ $dlg.Filter=[string]$meta.filter } else { $dlg.Filter="All files (*.*)|*.*" }; if($dlg.ShowDialog() -eq $true){ Send-Event "__download__" ([pscustomobject]@{id=', .ps_quote(id), ';path=$dlg.FileName}) } })'),
      paste0('  $controls[', .ps_quote(paste0('out_', id)), ']=', button),
      .ps_condition_lines(button, visibleWhen %||% out$visibleWhen),
      .ps_add_child(parent, button)
    )
    return(list(lines = lines[nzchar(lines)], var = button))
  }

  text <- .ps_new_var(st, paste0('textout_', safe))
  lines <- c(lines,
    paste0('  ', text, '=New-Object Windows.Controls.TextBlock'),
    paste0('  ', text, '.TextWrapping="Wrap"; ', text, '.Margin="0,5,0,8"'),
    if (kind %in% c('verbatim', 'html')) paste0('  ', text, '.FontFamily="Consolas"') else '',
    paste0('  $controls[', .ps_quote(paste0('out_', id)), ']=', text),
    .ps_condition_lines(text, visibleWhen %||% out$visibleWhen),
    .ps_add_child(parent, text)
  )
  list(lines = lines[nzchar(lines)], var = text)
}

.ps_emit_text <- function(value, parent, st, type = NULL) {
  tb <- .ps_new_var(st, 'text')
  size <- switch(type %||% '', h1 = 26, h2 = 22, h3 = 19, h4 = 17, h5 = 15, h6 = 14, 13)
  weight <- if (type %in% c('h1','h2','h3','h4','h5','h6','strong','titlePanel')) 'Bold' else 'Normal'
  style <- if (identical(type, 'em')) 'Italic' else 'Normal'
  lines <- c(
    paste0('  ', tb, '=New-Object Windows.Controls.TextBlock'),
    paste0('  ', tb, '.Text=', .ps_quote(.ps_text_value(value))),
    paste0('  ', tb, '.TextWrapping="Wrap"; ', tb, '.FontSize=', size, '; ', tb, '.FontWeight="', weight, '"; ', tb, '.FontStyle="', style, '"'),
    paste0('  ', tb, '.Margin="0,', if (type %in% c('h1','h2','h3','h4','h5','h6','titlePanel')) 8 else 2, ',0,', if (type %in% c('h1','h2','h3','h4','h5','h6','titlePanel')) 8 else 4, '"'),
    .ps_add_child(parent, tb)
  )
  list(lines = lines, var = tb)
}

.ps_emit_node <- function(x, parent, st, visibleWhen = NULL) {
  if (is.null(x)) return(list(lines = character(), var = NULL))
  if (inherits(x, 'winshiny.ui_input')) return(.ps_emit_input(x, parent, st, visibleWhen))
  if (inherits(x, 'winshiny.ui_output')) return(.ps_emit_output(x, parent, st, visibleWhen))
  if (inherits(x, 'winshiny.icon')) return(.ps_emit_text(x, parent, st))
  if (!inherits(x, 'winshiny.tag')) {
    if (is.list(x) && !is.data.frame(x)) {
      lines <- unlist(lapply(x, function(z) .ps_emit_node(z, parent, st, visibleWhen)$lines), use.names = FALSE)
      return(list(lines = lines, var = parent))
    }
    return(.ps_emit_text(x, parent, st))
  }

  type <- x$type
  childVisible <- visibleWhen
  if (identical(type, 'conditionalPanel')) childVisible <- x$attribs$condition %||% visibleWhen

  if (type %in% c('titlePanel','h1','h2','h3','h4','h5','h6','p','strong','em','helpText','pre','code')) {
    text <- if (length(x$children)) paste(vapply(x$children, .ps_text_value, character(1)), collapse = if (type %in% c('pre','code')) '\n' else ' ') else ''
    result <- .ps_emit_text(text, parent, st, type)
    if (type %in% c('pre','code')) result$lines <- c(result$lines, paste0('  ', result$var, '.FontFamily="Consolas"'))
    return(result)
  }
  if (type == 'br') return(.ps_emit_text(' ', parent, st))
  if (type == 'hr') {
    sep <- .ps_new_var(st, 'separator')
    return(list(lines = c(paste0('  ', sep, '=New-Object Windows.Controls.Separator; ', sep, '.Margin="0,8,0,8"'), .ps_add_child(parent, sep)), var = sep))
  }

  if (type == 'sidebarLayout') {
    grid <- .ps_new_var(st, 'sidebargrid')
    left <- .ps_new_var(st, 'sidebar')
    main <- .ps_new_var(st, 'main')
    sidebar_width <- if (length(x$children) && inherits(x$children[[1]], 'winshiny.tag')) x$children[[1]]$attribs$width %||% 4 else 4
    main_width <- if (length(x$children) > 1 && inherits(x$children[[2]], 'winshiny.tag')) x$children[[2]]$attribs$width %||% 8 else 8
    lines <- c(
      paste0('  ', grid, '=New-Object Windows.Controls.Grid; ', grid, '.HorizontalAlignment="Stretch"'),
      paste0('  ', grid, '.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{Width="', sidebar_width, '*"})) | Out-Null'),
      paste0('  ', grid, '.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{Width="', main_width, '*"})) | Out-Null'),
      paste0('  ', left, '=New-Object Windows.Controls.StackPanel; ', left, '.Margin="0,0,12,0"'),
      paste0('  ', main, '=New-Object Windows.Controls.StackPanel; ', main, '.Margin="12,0,0,0"')
    )
    if (length(x$children)) lines <- c(lines, unlist(lapply(x$children[[1]]$children %||% list(), function(z) .ps_emit_node(z, left, st, childVisible)$lines), use.names = FALSE))
    if (length(x$children) > 1) lines <- c(lines, unlist(lapply(x$children[[2]]$children %||% list(), function(z) .ps_emit_node(z, main, st, childVisible)$lines), use.names = FALSE))
    lines <- c(lines, .ps_set_grid(main, col = 1), paste0('  [void]', grid, '.Children.Add(', left, '); [void]', grid, '.Children.Add(', main, ')'), .ps_condition_lines(grid, childVisible), .ps_add_child(parent, grid))
    return(list(lines = lines[nzchar(lines)], var = grid))
  }

  if (type %in% c('fluidRow','fixedRow','fillRow','splitLayout')) {
    grid <- .ps_new_var(st, 'rowgrid')
    children <- x$children
    lines <- c(paste0('  ', grid, '=New-Object Windows.Controls.Grid; ', grid, '.HorizontalAlignment="Stretch"; ', grid, '.Margin="0,2,0,4"'))
    widths <- x$attribs$cellWidths %||% NULL
    for (i in seq_along(children)) {
      weight <- if (!is.null(widths) && length(widths) >= i) {
        suppressWarnings(as.numeric(gsub('%', '', widths[[i]], fixed = TRUE))) %||% 1
      } else if (inherits(children[[i]], 'winshiny.tag') && identical(children[[i]]$type, 'column')) {
        children[[i]]$attribs$width %||% 1
      } else 1
      if (is.na(weight) || weight <= 0) weight <- 1
      lines <- c(lines, paste0('  ', grid, '.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{Width="', weight, '*"})) | Out-Null'))
    }
    for (i in seq_along(children)) {
      cell <- .ps_new_var(st, paste0('cell', i))
      lines <- c(lines, paste0('  ', cell, '=New-Object Windows.Controls.StackPanel; ', cell, '.Margin="6,0,6,0"'))
      child <- children[[i]]
      inner <- if (inherits(child, 'winshiny.tag') && identical(child$type, 'column')) child$children else list(child)
      lines <- c(lines, unlist(lapply(inner, function(z) .ps_emit_node(z, cell, st, childVisible)$lines), use.names = FALSE))
      lines <- c(lines, .ps_set_grid(cell, col = i - 1L), paste0('  [void]', grid, '.Children.Add(', cell, ')'))
    }
    lines <- c(lines, .ps_condition_lines(grid, childVisible), .ps_add_child(parent, grid))
    return(list(lines = lines[nzchar(lines)], var = grid))
  }

  if (type %in% c('tabsetPanel','navbarPage','navlistPanel')) {
    tabs <- .ps_new_var(st, paste0('tabs_', type))
    tab_id <- as.character(x$attribs$id %||% '')
    selected <- as.character(x$attribs$selected %||% '')
    lines <- c(
      paste0('  ', tabs, '=New-Object Windows.Controls.TabControl; ', tabs, '.HorizontalAlignment="Stretch"; ', tabs, '.VerticalAlignment="Stretch"; ', tabs, '.MinHeight=420'),
      paste0('  $responsiveTabs.Add(', tabs, ') | Out-Null'),
      if (nzchar(tab_id)) paste0('  $tabControls[', .ps_quote(tab_id), ']=', tabs) else ''
    )
    if (identical(type, 'navbarPage') && !is.null(x$attribs$title)) {
      header <- .ps_new_var(st, 'navtitle')
      lines <- c(lines, paste0('  ', header, '=New-Object Windows.Controls.TextBlock; ', header, '.Text=', .ps_quote(x$attribs$title), '; ', header, '.FontSize=22; ', header, '.FontWeight="Bold"; ', header, '.Margin="0,0,0,8"'), .ps_add_child(parent, header))
    }
    add_tab <- function(tab, menu_prefix = NULL) {
      if (!inherits(tab, 'winshiny.tag')) return(character())
      if (identical(tab$type, 'navbarMenu')) {
        menu_title <- as.character(tab$attribs$title %||% 'Menu')
        z <- character()
        for (child in tab$children) {
          z <- c(z, add_tab(child, menu_prefix = menu_title))
        }
        return(z)
      }
      if (!identical(tab$type, 'tabPanel')) return(character())
      item <- .ps_new_var(st, 'tabitem')
      scroll <- .ps_new_var(st, 'tabscroll')
      panel <- .ps_new_var(st, 'tabpanel')
      title <- as.character(tab$attribs$title %||% tab$attribs$value %||% 'Tab')
      value <- as.character(tab$attribs$value %||% title)
      shown_title <- if (is.null(menu_prefix)) title else paste(menu_prefix, title, sep = ' - ')
      z <- c(
        paste0('  ', item, '=New-Object Windows.Controls.TabItem; ', item, '.Header=', .ps_quote(shown_title), '; ', item, '.Tag=', .ps_quote(value)),
        paste0('  ', scroll, '=New-Object Windows.Controls.ScrollViewer; ', scroll, '.VerticalScrollBarVisibility="Auto"; ', scroll, '.HorizontalScrollBarVisibility="Disabled"'),
        paste0('  ', panel, '=New-Object Windows.Controls.StackPanel; ', panel, '.Margin="10"; ', panel, '.HorizontalAlignment="Stretch"'),
        unlist(lapply(tab$children, function(z) .ps_emit_node(z, panel, st, childVisible)$lines), use.names = FALSE),
        paste0('  ', scroll, '.Content=', panel, '; ', item, '.Content=', scroll),
        paste0('  [void]', tabs, '.Items.Add(', item, ')')
      )
      z
    }
    for (tab in x$children) lines <- c(lines, add_tab(tab))
    if (nzchar(selected)) lines <- c(lines, paste0('  foreach($ti in ', tabs, '.Items){ if([string]$ti.Tag -eq ', .ps_quote(selected), '){ ', tabs, '.SelectedItem=$ti; break } }'))
    selection_event <- if (nzchar(tab_id)) paste0('if($this.SelectedItem -and $this.SelectedItem.Tag){ Send-Event ', .ps_quote(tab_id), ' ([string]$this.SelectedItem.Tag) }; ') else ''
    lines <- c(lines, paste0('  ', tabs, '.Add_SelectionChanged({ ', selection_event, '$this.Dispatcher.BeginInvoke([action]{ Schedule-ResponsiveLayout }) | Out-Null })'))
    lines <- c(lines, .ps_condition_lines(tabs, childVisible), .ps_add_child(parent, tabs))
    return(list(lines = lines[nzchar(lines)], var = tabs))
  }

  if (type == 'flowLayout') {
    flow <- .ps_new_var(st, 'flow')
    lines <- c(
      paste0('  ', flow, '=New-Object Windows.Controls.WrapPanel; ', flow, '.HorizontalAlignment="Stretch"'),
      unlist(lapply(x$children, function(z) .ps_emit_node(z, flow, st, childVisible)$lines), use.names = FALSE),
      .ps_condition_lines(flow, childVisible),
      .ps_add_child(parent, flow)
    )
    return(list(lines = lines[nzchar(lines)], var = flow))
  }

  # Generic containers and panels.
  container <- .ps_new_var(st, paste0('container_', type))
  if (type == 'wellPanel') {
    inner <- .ps_new_var(st, 'wellinner')
    lines <- c(
      paste0('  ', container, '=New-Object Windows.Controls.Border; ', container, '.BorderBrush=$themeBorder; ', container, '.BorderThickness="1"; ', container, '.CornerRadius="3"; ', container, '.Padding="10"; ', container, '.Margin="0,5,0,8"'),
      paste0('  ', inner, '=New-Object Windows.Controls.StackPanel'),
      unlist(lapply(x$children, function(z) .ps_emit_node(z, inner, st, childVisible)$lines), use.names = FALSE),
      paste0('  ', container, '.Child=', inner),
      .ps_condition_lines(container, childVisible),
      .ps_add_child(parent, container)
    )
    return(list(lines = lines[nzchar(lines)], var = container))
  }

  lines <- c(
    paste0('  ', container, '=New-Object Windows.Controls.StackPanel; ', container, '.HorizontalAlignment="Stretch"'),
    if (type %in% c('fluidPage','fixedPage','basicPage','bootstrapPage','verticalLayout','tagList','inputPanel','fillPage','fillCol')) paste0('  ', container, '.Margin="', if (type %in% c('fluidPage','fixedPage','basicPage','bootstrapPage')) '12' else '0', '"') else ''
  )
  lines <- c(lines, unlist(lapply(x$children, function(z) .ps_emit_node(z, container, st, childVisible)$lines), use.names = FALSE))
  lines <- c(lines, .ps_condition_lines(container, childVisible), .ps_add_child(parent, container))
  list(lines = lines[nzchar(lines)], var = container)
}


.selectize_control_ps <- function() {
  path <- system.file(
    'powershell', 'New-SelectizeControl.ps1',
    package = 'WinShiny'
  )

  if (!nzchar(path)) {
    candidate <- file.path('inst', 'powershell', 'New-SelectizeControl.ps1')
    if (file.exists(candidate)) path <- candidate
  }

  if (!nzchar(path) || !file.exists(path)) {
    stop(
      'WinShiny could not find inst/powershell/New-SelectizeControl.ps1.',
      call. = FALSE
    )
  }

  readLines(path, warn = FALSE, encoding = 'UTF-8')
}

make_ps1 <- function(nodes, eventFile, stateFile, commandFile, readyFile, logFile) {
  st <- .ps_gen_state()
  root_panel <- '$rootPanel'
  generated <- .ps_emit_node(nodes$ui, root_panel, st)$lines
  selectize_control <- .selectize_control_ps()

  lines <- c(
    '$ErrorActionPreference="Stop"',
    'try {',
    paste0('  $logFile=', .ps_quote(normalizePath(logFile, winslash = '/', mustWork = FALSE))),
    paste0('  $eventFile=', .ps_quote(normalizePath(eventFile, winslash = '/', mustWork = FALSE))),
    paste0('  $stateFile=', .ps_quote(normalizePath(stateFile, winslash = '/', mustWork = FALSE))),
    paste0('  $commandFile=', .ps_quote(normalizePath(commandFile, winslash = '/', mustWork = FALSE))),
    paste0('  $readyFile=', .ps_quote(normalizePath(readyFile, winslash = '/', mustWork = FALSE))),
    '  $clipboardDir=Join-Path (Split-Path -Parent $eventFile) "clipboard"',
    '  [void][System.IO.Directory]::CreateDirectory($clipboardDir)',
    '  function Log($m){ try { Add-Content -LiteralPath $logFile -Value ((Get-Date).ToString("s")+" "+$m) -Encoding UTF8 } catch {} }',
    '  Log "WinShiny PowerShell/WPF host starting"',
    '  Add-Type -AssemblyName PresentationFramework',
    '  Add-Type -AssemblyName PresentationCore',
    '  Add-Type -AssemblyName WindowsBase',
    '  Add-Type -AssemblyName System.Windows.Forms',
    '  Add-Type -AssemblyName System.Data',
    '  Add-Type -AssemblyName System.Drawing',
  selectize_control,
    "  try { Add-Type -Namespace WinShiny -Name NativeMethods -MemberDefinition '[System.Runtime.InteropServices.DllImport(\"dwmapi.dll\")] public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attribute, ref int value, int size);' -ErrorAction Stop } catch { }",
    '  $controls=@{}',
    '  $inputControls=@{}',
    '  $tabControls=@{}',
    '  $inputValues=@{}',
    '  $pendingEvents=@{}',
    '  $downloadMeta=@{}',
    '  $processedCommands=@{}',
    '  $conditionalRules=New-Object System.Collections.ArrayList',
    '  $responsivePlots=New-Object System.Collections.ArrayList',
    '  $responsiveTables=New-Object System.Collections.ArrayList',
    '  $responsiveTabs=New-Object System.Collections.ArrayList',
    paste0('  $script:isDark=', if (identical(nodes$initialTheme, 'dark')) '$true' else '$false'),
    '  $themeBg=[Windows.Media.Brushes]::White',
    '  $themeFg=[Windows.Media.Brushes]::Black',
    '  $themePanel=[Windows.Media.Brushes]::WhiteSmoke',
    '  $themeBorder=[Windows.Media.Brushes]::LightGray',
    '  function Update-WinShinyDateText($picker){ try { if($null -ne $picker -and $picker.SelectedDate){ $box=$picker.Template.FindName("PART_TextBox",$picker); $fmt=[string]$picker.Tag; if($null -ne $box -and -not [string]::IsNullOrWhiteSpace($fmt)){ $box.Text=$picker.SelectedDate.Value.ToString($fmt,[System.Globalization.CultureInfo]::InvariantCulture) } } } catch { Log ("Date display format error: "+($_ | Out-String)) } }',
    '  function Initialize-WinShinyDatePicker($picker,[string]$displayFormat,[string]$cultureName,[int]$weekStart){ try { $picker.Tag=$displayFormat; $picker.SelectedDateFormat=[Windows.Controls.DatePickerFormat]::Short; try { $picker.Language=[System.Windows.Markup.XmlLanguage]::GetLanguage($cultureName) } catch {}; if($weekStart -eq 1){ $picker.FirstDayOfWeek=[System.DayOfWeek]::Monday } else { $picker.FirstDayOfWeek=[System.DayOfWeek]::Sunday }; $picker.Add_Loaded({ Update-WinShinyDateText $this }); $picker.Add_SelectedDateChanged({ Update-WinShinyDateText $this }); $picker.Add_CalendarClosed({ Update-WinShinyDateText $this }) } catch { Log ("Date picker initialization error: "+($_ | Out-String)) } }',
    '  function Test-Condition($r){ $cur=$inputValues[$r.source]; if($r.expected -is [bool]){ return ([bool]$cur) -eq $r.expected }; return ([string]$cur) -eq ([string]$r.expected) }',
    '  function Update-Visibility(){ foreach($r in $conditionalRules){ $ctl=$controls[$r.target]; if($ctl){ if(Test-Condition $r){ $ctl.Visibility="Visible" } else { $ctl.Visibility="Collapsed" } } } }',
    '  function Send-Event($id,$value){ try { if($id -notlike "__*"){ $inputValues[$id]=$value }; $key=if($id -eq "__plot_size__" -and $value.id){ $id+":"+[string]$value.id } else { $id }; $pendingEvents[$key]=[pscustomobject]@{id=$id;value=$value}; Update-Visibility } catch { Log ("Queue event error: "+($_ | Out-String)) } }',
    '  function Flush-PendingEvents(){ if($pendingEvents.Count -eq 0){ return }; foreach($key in @($pendingEvents.Keys)){ try { $o=$pendingEvents[$key]; $name=("event_"+[DateTime]::UtcNow.Ticks+"_"+[Guid]::NewGuid().ToString("N")+".json"); $final=Join-Path $eventFile $name; $temp=$final+".tmp"; Set-Content -LiteralPath $temp -Value ($o | ConvertTo-Json -Compress -Depth 20) -Encoding UTF8 -ErrorAction Stop; Move-Item -LiteralPath $temp -Destination $final -Force -ErrorAction Stop; [void]$pendingEvents.Remove($key) } catch { Log ("Event write retry: "+($_ | Out-String)); break } } }',
    '  function Get-WinShinyClipboardPayload(){',
    '    try {',
    '      $text=$null; $formats=@(); $lastError=$null',
    '      for($i=0; $i -lt 40; $i++){',
    '        try {',
    '          $data=[System.Windows.Forms.Clipboard]::GetDataObject()',
    '          if($null -ne $data){ $formats=@($data.GetFormats($true)) }',
    '          if([System.Windows.Forms.Clipboard]::ContainsText([System.Windows.Forms.TextDataFormat]::UnicodeText)){ $text=[System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::UnicodeText) }',
    '          elseif([System.Windows.Forms.Clipboard]::ContainsText([System.Windows.Forms.TextDataFormat]::Text)){ $text=[System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::Text) }',
    '          elseif($null -ne $data -and $data.GetDataPresent([System.Windows.Forms.DataFormats]::CommaSeparatedValue,$true)){ $text=[string]$data.GetData([System.Windows.Forms.DataFormats]::CommaSeparatedValue,$true) }',
    '          elseif([System.Windows.Clipboard]::ContainsText()){ $text=[System.Windows.Clipboard]::GetText() }',
    '          $lastError=$null; break',
    '        } catch { $lastError=$_.Exception; [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background); Start-Sleep -Milliseconds 50 }',
    '      }',
    '      if($null -ne $lastError){ throw $lastError }',
    '      if($null -eq $text){ $text="" }',
    '      return [pscustomobject]@{text=[string]$text;metadata=[pscustomobject]@{formats=$formats;has_html=[bool](($formats -join "|") -match "HTML");has_csv=[bool](($formats -join "|") -match "Csv|CommaSeparatedValue");has_unicode_text=[bool](($formats -join "|") -match "UnicodeText");has_excel=[bool](($formats -join "|") -match "Biff|XML Spreadsheet|EnhancedMetafile|Csv|Excel")}}',
    '    } catch { return [pscustomobject]@{text="";error=[string]$_.Exception.Message;metadata=[pscustomobject]@{formats=@();has_html=$false;has_csv=$false;has_unicode_text=$false;has_excel=$false}} }',
    '  }',
    '  function ConvertTo-WinShinyCfHtml([string]$fragment){',
    '    $start="<html><body><!--StartFragment-->"; $finish="<!--EndFragment--></body></html>"; $html=$start+$fragment+$finish; $template="Version:0.9`r`nStartHTML:{0:D10}`r`nEndHTML:{1:D10}`r`nStartFragment:{2:D10}`r`nEndFragment:{3:D10}`r`n"; $dummy=[string]::Format($template,0,0,0,0); $utf8=[System.Text.Encoding]::UTF8; $startHtml=$utf8.GetByteCount($dummy); $startFragment=$startHtml+$utf8.GetByteCount($start); $endFragment=$startFragment+$utf8.GetByteCount($fragment); $endHtml=$startHtml+$utf8.GetByteCount($html); return ([string]::Format($template,$startHtml,$endHtml,$startFragment,$endFragment)+$html)',
    '  }',
    '  function Escape-WinShinyHtml($value){ return [System.Net.WebUtility]::HtmlEncode([string]$value) }',
    '  function Copy-WinShinyTables($ids,$labels,$title,$subtitle,$notes){',
    '    try {',
    '      $text=New-Object System.Text.StringBuilder; $html=New-Object System.Text.StringBuilder; [void]$html.Append("<div style=`"font-family:Aptos,Calibri,Arial,sans-serif;font-size:10.5pt;color:#1f1f1f`">"); if(-not [string]::IsNullOrWhiteSpace([string]$title)){ [void]$html.Append("<h1 style=`"font-size:16pt;color:#1f4e79;margin:0 0 6pt 0`">"+(Escape-WinShinyHtml $title)+"</h1>"); [void]$text.AppendLine([string]$title) }; if(-not [string]::IsNullOrWhiteSpace([string]$subtitle)){ [void]$html.Append("<p>"+(Escape-WinShinyHtml $subtitle)+"</p>"); [void]$text.AppendLine([string]$subtitle) }',
    '      $copied=0; for($i=0; $i -lt @($ids).Count; $i++){ $id=[string]@($ids)[$i]; $heading=if($i -lt @($labels).Count){ [string]@($labels)[$i] } else { $id }; $ctl=$controls["out_"+$id]; if($null -eq $ctl -or $null -eq $ctl.Tag -or -not ($ctl.Tag -is [System.Data.DataTable])){ continue }; $dt=[System.Data.DataTable]$ctl.Tag; if($copied -gt 0){ [void]$text.AppendLine() }; if(-not [string]::IsNullOrWhiteSpace($heading)){ [void]$html.Append("<h2 style=`"font-size:12pt;color:#1f4e79;margin:10pt 0 4pt 0`">"+(Escape-WinShinyHtml $heading)+"</h2>"); [void]$text.AppendLine($heading) }; [void]$html.Append("<table style=`"border-collapse:collapse;margin:0 0 10pt 0`"><thead><tr>"); for($c=0;$c -lt $dt.Columns.Count;$c++){ $name=[string]$dt.Columns[$c].ColumnName; $header=if($c -lt $ctl.Columns.Count){ [string]$ctl.Columns[$c].Header } else { $name }; [void]$html.Append("<th style=`"border:1px solid #b7b7b7;background:#d9eaf7;padding:4pt 6pt;text-align:left`">"+(Escape-WinShinyHtml $header)+"</th>"); if($c -gt 0){ [void]$text.Append("`t") }; [void]$text.Append($header) }; [void]$text.AppendLine(); [void]$html.Append("</tr></thead><tbody>"); foreach($row in $dt.Rows){ [void]$html.Append("<tr>"); for($c=0;$c -lt $dt.Columns.Count;$c++){ $v=if($row.IsNull($c)){ "" } else { [string]$row[$c] }; [void]$html.Append("<td style=`"border:1px solid #b7b7b7;padding:4pt 6pt`">"+(Escape-WinShinyHtml $v)+"</td>"); if($c -gt 0){ [void]$text.Append("`t") }; [void]$text.Append($v) }; [void]$text.AppendLine(); [void]$html.Append("</tr>") }; [void]$html.Append("</tbody></table>"); $copied++ }',
    '      if($copied -eq 0){ throw "No rendered table outputs were available to copy." }; if(-not [string]::IsNullOrWhiteSpace([string]$notes)){ [void]$html.Append("<p style=`"font-size:9pt;color:#555`">"+(Escape-WinShinyHtml $notes)+"</p>"); [void]$text.AppendLine(); [void]$text.AppendLine([string]$notes) }; [void]$html.Append("</div>"); $plain=$text.ToString(); $payload=[pscustomobject]@{html=(ConvertTo-WinShinyCfHtml $html.ToString());text=$plain;csv=$plain}; Set-WinShinyClipboardTable $payload',
    '    } catch { Log ("Direct table copy error: "+($_ | Out-String)); [System.Windows.MessageBox]::Show([string]$_.Exception.Message,"Clipboard copy failed",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null }',
    '  }',
    '  function Copy-WinShinyPlot($id){ try { $ctl=$controls["out_"+[string]$id]; if($null -eq $ctl -or $null -eq $ctl.Source){ throw "The plot is not currently rendered." }; $bmp=$ctl.Source; if($bmp.CanFreeze -and -not $bmp.IsFrozen){ $bmp=$bmp.Clone(); $bmp.Freeze() }; $done=$false; $last=$null; for($i=0;$i -lt 30;$i++){ try { [System.Windows.Clipboard]::SetImage($bmp); $done=$true; break } catch { $last=$_.Exception; Start-Sleep -Milliseconds 50 } }; if(-not $done){ if($last){ throw $last }; throw "The Windows clipboard is unavailable." } } catch { Log ("Direct plot copy error: "+($_ | Out-String)); [System.Windows.MessageBox]::Show([string]$_.Exception.Message,"Clipboard copy failed",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null } }',
    '  function Set-WinShinyClipboardTable($payload){',
    '    $object=New-Object System.Windows.DataObject',
    '    if($null -ne $payload.html -and -not [string]::IsNullOrEmpty([string]$payload.html)){ $object.SetData([System.Windows.DataFormats]::Html,[string]$payload.html) }',
    '    if($null -ne $payload.text){ $object.SetData([System.Windows.DataFormats]::UnicodeText,[string]$payload.text); $object.SetData([System.Windows.DataFormats]::Text,[string]$payload.text) }',
    '    if($null -ne $payload.csv){ $object.SetData([System.Windows.DataFormats]::CommaSeparatedValue,[string]$payload.csv) }',
    '    $done=$false; $lastError=$null; for($i=0; $i -lt 30; $i++){ try { [System.Windows.Clipboard]::SetDataObject($object,$true); $done=$true; $lastError=$null; break } catch { $lastError=$_.Exception; [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background); Start-Sleep -Milliseconds 50 } }; if(-not $done){ if($lastError){ throw $lastError }; throw "The Windows clipboard is busy or unavailable." }',
    '  }',
    '  function Set-WinShinyClipboardImage([string]$path){',
    '    if(-not (Test-Path -LiteralPath $path)){ throw "Clipboard image file does not exist." }',
    '    $stream=$null; $bitmap=$null',
    '    try {',
    '      $stream=[System.IO.File]::Open($path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)',
    '      $bitmap=New-Object Windows.Media.Imaging.BitmapImage',
    '      $bitmap.BeginInit(); $bitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad; $bitmap.StreamSource=$stream; $bitmap.EndInit(); $bitmap.Freeze()',
    '    } finally { if($stream){ $stream.Dispose() } }',
    '    $done=$false; $lastError=$null; for($i=0; $i -lt 30; $i++){ try { [System.Windows.Clipboard]::SetImage($bitmap); $done=$true; $lastError=$null; break } catch { $lastError=$_.Exception; [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background); Start-Sleep -Milliseconds 50 } }; if(-not $done){ if($lastError){ throw $lastError }; throw "The Windows clipboard is busy or unavailable." }',
    '  }',
    '  function New-WinShinyTabStyle([bool]$dark){',
    '    if($dark){ $normalBg="#2D2D30"; $selectedBg="#505058"; $normalFg="#D8D8D8"; $selectedFg="#FFFFFF"; $border="#6A6A70" } else { $normalBg="#E8E8E8"; $selectedBg="#FFFFFF"; $normalFg="#202020"; $selectedFg="#000000"; $border="#B8B8B8" }',
    '    $tabXaml=@"',
'<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="{x:Type TabItem}">',
'  <Setter Property="Foreground" Value="$normalFg"/>',
'  <Setter Property="Background" Value="$normalBg"/>',
'  <Setter Property="BorderBrush" Value="$border"/>',
'  <Setter Property="Padding" Value="12,6"/>',
'  <Setter Property="Margin" Value="0,0,2,0"/>',
'  <Setter Property="Template">',
'    <Setter.Value>',
'      <ControlTemplate TargetType="{x:Type TabItem}">',
'        <Border x:Name="TabBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" Padding="{TemplateBinding Padding}">',
'          <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True" TextElement.Foreground="{TemplateBinding Foreground}"/>',
'        </Border>',
'        <ControlTemplate.Triggers>',
'          <Trigger Property="IsSelected" Value="True">',
'            <Setter Property="Background" Value="$selectedBg"/>',
'            <Setter Property="Foreground" Value="$selectedFg"/>',
'            <Setter TargetName="TabBorder" Property="BorderThickness" Value="1,1,1,0"/>',
'          </Trigger>',
'          <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.55"/></Trigger>',
'        </ControlTemplate.Triggers>',
'      </ControlTemplate>',
'    </Setter.Value>',
'  </Setter>',
'</Style>',
'"@',
    '    [Windows.Markup.XamlReader]::Parse($tabXaml)',
    '  }',
    '  function New-WinShinyComboStyle([bool]$dark){',
    '    if($dark){ $field="#323234"; $fg="#F0F0F0"; $border="#77777D"; $hover="#4A4A50"; $selected="#585864" } else { $field="#FFFFFF"; $fg="#202020"; $border="#A8A8A8"; $hover="#E7F1FF"; $selected="#CCE4FF" }',
    '    $comboXaml=@"',
'<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="{x:Type ComboBox}">',
'  <Setter Property="Foreground" Value="$fg"/>',
'  <Setter Property="Background" Value="$field"/>',
'  <Setter Property="BorderBrush" Value="$border"/>',
'  <Setter Property="BorderThickness" Value="1"/>',
'  <Setter Property="Padding" Value="8,4"/>',
'  <Setter Property="MinHeight" Value="28"/>',
'  <Setter Property="ItemContainerStyle">',
'    <Setter.Value>',
'      <Style TargetType="{x:Type ComboBoxItem}">',
'        <Setter Property="Foreground" Value="$fg"/>',
'        <Setter Property="Background" Value="$field"/>',
'        <Setter Property="Padding" Value="9,5"/>',
'        <Setter Property="Template">',
'          <Setter.Value>',
'            <ControlTemplate TargetType="{x:Type ComboBoxItem}">',
'              <Border x:Name="ItemBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">',
'                <ContentPresenter VerticalAlignment="Center" TextElement.Foreground="{TemplateBinding Foreground}"/>',
'              </Border>',
'              <ControlTemplate.Triggers>',
'                <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="ItemBorder" Property="Background" Value="$hover"/></Trigger>',
'                <Trigger Property="IsSelected" Value="True"><Setter TargetName="ItemBorder" Property="Background" Value="$selected"/></Trigger>',
'              </ControlTemplate.Triggers>',
'            </ControlTemplate>',
'          </Setter.Value>',
'        </Setter>',
'      </Style>',
'    </Setter.Value>',
'  </Setter>',
'  <Setter Property="Template">',
'    <Setter.Value>',
'      <ControlTemplate TargetType="{x:Type ComboBox}">',
'        <Grid>',
'          <ToggleButton x:Name="DropDownToggle" Focusable="False" ClickMode="Press" Background="{TemplateBinding Background}" Foreground="{TemplateBinding Foreground}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">',
'            <ToggleButton.Template>',
'              <ControlTemplate TargetType="{x:Type ToggleButton}">',
'                <Border x:Name="ToggleBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">',
'                  <ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Stretch"/>',
'                </Border>',
'                <ControlTemplate.Triggers>',
'                  <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ToggleBorder" Property="Background" Value="$hover"/></Trigger>',
'                  <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ToggleBorder" Property="Opacity" Value="0.55"/></Trigger>',
'                </ControlTemplate.Triggers>',
'              </ControlTemplate>',
'            </ToggleButton.Template>',
'            <Grid>',
'              <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="30"/></Grid.ColumnDefinitions>',
'              <ContentPresenter Grid.Column="0" Margin="8,3,4,3" HorizontalAlignment="Left" VerticalAlignment="Center" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" TextElement.Foreground="{TemplateBinding Foreground}"/>',
'              <Path Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center" Fill="{TemplateBinding Foreground}" Data="M 0 0 L 5 5 L 10 0 Z"/>',
'            </Grid>',
'          </ToggleButton>',
'          <Popup x:Name="PART_Popup" Placement="Bottom" AllowsTransparency="True" Focusable="False" IsOpen="{TemplateBinding IsDropDownOpen}" PopupAnimation="Slide">',
'            <Border Background="$field" BorderBrush="$border" BorderThickness="1" MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}" MaxHeight="{TemplateBinding MaxDropDownHeight}">',
'              <ScrollViewer CanContentScroll="True"><ItemsPresenter/></ScrollViewer>',
'            </Border>',
'          </Popup>',
'        </Grid>',
'        <ControlTemplate.Triggers><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.55"/></Trigger></ControlTemplate.Triggers>',
'      </ControlTemplate>',
'    </Setter.Value>',
'  </Setter>',
'</Style>',
'"@',
    '    [Windows.Markup.XamlReader]::Parse($comboXaml)',
    '  }',
    '  function New-WinShinyButtonStyle([bool]$dark){',
    '    if($dark){ $normalBg="#3A3A3D"; $normalFg="#F2F2F2"; $hoverBg="#4D4D54"; $hoverFg="#FFFFFF"; $pressedBg="#60606A"; $border="#707078"; $disabledFg="#9A9A9A" } else { $normalBg="#F0F0F0"; $normalFg="#202020"; $hoverBg="#DCEBFA"; $hoverFg="#101010"; $pressedBg="#BDD7F2"; $border="#A8A8A8"; $disabledFg="#777777" }',
    '    $buttonXaml=@"',
'<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="{x:Type Button}">',
'  <Setter Property="Background" Value="$normalBg"/>',
'  <Setter Property="Foreground" Value="$normalFg"/>',
'  <Setter Property="BorderBrush" Value="$border"/>',
'  <Setter Property="BorderThickness" Value="1"/>',
'  <Setter Property="Padding" Value="10,5"/>',
'  <Setter Property="HorizontalContentAlignment" Value="Center"/>',
'  <Setter Property="VerticalContentAlignment" Value="Center"/>',
'  <Setter Property="Template">',
'    <Setter.Value>',
'      <ControlTemplate TargetType="{x:Type Button}">',
'        <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="2" Padding="{TemplateBinding Padding}">',
'          <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}" TextElement.Foreground="{TemplateBinding Foreground}"/>',
'        </Border>',
'        <ControlTemplate.Triggers>',
'          <Trigger Property="IsMouseOver" Value="True">',
'            <Setter Property="Background" Value="$hoverBg"/>',
'            <Setter Property="Foreground" Value="$hoverFg"/>',
'          </Trigger>',
'          <Trigger Property="IsPressed" Value="True"><Setter Property="Background" Value="$pressedBg"/></Trigger>',
'          <Trigger Property="IsEnabled" Value="False">',
'            <Setter Property="Foreground" Value="$disabledFg"/>',
'            <Setter Property="Opacity" Value="0.70"/>',
'          </Trigger>',
'        </ControlTemplate.Triggers>',
'      </ControlTemplate>',
'    </Setter.Value>',
'  </Setter>',
'</Style>',
'"@',
    '    [Windows.Markup.XamlReader]::Parse($buttonXaml)',
    '  }',
    '  function New-WinShinyScrollBarStyle([bool]$dark){',
    '    if($dark){ $track="#242426"; $thumb="#66666B"; $hover="#85858B" } else { $track="#EFEFEF"; $thumb="#A6A6A6"; $hover="#7F7F7F" }',
    '    $scrollXaml=@"',
'<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="{x:Type ScrollBar}">',
'  <Setter Property="Background" Value="$track"/>',
'  <Setter Property="Width" Value="13"/>',
'  <Setter Property="Template">',
'    <Setter.Value>',
'      <ControlTemplate TargetType="{x:Type ScrollBar}">',
'        <Grid Background="{TemplateBinding Background}">',
'          <Track x:Name="PART_Track" IsDirectionReversed="True">',
'            <Track.DecreaseRepeatButton><RepeatButton x:Name="DecreaseButton" Command="{x:Static ScrollBar.PageUpCommand}" Background="Transparent" Opacity="0"/></Track.DecreaseRepeatButton>',
'            <Track.Thumb>',
'              <Thumb x:Name="Thumb" Margin="2" Background="$thumb">',
'                <Thumb.Template>',
'                  <ControlTemplate TargetType="{x:Type Thumb}">',
'                    <Border x:Name="ThumbBorder" Background="{TemplateBinding Background}" CornerRadius="5"/>',
'                    <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ThumbBorder" Property="Background" Value="$hover"/></Trigger></ControlTemplate.Triggers>',
'                  </ControlTemplate>',
'                </Thumb.Template>',
'              </Thumb>',
'            </Track.Thumb>',
'            <Track.IncreaseRepeatButton><RepeatButton x:Name="IncreaseButton" Command="{x:Static ScrollBar.PageDownCommand}" Background="Transparent" Opacity="0"/></Track.IncreaseRepeatButton>',
'          </Track>',
'        </Grid>',
'        <ControlTemplate.Triggers>',
'          <Trigger Property="Orientation" Value="Horizontal">',
'            <Setter Property="Width" Value="Auto"/>',
'            <Setter Property="Height" Value="13"/>',
'            <Setter TargetName="PART_Track" Property="Orientation" Value="Horizontal"/>',
'            <Setter TargetName="PART_Track" Property="IsDirectionReversed" Value="False"/>',
'            <Setter TargetName="DecreaseButton" Property="Command" Value="{x:Static ScrollBar.PageLeftCommand}"/>',
'            <Setter TargetName="IncreaseButton" Property="Command" Value="{x:Static ScrollBar.PageRightCommand}"/>',
'          </Trigger>',
'        </ControlTemplate.Triggers>',
'      </ControlTemplate>',
'    </Setter.Value>',
'  </Setter>',
'</Style>',
'"@',
    '    [Windows.Markup.XamlReader]::Parse($scrollXaml)',
    '  }',
    '  function Set-WinShinyTitleBar($window,[bool]$dark){ try { if($null -eq $window -or $null -eq ("WinShiny.NativeMethods" -as [type])){ return }; $helper=[System.Windows.Interop.WindowInteropHelper]::new($window); $hwnd=$helper.Handle; if($hwnd -eq [IntPtr]::Zero){ return }; [int]$enabled=if($dark){1}else{0}; $result=[WinShiny.NativeMethods]::DwmSetWindowAttribute($hwnd,20,[ref]$enabled,4); if($result -ne 0){ [void][WinShiny.NativeMethods]::DwmSetWindowAttribute($hwnd,19,[ref]$enabled,4) }; [int]$caption=if($dark){0x001E1E1E}else{0x00FFFFFF}; [int]$captionText=if($dark){0x00F0F0F0}else{0x00202020}; [void][WinShiny.NativeMethods]::DwmSetWindowAttribute($hwnd,35,[ref]$caption,4); [void][WinShiny.NativeMethods]::DwmSetWindowAttribute($hwnd,36,[ref]$captionText,4) } catch { Log ("Title bar theme warning: "+($_ | Out-String)) } }',
    '  function Apply-Theme($root,[bool]$dark){',
    '    if($dark){ $script:themeBg=New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromRgb(30,30,30)); $script:themeFg=[Windows.Media.Brushes]::Gainsboro; $script:themePanel=New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromRgb(45,45,48)); $script:themeField=New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromRgb(50,50,52)); $script:themeBorder=[Windows.Media.Brushes]::DimGray }',
    '    else { $script:themeBg=[Windows.Media.Brushes]::White; $script:themeFg=[Windows.Media.Brushes]::Black; $script:themePanel=[Windows.Media.Brushes]::WhiteSmoke; $script:themeField=[Windows.Media.Brushes]::White; $script:themeBorder=[Windows.Media.Brushes]::LightGray }',
    '    function Paint-Control($ctl){',
    '      if($null -eq $ctl){ return }',
    '      if($ctl -is [Windows.Window]){ $ctl.Background=$script:themeBg; $ctl.Foreground=$script:themeFg }',
    '      if($ctl -is [Windows.Controls.Panel]){ $ctl.Background=$script:themeBg }',
    '      if($ctl -is [Windows.Controls.ScrollViewer]){ $ctl.Background=$script:themeBg }',
    '      if($ctl -is [Windows.Controls.TextBlock] -or $ctl -is [Windows.Controls.Label] -or $ctl -is [Windows.Controls.CheckBox] -or $ctl -is [Windows.Controls.RadioButton]){ $ctl.Foreground=$script:themeFg }',
    '      if($ctl -is [Windows.Controls.TextBox] -or $ctl -is [Windows.Controls.PasswordBox] -or $ctl -is [Windows.Controls.ComboBox] -or $ctl -is [Windows.Controls.ListBox] -or $ctl -is [Windows.Controls.DatePicker]){ $ctl.Background=$script:themeField; $ctl.Foreground=$script:themeFg; $ctl.BorderBrush=$script:themeBorder }',
    '      if($ctl -is [Windows.Controls.ComboBox]){ $ctl.IsEditable=$false; try { $ctl.Style=(New-WinShinyComboStyle $dark) } catch { $ctl.Background=$script:themeField; $ctl.Foreground=$script:themeFg; $ctl.BorderBrush=$script:themeBorder; Log ("ComboBox theme warning: "+($_ | Out-String)) } }',
    '      if($ctl -is [Windows.Controls.Button]){ try { $ctl.Style=(New-WinShinyButtonStyle $dark) } catch { $ctl.Background=$script:themePanel; $ctl.Foreground=$script:themeFg; $ctl.BorderBrush=$script:themeBorder; Log ("Button theme warning: "+($_ | Out-String)) } }',
    '      if($ctl -is [Windows.Controls.TabControl]){ $ctl.Background=$script:themeBg; $ctl.Foreground=$script:themeFg; $ctl.BorderBrush=$script:themeBorder }',
    '      if($ctl -is [Windows.Controls.TabItem]){ $ctl.Style=(New-WinShinyTabStyle $dark); if($ctl.Content -is [Windows.DependencyObject]){ Paint-Control $ctl.Content } }',
    '      if($ctl -is [Windows.Controls.DataGrid]){ $ctl.Background=$script:themeField; $ctl.Foreground=$script:themeFg; $ctl.RowBackground=$script:themeField; $ctl.AlternatingRowBackground=$script:themePanel; $ctl.BorderBrush=$script:themeBorder; $ctl.HorizontalGridLinesBrush=$script:themeBorder; $ctl.VerticalGridLinesBrush=$script:themeBorder; $ctl.MinColumnWidth=72; $headerStyle=[Windows.Style]::new([Windows.Controls.Primitives.DataGridColumnHeader]); [void]$headerStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::ForegroundProperty,$script:themeFg)); [void]$headerStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::BackgroundProperty,$script:themePanel)); [void]$headerStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::BorderBrushProperty,$script:themeBorder)); [void]$headerStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::PaddingProperty,([Windows.Thickness]::new(4,4,4,4)))); [void]$headerStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::FontWeightProperty,[Windows.FontWeights]::SemiBold)); $ctl.ColumnHeaderStyle=$headerStyle; $cellStyle=[Windows.Style]::new([Windows.Controls.DataGridCell]); [void]$cellStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::ForegroundProperty,$script:themeFg)); [void]$cellStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::BackgroundProperty,$script:themeField)); [void]$cellStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::BorderBrushProperty,$script:themeBorder)); [void]$cellStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::PaddingProperty,([Windows.Thickness]::new(5,3,5,3)))); $ctl.CellStyle=$cellStyle }',
    '      if($ctl -is [Windows.Controls.Border]){ $ctl.BorderBrush=$script:themeBorder; $ctl.Background=$script:themeBg }',
    '      if($ctl -is [Windows.Controls.Panel]){ foreach($child in $ctl.Children){ Paint-Control $child } }',
    '      elseif($ctl -is [Windows.Controls.Border] -and $ctl.Child){ Paint-Control $ctl.Child }',
    '      elseif($ctl -is [Windows.Controls.ScrollViewer] -and $ctl.Content){ Paint-Control $ctl.Content }',
    '      elseif($ctl -is [Windows.Controls.ContentControl] -and $ctl.Content -is [Windows.DependencyObject]){ Paint-Control $ctl.Content }',
    '      elseif($ctl -is [Windows.Controls.ItemsControl]){ foreach($item in $ctl.Items){ if($item -is [Windows.DependencyObject]){ Paint-Control $item } } }',
    '      if(($ctl -is [Windows.Controls.StackPanel]) -and ([string]$ctl.Uid -eq "winshiny-selectize-inline")){ Set-WinShinySelectizeTheme -Control $ctl -DarkMode $dark }',
    '    }',
    '    if($root -is [Windows.Window]){ try { $root.Resources[[Windows.Controls.Primitives.ScrollBar]]=(New-WinShinyScrollBarStyle $dark) } catch { Log ("ScrollBar theme warning: "+($_ | Out-String)) } }',
    '    Paint-Control $root',
    '    if($root -is [Windows.Window]){ Set-WinShinyTitleBar $root $dark }',
    '  }',
    '  function Find-ScrollViewer($ctl){ try { $cur=$ctl; while($null -ne $cur){ if($cur -is [Windows.Controls.ScrollViewer]){ return $cur }; $cur=[Windows.Media.VisualTreeHelper]::GetParent($cur) } } catch {}; return $null }',
    '  function Get-BottomLayoutChrome($ctl,$sv){ $total=4.0; try { $cur=$ctl; while($null -ne $cur -and $cur -ne $sv){ if($cur -is [Windows.FrameworkElement]){ $total += [double]$cur.Margin.Bottom }; $cur=[Windows.Media.VisualTreeHelper]::GetParent($cur) } } catch {}; return [math]::Max(4.0,$total) }',
    '  function Get-RemainingViewportHeight($ctl){ try { $sv=Find-ScrollViewer $ctl; if($sv -and $sv.ViewportHeight -gt 0){ $pt=$ctl.TransformToAncestor($sv).Transform([Windows.Point]::new(0,0)); $bottom=Get-BottomLayoutChrome $ctl $sv; return [math]::Max(150,[double]$sv.ViewportHeight-[double]$pt.Y-[double]$bottom) } } catch {}; return [math]::Max(180,[double]$win.ActualHeight-250) }',
    '  function Resize-ResponsiveControls(){ try {',
    '    for($pass=0; $pass -lt 3; $pass++){',
    '      $win.UpdateLayout()',
    '      foreach($tabs in $responsiveTabs){ if($tabs.IsVisible){ $tabAvailable=Get-RemainingViewportHeight $tabs; $tabs.Height=[math]::Max(360,[double]$tabAvailable) } }',
    '      foreach($p in $responsivePlots){ if($p.Border.IsVisible){ $available=Get-RemainingViewportHeight $p.Border; $target=[math]::Max([double]$p.MinHeight,[double]$available); $cap=[math]::Max([double]$p.MinHeight,[double]$win.ActualHeight-190); $p.Border.Height=[math]::Min($target,$cap) } }',
    '      foreach($t in $responsiveTables){ if($t.Border.IsVisible){ $available=Get-RemainingViewportHeight $t.Border; $t.Border.Height=[math]::Max(220,[double]$available); $t.Grid.Height=[double]::NaN; $t.Grid.VerticalAlignment="Stretch" } }',
    '      $win.UpdateLayout()',
    '    }',
    '    foreach($t in $responsiveTables){ if($t.Border.IsVisible -and $t.Grid.Items.Count -gt 0){ $usable=[math]::Max(80,[double]$t.Grid.ActualHeight-[double]$t.Grid.ColumnHeaderHeight-2); $visible=[math]::Max(1,[math]::Min([int]$t.Grid.Items.Count,[int][math]::Floor($usable/27))); $rowHeight=[math]::Max(23,[math]::Min(31,$usable/$visible)); $t.Grid.RowHeight=$rowHeight } }',
    '    $win.UpdateLayout()',
    '  } catch { Log ("Responsive layout error: "+($_ | Out-String)) } }',
    '  function Report-ResponsivePlotSizes(){ try {',
    '    $win.UpdateLayout()',
    '    foreach($p in $responsivePlots){ if($p.Border.IsVisible){',
    '      $w=[math]::Max(200,[int][math]::Floor($p.Border.ActualWidth-2))',
    '      $h=[math]::Max(150,[int][math]::Floor($p.Border.ActualHeight-2))',
    '      if([math]::Abs($w-[int]$p.LastWidth) -ge 2 -or [math]::Abs($h-[int]$p.LastHeight) -ge 2){',
    '        $p.LastWidth=$w; $p.LastHeight=$h; $p.Image.Visibility="Collapsed"; $p.Status.Text="Redrawing plot..."; $p.Status.Visibility="Visible"',
    '        Send-Event "__plot_size__" ([pscustomobject]@{id=$p.Id;width=$w;height=$h})',
    '      }',
    '    } }',
    '    Flush-PendingEvents',
    '  } catch { Log ("Plot measurement error: "+($_ | Out-String)) } }',
    '  $plotMeasureTimer=New-Object Windows.Threading.DispatcherTimer; $plotMeasureTimer.Interval=[TimeSpan]::FromMilliseconds(35); $plotMeasureTimer.Add_Tick({ $plotMeasureTimer.Stop(); Resize-ResponsiveControls; Report-ResponsivePlotSizes })',
    '  $layoutTimer=New-Object Windows.Threading.DispatcherTimer; $layoutTimer.Interval=[TimeSpan]::FromMilliseconds(85); $layoutTimer.Add_Tick({ $layoutTimer.Stop(); Resize-ResponsiveControls; $plotMeasureTimer.Stop(); $plotMeasureTimer.Start() })',
    '  function Schedule-ResponsiveLayout(){ $plotMeasureTimer.Stop(); $layoutTimer.Stop(); $layoutTimer.Start() }',
    '  function Set-ImageSource($ctl,$status,$source){ try { if([string]::IsNullOrWhiteSpace([string]$source)){ throw "The renderer returned an empty image path." }; $src=[string]$source; if(!(Test-Path -LiteralPath $src)){ throw ("Image file does not exist: "+$src) }; $stream=[System.IO.File]::Open($src,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite); try { $decoder=[System.Windows.Media.Imaging.PngBitmapDecoder]::new($stream,[System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad); $bmp=$decoder.Frames[0]; $bmp.Freeze(); $ctl.Source=$bmp; $ctl.ToolTip=("Image "+$bmp.PixelWidth+" x "+$bmp.PixelHeight); $status.Text=""; $status.Visibility="Collapsed"; $ctl.Visibility="Visible"; $ctl.InvalidateMeasure(); $ctl.InvalidateVisual() } finally { if($stream){ $stream.Dispose() } } } catch { $ctl.Source=$null; $ctl.Visibility="Collapsed"; $status.Text=("Plot error: "+[string]$_.Exception.Message); $status.Visibility="Visible"; Log ("Image load error: "+($_ | Out-String)) } }',
    '  function Set-TableData($ctl,$status,$value){ try { $ctl.ItemsSource=$null; $ctl.Tag=$null; $ctl.Columns.Clear(); $columns=@(); $rows=@(); if($null -ne $value){ $rawColumns=$value.columns; if($null -ne $rawColumns){ if(($rawColumns -is [Management.Automation.PSCustomObject]) -and ($null -eq $rawColumns.PSObject.Properties["key"])){ $columns=@($rawColumns.PSObject.Properties | ForEach-Object { $_.Value }) } else { $columns=@($rawColumns) } }; $rows=@($value.rows | Where-Object { $null -ne $_ }) }; $validColumns=New-Object System.Collections.ArrayList; $dt=[System.Data.DataTable]::new("WinShinyTable"); foreach($spec in $columns){ if($null -eq $spec){ continue }; $key=[string]$spec.key; if([string]::IsNullOrWhiteSpace($key)){ continue }; $label=[string]$spec.label; if([string]::IsNullOrWhiteSpace($label)){ $label=$key }; [void]$dt.Columns.Add([System.Data.DataColumn]::new($key,[object])); [void]$validColumns.Add($spec); $column=[Windows.Controls.DataGridTextColumn]::new(); $column.Header=$label; $column.MinWidth=72; $binding=[Windows.Data.Binding]::new("["+$key+"]"); $binding.Mode=[Windows.Data.BindingMode]::OneWay; $column.Binding=$binding; $column.Width=[Windows.Controls.DataGridLength]::new(1,[Windows.Controls.DataGridLengthUnitType]::Star); [void]$ctl.Columns.Add($column) }; foreach($row in $rows){ if($null -eq $row){ continue }; $dr=$dt.NewRow(); $hasValue=$false; for($j=0; $j -lt $validColumns.Count; $j++){ $spec=$validColumns[$j]; $key=[string]$spec.key; $prop=$row.PSObject.Properties[$key]; if($null -ne $prop -and $null -ne $prop.Value){ $dr[$j]=$prop.Value; if(-not [string]::IsNullOrWhiteSpace([string]$prop.Value)){ $hasValue=$true } } else { $dr[$j]=[DBNull]::Value } }; if($hasValue){ [void]$dt.Rows.Add($dr) } }; $view=$dt.DefaultView; $view.AllowNew=$false; $view.AllowDelete=$false; $view.AllowEdit=$false; try { $view.NewItemPlaceholderPosition=[System.ComponentModel.NewItemPlaceholderPosition]::None } catch {}; $ctl.Tag=$dt; $ctl.ItemsSource=$view; $ctl.CanUserAddRows=$false; $fill=$false; try { $fill=[bool]$ctl.WinShinyFill } catch {}; $ctl.Height=[double]::NaN; if($fill){ $ctl.MaxHeight=[double]::PositiveInfinity; $ctl.VerticalAlignment="Stretch" } else { $ctl.MaxHeight=500; $ctl.VerticalAlignment="Top" }; $ctl.UpdateLayout(); $ctl.Visibility="Visible"; $status.Visibility="Collapsed"; Apply-Theme $ctl $script:isDark; if($fill){ Schedule-ResponsiveLayout } } catch { $ctl.ItemsSource=$null; $ctl.Tag=$null; $ctl.Visibility="Collapsed"; $status.Text=("Table error: "+[string]$_.Exception.Message); $status.Visibility="Visible"; Log ("Table binding error: "+($_ | Out-String)) } }',
    '  function Get-ChoiceValues($choices){ if($null -eq $choices){ return @() }; if($choices -is [System.Array]){ return @($choices) }; if($choices -is [System.Management.Automation.PSCustomObject]){ return @($choices.PSObject.Properties.Value) }; return @($choices) }',
    '  function Get-ChoiceEntries($choices){ if($null -eq $choices){ return @() }; $entries=@(); if($choices -is [System.Management.Automation.PSCustomObject]){ foreach($property in $choices.PSObject.Properties){ $label=if([string]::IsNullOrWhiteSpace([string]$property.Name)){[string]$property.Value}else{[string]$property.Name}; $entries += [pscustomobject]@{Display=$label;Value=$property.Value} }; return $entries }; foreach($choice in @($choices)){ $entries += [pscustomobject]@{Display=[string]$choice;Value=$choice} }; return $entries }',
    '  function New-DynamicNode($spec){',
    '    if($null -eq $spec){ return (New-Object Windows.Controls.StackPanel) }',
    '    $nodeType=[string]$spec.nodeType',
    '    if($nodeType -eq "text"){ $tb=New-Object Windows.Controls.TextBlock; $tb.Text=[string]$spec.value; $tb.TextWrapping="Wrap"; $tb.Margin="0,2,0,4"; return $tb }',
    '    if($nodeType -eq "input"){',
    '      $wrap=New-Object Windows.Controls.StackPanel; $wrap.Margin="0,3,0,7"; $id=[string]$spec.id; $kind=[string]$spec.kind; $label=[string]$spec.label',
    '      if($kind -notin @("checkbox","theme","button","link","clipboard")){ $lbl=New-Object Windows.Controls.TextBlock; $lbl.Text=$label; $lbl.FontWeight="SemiBold"; [void]$wrap.Children.Add($lbl); $controls["label_"+$id]=$lbl }',
    '      if($kind -in @("text","textarea","numeric")){ $ctl=New-Object Windows.Controls.TextBox; $ctl.Text=[string]$spec.value; if($kind -eq "textarea"){ $ctl.AcceptsReturn=$true; $ctl.TextWrapping="Wrap"; $ctl.MinHeight=80 }; $handler={ if($kind -eq "numeric"){ $n=0.0; if([double]::TryParse($this.Text,[ref]$n)){ Send-Event $id $n } } else { Send-Event $id $this.Text } }.GetNewClosure(); $ctl.Add_TextChanged($handler) }',
    '      elseif($kind -in @("checkbox","theme")){ $ctl=New-Object Windows.Controls.CheckBox; $ctl.Content=$label; $ctl.IsChecked=[bool]$spec.value; $handler={ if($kind -eq "theme"){ $script:isDark=[bool]$this.IsChecked; Apply-Theme $win $script:isDark }; Send-Event $id ([bool]$this.IsChecked); Flush-PendingEvents }.GetNewClosure(); $ctl.Add_Click($handler) }',
    '      elseif($kind -in @("select","selectize","varselectize")){ $multiple=[bool]$spec.args.multiple; $useSelectize=($kind -in @("selectize","varselectize")) -or [bool]$spec.args.selectize; $choiceEntries=@(Get-ChoiceEntries $spec.args.choices); $choices=@($choiceEntries | ForEach-Object { $_.Value }); $selected=@($spec.value); if($useSelectize){ $prompt=if($multiple){"Search and select one or more items..."}else{"Search and select an item..."}; try { $candidate=[string]$spec.args.options.placeholder; if(-not [string]::IsNullOrWhiteSpace($candidate)){ $prompt=$candidate } } catch {}; $ctl=New-WinShinySelectizeControl -Items ([object[]]$choiceEntries) -SelectedValues ([object[]]$selected) -Multiple $multiple -Prompt $prompt -InputId $id -DarkMode $script:isDark -DisplayProperty "Display" -ValueProperty "Value" } elseif($multiple){ $ctl=New-Object Windows.Controls.ListBox; $ctl.SelectionMode="Multiple"; $visible=6; if($null -ne $spec.args.size){ try { $visible=[math]::Max(1,[int]$spec.args.size) } catch {} }; $ctl.MinHeight=[math]::Max(72,26*$visible); $ctl.MaxHeight=$ctl.MinHeight; foreach($choice in $choices){ [void]$ctl.Items.Add([string]$choice) }; foreach($v in $selected){ if($ctl.Items.Contains([string]$v)){ [void]$ctl.SelectedItems.Add([string]$v) } }; $handler={ $vals=[string[]]@($this.SelectedItems | ForEach-Object { [string]$_ }); Send-Event $id $vals; Flush-PendingEvents }.GetNewClosure(); $ctl.Add_SelectionChanged($handler) } else { $ctl=New-Object Windows.Controls.ComboBox; $ctl.IsEditable=$false; foreach($choice in $choices){ [void]$ctl.Items.Add([string]$choice) }; if($selected.Count -gt 0){ $ctl.SelectedItem=[string]$selected[0] }; $handler={ if($this.SelectedItem){ Send-Event $id ([string]$this.SelectedItem); Flush-PendingEvents } }.GetNewClosure(); $ctl.Add_SelectionChanged($handler) } }',
    '      elseif($kind -eq "slider"){ $ctl=New-Object Windows.Controls.Slider; $ctl.Minimum=[double]$spec.args.min; $ctl.Maximum=[double]$spec.args.max; $ctl.Value=[double]$spec.value; $ctl.TickFrequency=[double]$spec.args.step; $ctl.SmallChange=[double]$spec.args.step; $ctl.IsSnapToTickEnabled=$true; $ctl.TickPlacement="BottomRight"; $handler={ Send-Event $id ([double]$this.Value) }.GetNewClosure(); $ctl.Add_ValueChanged($handler) }',
    '      elseif($kind -eq "clipboard"){ $ctl=New-Object Windows.Controls.Button; $ctl.Content=$label; $handler={ try { Log ("Clipboard import clicked: "+[string]$id); $text=$null; $last=$null; for($attempt=0;$attempt -lt 30;$attempt++){ try { if([System.Windows.Forms.Clipboard]::ContainsText([System.Windows.Forms.TextDataFormat]::UnicodeText)){ $text=[System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::UnicodeText) } elseif([System.Windows.Forms.Clipboard]::ContainsText()){ $text=[System.Windows.Forms.Clipboard]::GetText() } elseif([System.Windows.Clipboard]::ContainsText()){ $text=[System.Windows.Clipboard]::GetText() }; $last=$null; break } catch { $last=$_.Exception; Start-Sleep -Milliseconds 50 } }; if($null -ne $last){ throw $last }; if([string]::IsNullOrWhiteSpace([string]$text)){ throw "The Windows clipboard does not contain text." }; $safeId=([regex]::Replace([string]$id,"[^A-Za-z0-9_.-]","_")); $name=("clipboard_"+$safeId+"_"+[DateTime]::UtcNow.Ticks+"_"+[Guid]::NewGuid().ToString("N")+".txt"); $final=Join-Path $clipboardDir $name; $temp=$final+".tmp"; $utf8=New-Object System.Text.UTF8Encoding($false); Log ("Clipboard text characters: "+([string]$text).Length); [System.IO.File]::WriteAllText($temp,[string]$text,$utf8); Move-Item -LiteralPath $temp -Destination $final -Force; Log ("Clipboard transfer file: "+$final); Send-Event $id ([string]$final); Flush-PendingEvents; Log ("Clipboard import event flushed: "+[string]$id) } catch { Log ("Clipboard import error: "+($_ | Out-String)); Send-Event $id ("__WINSHINY_CLIPBOARD_ERROR__"+[string]$_.Exception.Message); Flush-PendingEvents } }.GetNewClosure(); $ctl.Add_Click($handler) }',
    '      elseif($kind -in @("button","link")){ $ctl=New-Object Windows.Controls.Button; $ctl.Content=$label; $script:dynamicButtonValues[$id]=0; $handler={ $script:dynamicButtonValues[$id]++; Send-Event $id $script:dynamicButtonValues[$id]; Flush-PendingEvents }.GetNewClosure(); $ctl.Add_Click($handler) }',
    '      else { $ctl=New-Object Windows.Controls.TextBlock; $ctl.Text=("Unsupported dynamic input: "+$kind) }',
    '      $controls[$id]=$ctl; $inputControls[$id]=$ctl; [void]$wrap.Children.Add($ctl); return $wrap',
    '    }',
    '    if($nodeType -eq "output"){ $id=[string]$spec.id; $kind=[string]$spec.kind; if($kind -in @("table","datatable")){ $ctl=New-Object Windows.Controls.DataGrid; $ctl.IsReadOnly=$true; $ctl.AutoGenerateColumns=$false; $ctl.CanUserAddRows=$false; $ctl.CanUserDeleteRows=$false; $ctl.HeadersVisibility="Column"; $ctl.RowHeaderWidth=0; $ctl.RowDetailsVisibilityMode="Collapsed"; $ctl.GridLinesVisibility="All"; $ctl.MinColumnWidth=72; $ctl.MinHeight=0; $ctl.MaxHeight=500; $ctl.ColumnHeaderHeight=30; $ctl.RowHeight=27; $ctl.HorizontalScrollBarVisibility="Auto"; $ctl.VerticalAlignment="Top" } else { $ctl=New-Object Windows.Controls.TextBlock; $ctl.TextWrapping="Wrap" }; $controls["out_"+$id]=$ctl; return $ctl }',
    '    $panel=New-Object Windows.Controls.StackPanel; $panel.HorizontalAlignment="Stretch"',
    '    if($spec.children){ foreach($childSpec in @($spec.children)){ [void]$panel.Children.Add((New-DynamicNode $childSpec)) } }',
    '    return $panel',
    '  }',
    '  $script:dynamicButtonValues=@{}',
    '  function Apply-InputMessage($id,$message){',
    '    $ctl=$inputControls[$id]; if(!$ctl){ return }',
    '    $labelCtl=$controls["label_"+$id]; if($labelCtl -and $null -ne $message.label){ $labelCtl.Text=[string]$message.label }',
    '    if(($ctl -is [Windows.Controls.StackPanel]) -and ([string]$ctl.Uid -eq "winshiny-selectize-inline")){ $choicesProperty=$message.PSObject.Properties["choices"]; if($null -ne $choicesProperty){ Set-WinShinySelectizeItems -Control $ctl -Items ([object[]]@(Get-ChoiceEntries $choicesProperty.Value)) -DisplayProperty "Display" -ValueProperty "Value" }; $valueProperty=$message.PSObject.Properties["value"]; if($null -ne $valueProperty){ Set-WinShinySelectizeSelectedValues -Control $ctl -Values ([object[]]@($valueProperty.Value)) } }',
    '    elseif($ctl -is [Windows.Controls.TextBox]){ if($null -ne $message.value){ $ctl.Text=[string]$message.value } }',
    '    elseif($ctl -is [Windows.Controls.CheckBox]){ if($null -ne $message.value){ $ctl.IsChecked=[bool]$message.value } }',
    '    elseif($ctl -is [Windows.Controls.ComboBox]){ if($null -ne $message.choices){ $ctl.Items.Clear(); foreach($v in @(Get-ChoiceValues $message.choices)){ [void]$ctl.Items.Add([string]$v) } }; if($null -ne $message.value){ $values=@($message.value); if($values.Count -gt 0){ $ctl.SelectedItem=[string]$values[0] } else { $ctl.SelectedIndex=-1 } } }',
    '    elseif($ctl -is [Windows.Controls.ListBox]){ if($null -ne $message.choices){ $ctl.Items.Clear(); foreach($v in @(Get-ChoiceValues $message.choices)){ [void]$ctl.Items.Add([string]$v) } }; if($null -ne $message.value){ $selected=@($message.value); $ctl.SelectedItems.Clear(); foreach($v in $selected){ if($ctl.Items.Contains([string]$v)){ [void]$ctl.SelectedItems.Add([string]$v) } } } }',
    '    elseif(($ctl -is [Windows.Controls.Panel]) -and ([string]$ctl.Tag -eq "winshiny-checkboxgroup")){ $selected=@($message.value); if($null -ne $message.choices){ $ctl.Children.Clear(); foreach($v in @(Get-ChoiceValues $message.choices)){ $cb=New-Object Windows.Controls.CheckBox; $cb.Content=[string]$v; $cb.Tag=[string]$v; $cb.Margin="0,2,12,2"; $handler={ $vals=@(); foreach($child in $ctl.Children){ if($child.IsChecked){ $vals += [string]$child.Tag } }; Send-Event $id $vals; Flush-PendingEvents }.GetNewClosure(); $cb.Add_Click($handler); [void]$ctl.Children.Add($cb) } }; foreach($child in $ctl.Children){ $child.IsChecked=($selected -contains [string]$child.Tag) }; Apply-Theme $ctl $script:isDark }',
    '    elseif($ctl -is [Windows.Controls.Slider]){ if($null -ne $message.min){ $ctl.Minimum=[double]$message.min }; if($null -ne $message.max){ $ctl.Maximum=[double]$message.max }; if($null -ne $message.step){ $ctl.TickFrequency=[double]$message.step; $ctl.SmallChange=[double]$message.step }; if($null -ne $message.value){ $ctl.Value=[double]$message.value } }',
    '    elseif($ctl -is [Windows.Controls.DatePicker]){ if($null -ne $message.value){ $ctl.SelectedDate=[datetime]$message.value } }',
    '    elseif($ctl -is [Windows.Controls.Button]){ if($null -ne $message.label){ $ctl.Content=[string]$message.label }; if($null -ne $message.disabled){ $ctl.IsEnabled=-not [bool]$message.disabled } }',
    '  }',
    '  function Apply-Command($cmd){',
    '    $type=[string]$cmd.type; $p=$cmd.payload',
    '    if($type -eq "input"){ Apply-InputMessage ([string]$p.id) $p.message }',
    '    elseif($type -eq "selectTab"){ $tabs=$tabControls[[string]$p.id]; if($tabs){ foreach($ti in $tabs.Items){ if([string]$ti.Tag -eq [string]$p.selected){ $tabs.SelectedItem=$ti; break } } } }',
    '    elseif($type -eq "clipboardTable"){ try { Set-WinShinyClipboardTable $p; Send-Event "__clipboard_result__" ([pscustomobject]@{kind="table";ok=$true;message="Model tables copied to the Windows clipboard."}); Flush-PendingEvents } catch { $m=[string]$_.Exception.Message; Log ("Clipboard table error: "+($_ | Out-String)); Send-Event "__clipboard_result__" ([pscustomobject]@{kind="table";ok=$false;message=$m}); Flush-PendingEvents } }',
    '    elseif($type -eq "clipboardImage"){ try { Set-WinShinyClipboardImage ([string]$p.path); Send-Event "__clipboard_result__" ([pscustomobject]@{kind="image";ok=$true;message="Diagnostic plot copied to the Windows clipboard."}); Flush-PendingEvents } catch { $m=[string]$_.Exception.Message; Log ("Clipboard image error: "+($_ | Out-String)); Send-Event "__clipboard_result__" ([pscustomobject]@{kind="image";ok=$false;message=$m}); Flush-PendingEvents } }',
    '    elseif($type -eq "notification"){ [System.Windows.MessageBox]::Show([string]$p.text,"WinShiny",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null }',
    '    elseif($type -eq "showModal"){ $dialog=New-Object Windows.Window; $dialog.Owner=$win; $dialog.Title=[string]$p.title; $dialog.Width=500; $dialog.Height=350; $dialog.WindowStartupLocation="CenterOwner"; $dialog.Content=(New-DynamicNode $p.body); $script:activeModal=$dialog; $dialog.ShowDialog() | Out-Null }',
    '    elseif($type -eq "removeModal"){ if($script:activeModal){ $script:activeModal.Close(); $script:activeModal=$null } }',
    '    elseif($type -eq "close"){ $win.Close() }',
    '  }',
    '  function Get-OutputFingerprint($value){ try { return ($value | ConvertTo-Json -Depth 100 -Compress) } catch { return [string]$value } }',
    '  function Apply-State($s){',
    '    foreach($p in $s.PSObject.Properties){ if([string]$p.Value.kind -eq "ui"){ $name=[string]$p.Name; $fingerprint=Get-OutputFingerprint $p.Value; $cacheKey=("ui:"+$name); if($script:lastOutputState.ContainsKey($cacheKey) -and [string]$script:lastOutputState[$cacheKey] -ceq [string]$fingerprint){ continue }; $script:lastOutputState[$cacheKey]=$fingerprint; $ctl=$controls["out_"+$name]; $status=$controls["outstatus_"+$name]; if($ctl){ $ctl.Content=(New-DynamicNode $p.Value.value); if($status){ $status.Visibility="Collapsed" }; Apply-Theme $ctl $script:isDark } } }',
    '    foreach($p in $s.PSObject.Properties){',
    '      $kind=[string]$p.Value.kind; $value=$p.Value.value; $ctl=$controls["out_"+$p.Name]; $status=$controls["outstatus_"+$p.Name]',
    '      if($kind -eq "command"){ $cmdId=[string]$value.id; if(-not [string]::IsNullOrWhiteSpace($cmdId) -and -not $processedCommands.ContainsKey($cmdId)){ $processedCommands[$cmdId]=$true; Apply-Command ([pscustomobject]@{type=[string]$value.type;payload=$value.payload}) }; continue }',
    '      if($kind -eq "download"){ $downloadMeta[$p.Name]=$value; continue }',
    '      if(!$ctl -or $kind -eq "ui"){ continue }',
    '      if($kind -in @("plot","image")){ Set-ImageSource $ctl $status $value }',
    '      elseif($kind -in @("table","datatable")){ Set-TableData $ctl $status $value }',
    '      elseif($kind -eq "error"){ if($status){ if($ctl -is [Windows.Controls.Image]){ $ctl.Source=$null }; $ctl.Visibility="Collapsed"; $status.Text=("R error: "+[string]$value); $status.Visibility="Visible" } elseif($ctl -is [Windows.Controls.TextBlock]){ $ctl.Text=("Error: "+[string]$value) } }',
    '      elseif($ctl -is [Windows.Controls.TextBlock]){ $ctl.Text=[string]$value }',
    '    }',
    '  }',
    '  $win=New-Object Windows.Window',
    paste0('  $win.Title=', .ps_quote(nodes$title %||% 'WinShiny')),
    '  $win.Width=1000; $win.Height=760; $win.MinWidth=640; $win.MinHeight=480; $win.WindowStartupLocation="CenterScreen"',
    '  $scroll=New-Object Windows.Controls.ScrollViewer; $scroll.VerticalScrollBarVisibility="Auto"; $scroll.HorizontalScrollBarVisibility="Disabled"',
    '  $rootPanel=New-Object Windows.Controls.StackPanel; $rootPanel.Margin="10"; $rootPanel.HorizontalAlignment="Stretch"',
    '  $scroll.Content=$rootPanel; $win.Content=$scroll',
    generated,
    '  $eventTimer=New-Object Windows.Threading.DispatcherTimer; $eventTimer.Interval=[TimeSpan]::FromMilliseconds(90)',
    '  $eventTimer.Add_Tick({ Flush-PendingEvents }); $eventTimer.Start()',
    '  $script:lastState=""',
    '  $script:lastOutputState=@{}',
    '  $stateTimer=New-Object Windows.Threading.DispatcherTimer; $stateTimer.Interval=[TimeSpan]::FromMilliseconds(80)',
    '  $stateTimer.Add_Tick({ try { if(Test-Path -LiteralPath $stateFile){ $txt=Get-Content -LiteralPath $stateFile -Raw -ErrorAction Stop; if($txt -and $txt -ne $script:lastState){ $s=$txt | ConvertFrom-Json -ErrorAction Stop; $script:lastState=$txt; Apply-State $s } } } catch { Log ("State update error: "+($_ | Out-String)) } }); $stateTimer.Start()',
    '  $commandTimer=New-Object Windows.Threading.DispatcherTimer; $commandTimer.Interval=[TimeSpan]::FromMilliseconds(180)',
    '  $commandTimer.Add_Tick({ try { if(Test-Path -LiteralPath $commandFile){ $files=@(Get-ChildItem -LiteralPath $commandFile -Filter "command_*.json" -File -ErrorAction SilentlyContinue | Sort-Object Name); foreach($f in $files){ try { $line=Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop; if($line){ Apply-Command ($line | ConvertFrom-Json -ErrorAction Stop) }; Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue } catch { Log ("Command file error: "+($_ | Out-String)) } } } } catch { Log ("Command error: "+($_ | Out-String)) } }); $commandTimer.Start()',
    '  $win.Add_SizeChanged({ Schedule-ResponsiveLayout })',
    '  $win.Add_SourceInitialized({ Set-WinShinyTitleBar $win $script:isDark })',
    '  Update-Visibility',
    '  Apply-Theme $win $script:isDark',
    '  $win.Add_ContentRendered({ try { Resize-ResponsiveControls; $plotMeasureTimer.Stop(); $plotMeasureTimer.Start(); Set-Content -LiteralPath $readyFile -Value "ready" -Encoding UTF8; Log "Window content rendered" } catch { Log ("ContentRendered error: "+($_ | Out-String)) } })',
    '  $win.Add_Closed({ Send-Event "__closed__" $true; Flush-PendingEvents; Log "Window closed" })',
    '  Log "Showing dialog"',
    '  [void]$win.ShowDialog()',
    '} catch {',
    '  try { Add-Content -LiteralPath $logFile -Value ((Get-Date).ToString("s")+" ERROR "+($_ | Out-String)) -Encoding UTF8 } catch {}',
    '  try { Set-Content -LiteralPath $readyFile -Value "error" -Encoding UTF8 } catch {}',
    '  exit 1',
    '}'
  )
  paste(lines[nzchar(lines)], collapse = '\n')
}

.parse_event_line <- function(s) {
  s <- paste(as.character(s), collapse = '')
  z <- jsonlite::fromJSON(s, simplifyVector = FALSE)
  id <- as.character(z$id)
  val <- z$value
  if (!startsWith(id, '__') && is.list(val) && !is.data.frame(val) && is.null(names(val))) {
    val <- unlist(val, recursive = TRUE, use.names = FALSE)
  }
  list(id = id, value = val)
}


# PowerShell writes one completed JSON file per event. Reading individual files
# avoids Windows sharing violations and lets rapid slider/resize events be
# coalesced safely on the PowerShell side.
.read_events <- function(path, pos = 0) {
  if (!dir.exists(path)) return(list(events = list(), pos = 0))
  files <- sort(list.files(
    path,
    pattern = '^(event|clipboard)_.*\\.json$',
    full.names = TRUE
  ))
  if (!length(files)) return(list(events = list(), pos = 0))

  events <- list()
  for (file in files) {
    parsed <- tryCatch({
      text <- paste(base::readLines(file, warn = FALSE, encoding = 'UTF-8'), collapse = '')
      text <- base::sub('^\ufeff', '', text)
      if (!nzchar(text)) NULL else .parse_event_line(text)
    }, error = function(e) NULL)
    if (!is.null(parsed)) {
      removed <- identical(suppressWarnings(unlink(file)), 0L)
      if (removed) events[[length(events) + 1L]] <- parsed
    }
  }
  list(events = events, pos = 0)
}


.download_filter <- function(filename, contentType = NA_character_) {
  ext <- tolower(tools::file_ext(filename %||% ''))
  if (ext == 'csv' || identical(contentType, 'text/csv')) return('CSV files (*.csv)|*.csv|All files (*.*)|*.*')
  if (ext == 'docx' || identical(contentType, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')) return('Word documents (*.docx)|*.docx|All files (*.*)|*.*')
  if (ext %in% c('png','jpg','jpeg','bmp','gif')) return('Image files|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files (*.*)|*.*')
  if (ext %in% c('rds','rdata')) return('R data files|*.rds;*.RData|All files (*.*)|*.*')
  if (ext %in% c('txt','log')) return('Text files (*.txt)|*.txt|All files (*.*)|*.*')
  'All files (*.*)|*.*'
}

runApp <- function(appDir = getwd(), port = getOption('shiny.port'),
                   launch.browser = getOption('shiny.launch.browser', interactive()),
                   host = getOption('shiny.host','127.0.0.1'), workerId = '',
                   quiet = FALSE, display.mode = c('auto','normal','showcase'),
                   test.mode = getOption('shiny.testmode', FALSE), app = NULL,
                   wait = TRUE, startupTimeout = 8, ...) {
  app <- app %||% if (inherits(appDir, 'winshiny.app')) appDir else stop(
    'Pass a WinShiny app object from shinyApp(ui, server).', call. = FALSE
  )
  .reset_reactive_graph()
  if (is.function(app$onStart)) app$onStart()
  nodes <- collect_nodes(app$ui)
  clipboardIds <- vapply(
    nodes$inputs,
    function(x) if (identical(x$kind, 'clipboard')) as.character(x$id) else '',
    character(1)
  )
  clipboardIds <- clipboardIds[nzchar(clipboardIds)]

  input <- reactiveValues()
  for (inp in nodes$inputs) input[[inp$id]] <- inp$value
  for (id in names(nodes$navValues)) input[[id]] <- nodes$navValues[[id]]

  tmp <- tempfile('winshiny_')
  dir.create(tmp)
  eventFile <- file.path(tmp, 'events')
  stateFile <- file.path(tmp, 'state.json')
  commandFile <- file.path(tmp, 'commands')
  ps1 <- file.path(tmp, 'app.ps1')
  readyFile <- file.path(tmp, 'ready.txt')
  logFile <- file.path(tmp, 'powershell.log')
  dir.create(eventFile, recursive = TRUE)
  dir.create(commandFile, recursive = TRUE)

  state <- new.env(parent = emptyenv())
  downloads <- new.env(parent = emptyenv())
  plotFiles <- new.env(parent = emptyenv())
  plotSizes <- reactiveValues()
  themeState <- reactiveVal(nodes$initialTheme)
  plotDefaults <- list()
  commandCounter <- 0L
  for (out in nodes$outputs) {
    if (out$kind %in% c('plot','image')) {
      plotDefaults[[out$id]] <- list(
        width = .px(out$args$width, 800),
        height = .px(out$args$height, 400)
      )
      plotSizes[[out$id]] <- plotDefaults[[out$id]]
    }
  }

  flushCallbacks <- list()
  endedCallbacks <- list()
  session <- new.env(parent = emptyenv())
  .winshiny_runtime$session <- session
  session$input <- input
  session$userData <- new.env(parent = emptyenv())
  session$token <- paste(sample(c(letters, LETTERS, 0:9), 24, TRUE), collapse = '')
  session$clientData <- reactiveValues()
  session$currentTheme <- nodes$initialTheme
  session$getTheme <- function() themeState()
  session$returnValue <- NULL
  session$winshinyFiles <- list(
    dir = tmp, script = ps1, log = logFile, events = eventFile,
    state = stateFile, commands = commandFile, ready = readyFile
  )
  session$getPlotSize <- function(id) {
    size <- plotSizes[[id]]
    size %||% plotDefaults[[id]] %||% list(width = 800, height = 500)
  }
  session$registerUiDefaults <- function(spec) {
    defaults <- .ui_input_defaults(spec)
    env <- .rv_env(input)
    for (id in names(defaults)) {
      if (!exists(id, env, inherits = FALSE)) input[[id]] <- defaults[[id]]
    }
    invisible(NULL)
  }
  session$sendOutput <- function(id, value, kind = 'text') {
    if (kind %in% c('table', 'datatable')) value <- .table_payload(value)
    if (identical(kind, 'plot') && is.character(value) && length(value) == 1L) {
      old <- if (exists(id, plotFiles, inherits = FALSE)) get(id, plotFiles, inherits = FALSE) else NULL
      assign(id, value, envir = plotFiles)
      if (!is.null(old) && !identical(old, value) && file.exists(old)) try(unlink(old), silent = TRUE)
    }
    assign(id, list(value = value, kind = kind), envir = state)
    .write_json_state(stateFile, state)
  }
  session$registerDownload <- function(id, handler) {
    assign(id, handler, envir = downloads)
    ctx <- .ctx('output')
    ctx$run <- function() {
      suggested <- tryCatch(
        if (is.function(handler$filename)) handler$filename() else handler$filename,
        error = function(e) paste0(id, '.dat')
      )
      session$sendOutput(id, list(
        filename = as.character(suggested %||% paste0(id, '.dat')),
        filter = .download_filter(suggested, handler$contentType)
      ), 'download')
    }
    .schedule(ctx)
    invisible(NULL)
  }
  session$sendCommand <- function(type, payload = list()) {
    commandCounter <<- commandCounter + 1L
    commandId <- paste0(
      Sys.getpid(), '-', commandCounter, '-',
      paste(sample(c(letters, 0:9), 10L, replace = TRUE), collapse = '')
    )
    .append_json_command(
      commandFile,
      as.character(type)[1L],
      payload
    )
    invisible(commandId)
  }
  session$sendInputMessage <- function(inputId, message) {
    session$sendCommand('input', list(id = inputId, message = message))
  }
  session$onFlush <- function(fun, once = TRUE) {
    flushCallbacks[[length(flushCallbacks) + 1L]] <<- list(fun = fun, once = once, phase = 'before')
    invisible(NULL)
  }
  session$onFlushed <- function(fun, once = TRUE) {
    flushCallbacks[[length(flushCallbacks) + 1L]] <<- list(fun = fun, once = once, phase = 'after')
    invisible(NULL)
  }
  session$onSessionEnded <- function(fun) {
    endedCallbacks[[length(endedCallbacks) + 1L]] <<- fun
    invisible(NULL)
  }
  session$ns <- identity

  run_flush_callbacks <- function(phase) {
    keep <- list()
    for (item in flushCallbacks) {
      if (identical(item$phase, phase)) try(item$fun(), silent = TRUE)
      if (!isTRUE(item$once)) keep[[length(keep) + 1L]] <- item
      else if (!identical(item$phase, phase)) keep[[length(keep) + 1L]] <- item
    }
    flushCallbacks <<- keep
  }
  flush <- function() {
    run_flush_callbacks('before')
    flushReact()
    run_flush_callbacks('after')
  }

  output <- .make_output_proxy(session)
  attr(output, 'session') <- session
  session$output <- output
  withReactiveDomain(session, app$server(input, output, session))
  flush()

  if (length(nodes$outputs) && !file.exists(stateFile)) {
    stop('WinShiny did not render any outputs during the initial reactive flush.', call. = FALSE)
  }

  writeLines(make_ps1(nodes, eventFile, stateFile, commandFile, readyFile, logFile), ps1, useBytes = TRUE)
  exe <- Sys.which('powershell.exe')
  if (!nzchar(exe)) exe <- Sys.which('powershell')
  if (!nzchar(exe)) exe <- Sys.which('pwsh')
  if (!nzchar(exe)) stop('Could not find powershell.exe, powershell, or pwsh on PATH.', call. = FALSE)

  if (!quiet) message(
    'WinShiny launching PowerShell/WPF host. Log: ',
    normalizePath(logFile, winslash = '/', mustWork = FALSE)
  )
  system2(exe, c('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File', shQuote(ps1)),
          wait = FALSE, stdout = FALSE, stderr = FALSE)

  t0 <- Sys.time()
  while (!file.exists(readyFile) && as.numeric(difftime(Sys.time(), t0, units = 'secs')) < startupTimeout) {
    Sys.sleep(0.1)
  }
  if (!file.exists(readyFile)) {
    msg <- if (file.exists(logFile)) paste(readLines(logFile, warn = FALSE), collapse = '\n') else 'No PowerShell log was written.'
    stop('PowerShell/WPF host did not report readiness. Script: ',
         normalizePath(ps1, winslash = '/', mustWork = FALSE), '\nLog:\n', msg, call. = FALSE)
  }
  if (identical(readLines(readyFile, warn = FALSE)[1], 'error')) {
    msg <- if (file.exists(logFile)) paste(readLines(logFile, warn = FALSE), collapse = '\n') else 'No PowerShell log was written.'
    stop('PowerShell/WPF host failed during startup. Script: ',
         normalizePath(ps1, winslash = '/', mustWork = FALSE), '\nLog:\n', msg, call. = FALSE)
  }
  if (!isTRUE(wait)) return(invisible(session))

  pos <- 0
  on.exit({
    .winshiny_runtime$session <- NULL
    files <- unlist(as.list(plotFiles, all.names = TRUE), use.names = FALSE)
    if (length(files)) try(unlink(files[file.exists(files)]), silent = TRUE)
  }, add = TRUE)

  repeat {
    Sys.sleep(0.04)
    re <- .read_events(eventFile, pos)
    pos <- re$pos
    for (ev in re$events) {
      if (identical(ev$id, '__closed__')) {
        lapply(endedCallbacks, function(fun) try(fun(), silent = TRUE))
        return(invisible(session$returnValue))
      }
      if (identical(ev$id, '__plot_size__')) {
        z <- ev$value
        id <- as.character(z$id %||% '')
        width <- suppressWarnings(as.integer(z$width %||% 800))
        height <- suppressWarnings(as.integer(z$height %||% 500))
        old <- plotSizes[[id]]
        changed <- is.null(old) || abs(old$width - width) >= 2L || abs(old$height - height) >= 2L
        if (nzchar(id) && changed) {
          plotSizes[[id]] <- list(width = width, height = height)
          session$clientData[[paste0('output_', id, '_width')]] <- width
          session$clientData[[paste0('output_', id, '_height')]] <- height
        }
      } else if (identical(ev$id, '__download__')) {
        z <- ev$value
        id <- as.character(z$id %||% '')
        path <- as.character(z$path %||% '')
        if (nzchar(id) && nzchar(path) && exists(id, downloads, inherits = FALSE)) {
          handler <- get(id, downloads, inherits = FALSE)
          tryCatch(handler$content(path), error = function(e) {
            session$sendCommand('notification', list(text = paste('Export failed:', conditionMessage(e)), type = 'error'))
          })
        }
      } else {
        eventValue <- ev$value
        if (ev$id %in% clipboardIds) {
          marker <- '__WINSHINY_CLIPBOARD_ERROR__'
          scalar <- if (is.character(eventValue) && length(eventValue)) eventValue[[1L]] else ''
          if (nzchar(scalar) && startsWith(scalar, marker)) {
            eventValue <- list(error = substring(scalar, nchar(marker) + 1L))
          } else if (nzchar(scalar) && file.exists(scalar)) {
            eventValue <- tryCatch(
              paste(base::readLines(scalar, warn = FALSE, encoding = 'UTF-8'), collapse = '\n'),
              error = function(e) list(error = conditionMessage(e))
            )
            try(suppressWarnings(unlink(scalar)), silent = TRUE)
          }
        }
        input[[ev$id]] <- eventValue
        if (ev$id %in% nodes$themeIds) {
          session$currentTheme <- if (isTRUE(ev$value)) 'dark' else 'light'
          themeState(session$currentTheme)
        }
      }
    }
    flush()
  }
}

# Module proxies. These preserve Shiny's ID namespacing convention for the
# common moduleServer()/callModule() workflow.
`$.winshiny.inputproxy` <- function(x, name) {
  x$values[[x$ns(name)]]
}
`[[.winshiny.inputproxy` <- function(x, i, ...) {
  x$values[[x$ns(as.character(i))]]
}

`$<-.winshiny.output` <- function(x, name, value) {
  session <- attr(x, 'session')
  namespace <- attr(x, 'namespace')
  full_name <- if (is.function(namespace)) namespace(name) else name
  if (inherits(value, 'winshiny.downloadHandler')) {
    session$registerDownload(full_name, value)
  } else if (is.function(value)) {
    ctx <- .ctx('output')
    ctx$run <- function() {
      kind <- if (inherits(value, 'winshiny.render.plot')) {
        'plot'
      } else if (inherits(value, 'winshiny.render.image')) {
        'image'
      } else if (inherits(value, 'winshiny.render.datatable')) {
        'datatable'
      } else if (inherits(value, 'winshiny.render.table')) {
        'table'
      } else if (inherits(value, 'winshiny.render.ui')) {
        'ui'
      } else {
        'text'
      }
      tryCatch({
        if (identical(kind, 'plot')) {
          size <- session$getPlotSize(full_name)
          v <- value(width_px = size$width, height_px = size$height, theme = session$getTheme())
        } else {
          v <- value()
        }
        if (identical(kind, 'ui')) session$registerUiDefaults(v)
        session$sendOutput(full_name, v, kind)
      }, error = function(e) {
        session$sendOutput(full_name, conditionMessage(e), 'error')
      })
    }
    assign(name, ctx, envir = x)
    .schedule(ctx)
  } else {
    session$sendOutput(full_name, value, 'text')
  }
  x
}

moduleServer <- function(id, module, session = getDefaultReactiveDomain()) {
  if (is.null(session)) stop('moduleServer() must be called from an active WinShiny session.', call. = FALSE)
  ns <- NS(id)
  child <- new.env(parent = emptyenv())
  child$input <- structure(list(values = session$input, ns = ns), class = 'winshiny.inputproxy')
  child$output <- .make_output_proxy(session)
  attr(child$output, 'session') <- session
  attr(child$output, 'namespace') <- ns
  child$userData <- session$userData
  child$ns <- ns
  child$sendInputMessage <- function(inputId, message) session$sendInputMessage(ns(inputId), message)
  child$sendOutput <- function(outputId, value, kind = 'text') session$sendOutput(ns(outputId), value, kind)
  child$registerDownload <- function(outputId, handler) session$registerDownload(ns(outputId), handler)
  child$sendCommand <- session$sendCommand
  child$getPlotSize <- function(outputId) session$getPlotSize(ns(outputId))
  child$registerUiDefaults <- session$registerUiDefaults
  withReactiveDomain(child, module(child$input, child$output, child))
}

callModule <- function(module, id, ..., session = getDefaultReactiveDomain()) {
  dots <- list(...)
  moduleServer(id, function(input, output, session) {
    do.call(module, c(list(input = input, output = output, session = session), dots))
  }, session = session)
}

# More faithful event helpers. Handler expressions are isolated from the event
# observer's dependency set, and action-button zero values are ignored by
# default.
.win_event_is_null <- function(value) {
  is.null(value) || length(value) == 0L ||
    (length(value) == 1L && is.numeric(value) && identical(as.numeric(value), 0))
}

observeEvent <- function(eventExpr, handlerExpr, event.env = parent.frame(),
                         event.quoted = FALSE, handler.env = parent.frame(),
                         handler.quoted = FALSE, ..., label = NULL,
                         suspended = FALSE, priority = 0, domain = getDefaultReactiveDomain(),
                         autoDestroy = TRUE, ignoreNULL = TRUE,
                         ignoreInit = FALSE, once = FALSE) {
  force(event.env); force(handler.env); force(domain)
  event <- if (event.quoted) eventExpr else substitute(eventExpr)
  handler <- if (handler.quoted) handlerExpr else substitute(handlerExpr)
  initialized <- FALSE
  active <- TRUE
  last_value <- NULL
  observe({
    value <- eval(event, envir = event.env)
    if (!active) return(invisible(NULL))
    first <- !initialized
    initialized <<- TRUE
    if (first) {
      last_value <<- value
      if (isTRUE(ignoreInit)) return(invisible(NULL))
    } else if (identical(value, last_value)) {
      return(invisible(NULL))
    } else {
      last_value <<- value
    }
    if (isTRUE(ignoreNULL) && .win_event_is_null(value)) return(invisible(NULL))
    result <- isolate(eval(handler, envir = handler.env))
    if (isTRUE(once)) active <<- FALSE
    result
  }, label = label, suspended = suspended, priority = priority,
  domain = domain, autoDestroy = autoDestroy)
}

eventReactive <- function(eventExpr, valueExpr, event.env = parent.frame(),
                          event.quoted = FALSE, value.env = parent.frame(),
                          value.quoted = FALSE, ..., label = NULL,
                          domain = getDefaultReactiveDomain(), ignoreNULL = TRUE,
                          ignoreInit = FALSE) {
  force(event.env); force(value.env); force(domain)
  event <- if (event.quoted) eventExpr else substitute(eventExpr)
  value <- if (value.quoted) valueExpr else substitute(valueExpr)
  initialized <- FALSE
  cached <- NULL
  reactive({
    event_value <- eval(event, envir = event.env)
    first <- !initialized
    initialized <<- TRUE
    if (first && isTRUE(ignoreInit)) return(cached)
    if (isTRUE(ignoreNULL) && .win_event_is_null(event_value)) return(cached)
    cached <<- isolate(eval(value, envir = value.env))
    cached
  }, label = label, domain = domain)
}

# Event-loop timers. runApp() calls flushReact() frequently, so due contexts are
# scheduled without a separate R thread.
.reset_reactive_graph <- function() {
  .win_reactive$current <- NULL
  .win_reactive$queue <- list()
  .win_reactive$next_id <- 0L
  .win_reactive$deps <- new.env(parent = emptyenv())
  .win_reactive$domain <- NULL
  .win_reactive$timers <- list()
  invisible(NULL)
}

invalidateLater <- function(millis, session = getDefaultReactiveDomain()) {
  ctx <- .win_reactive$current
  if (is.null(ctx)) return(invisible(NULL))
  .win_reactive$timers[[ctx$id]] <- list(
    due = Sys.time() + as.numeric(millis) / 1000,
    ctx = ctx
  )
  invisible(NULL)
}

flushReact <- function() {
  guard <- 0L
  repeat {
    timers <- .win_reactive$timers %||% list()
    if (length(timers)) {
      now <- Sys.time()
      due <- vapply(timers, function(x) now >= x$due, logical(1))
      if (any(due)) {
        for (item in timers[due]) .schedule(item$ctx)
        .win_reactive$timers <- timers[!due]
      }
    }
    if (!length(.win_reactive$queue)) break
    guard <- guard + 1L
    if (guard > 10000L) stop('Reactive flush did not converge', call. = FALSE)
    q <- .win_reactive$queue
    .win_reactive$queue <- list()
    lapply(q, function(ctx) {
      if (identical(ctx$kind, 'observer')) {
        tryCatch(.run_ctx(ctx), error = function(e) warning(conditionMessage(e), call. = FALSE))
      } else {
        .run_ctx(ctx)
      }
    })
  }
  invisible(NULL)
}

reactiveTimer <- function(intervalMs = 1000, session = getDefaultReactiveDomain()) {
  force(intervalMs); force(session)
  function() {
    invalidateLater(intervalMs, session)
    Sys.time()
  }
}

reactivePoll <- function(intervalMillis, session, checkFunc, valueFunc) {
  force(intervalMillis); force(session); force(checkFunc); force(valueFunc)
  last_check <- NULL
  last_value <- NULL
  reactive({
    invalidateLater(intervalMillis, session)
    current <- checkFunc()
    if (is.null(last_check) || !identical(current, last_check)) {
      last_check <<- current
      last_value <<- isolate(valueFunc())
    }
    last_value
  })
}

reactiveFileReader <- function(intervalMillis, session, filePath, readFunc, ...) {
  dots <- list(...)
  reactivePoll(
    intervalMillis, session,
    checkFunc = function() {
      path <- if (is.function(filePath)) filePath() else filePath
      file.info(path)$mtime
    },
    valueFunc = function() {
      path <- if (is.function(filePath)) filePath() else filePath
      do.call(readFunc, c(list(path), dots))
    }
  )
}

getCurrentTheme <- function(session = getDefaultReactiveDomain()) {
  if (is.null(session)) return(NULL)
  session$currentTheme %||% 'light'
}

.winshiny_runtime <- new.env(parent = emptyenv())
.winshiny_runtime$session <- NULL
isRunning <- function() !is.null(.winshiny_runtime$session)
is.shiny.appobj <- function(x) inherits(x, 'winshiny.app')
stopApp <- function(returnValue = invisible()) {
  session <- .winshiny_runtime$session
  if (!is.null(session)) {
    session$returnValue <- returnValue
    session$sendCommand('close', list())
  }
  invisible(returnValue)
}
