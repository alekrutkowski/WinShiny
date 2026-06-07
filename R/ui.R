.win_tag <- function(type, ..., attribs = list()) structure(list(type = type, children = .flatten_children(list(...)), attribs = attribs), class = 'winshiny.tag')
.win_input <- function(kind, inputId, label, value = NULL, ...) structure(list(type = 'input', kind = kind, id = as.character(inputId), label = label, value = value, args = list(...)), class = 'winshiny.ui_input')
.win_output <- function(kind, outputId, ...) structure(list(type = 'output', kind = kind, id = as.character(outputId), args = list(...)), class = 'winshiny.ui_output')

# UI containers and tag helpers
fluidPage <- function(..., title = NULL, theme = NULL, lang = NULL) .win_tag('fluidPage', ..., attribs = list(title = title, theme = theme, lang = lang))
fixedPage <- function(...) .win_tag('fixedPage', ...)
fillPage <- function(..., padding = 0, title = NULL, bootstrap = TRUE, theme = NULL) .win_tag('fillPage', ..., attribs = list(title = title))
flowLayout <- function(..., cellArgs = list()) .win_tag('flowLayout', ...)
verticalLayout <- function(..., fluid = TRUE) .win_tag('verticalLayout', ...)
sidebarLayout <- function(sidebarPanel, mainPanel, position = c('left','right'), fluid = TRUE) .win_tag('sidebarLayout', sidebarPanel, mainPanel, attribs = list(position = match.arg(position)))
sidebarPanel <- function(..., width = 4) .win_tag('sidebarPanel', ..., attribs = list(width = width))
mainPanel <- function(..., width = 8) .win_tag('mainPanel', ..., attribs = list(width = width))
wellPanel <- function(...) .win_tag('wellPanel', ...)
absolutePanel <- function(..., top = NULL, left = NULL, right = NULL, bottom = NULL, width = NULL, height = NULL, draggable = FALSE, fixed = FALSE, cursor = c('auto','move','default','inherit')) .win_tag('absolutePanel', ..., attribs = list(top=top,left=left,right=right,bottom=bottom,width=width,height=height))
fixedPanel <- function(...) absolutePanel(..., fixed = TRUE)
conditionalPanel <- function(condition, ..., ns = NS(NULL)) .win_tag('conditionalPanel', ..., attribs = list(condition = condition))
column <- function(width, ..., offset = 0) .win_tag('column', ..., attribs = list(width = width, offset = offset))
fluidRow <- function(...) .win_tag('fluidRow', ...)

htmlTemplate <- function(filename, ..., document_ = 'auto') .win_tag('htmlTemplate', paste(readLines(filename, warn = FALSE), collapse = '\n'), attribs = list(args = list(...)))
tagList <- function(...) .win_tag('tagList', ...)
titlePanel <- function(title, windowTitle = title) .win_tag('titlePanel', title, attribs = list(windowTitle = windowTitle))
headerPanel <- titlePanel
HTML <- function(text, ...) structure(paste(text, collapse = '\n'), class = c('html','character'))

.make_tag <- function(nm) function(..., .noWS = NULL, .renderHook = NULL) .win_tag(nm, ...)
.tag_names <- c('a','abbr','address','area','article','aside','audio','b','base','bdi','bdo','blockquote','body','br','button','canvas','caption','cite','code','col','colgroup','data','datalist','dd','del','details','dfn','dialog','div','dl','dt','em','embed','fieldset','figcaption','figure','footer','form','h1','h2','h3','h4','h5','h6','head','header','hr','html','i','iframe','img','input','ins','kbd','label','legend','li','link','main','map','mark','meta','meter','nav','noscript','object','ol','optgroup','option','output','p','param','picture','pre','progress','q','rp','rt','ruby','s','samp','script','section','select','small','source','span','strong','style','sub','summary','sup','table','tbody','td','template','textarea','tfoot','th','thead','time','title','tr','track','u','ul','var','video','wbr')
# Keep tag constructors only under `tags`. Creating bare functions such as
# `sub`, `source`, and `table` in the package namespace shadows base R even
# when those functions are not exported.
tags <- structure(stats::setNames(lapply(.tag_names, .make_tag), .tag_names), class = 'winshiny.tags')

# Inputs matching Shiny's public inputs
textInput <- function(inputId, label, value = '', width = NULL, placeholder = NULL) .win_input('text', inputId, label, as.character(value), width = width, placeholder = placeholder)
textAreaInput <- function(inputId, label, value = '', width = NULL, height = NULL, cols = NULL, rows = NULL, placeholder = NULL, resize = NULL) .win_input('textarea', inputId, label, as.character(value), width=width,height=height,cols=cols,rows=rows %||% 4,placeholder=placeholder,resize=resize)
passwordInput <- function(inputId, label, value = '', width = NULL, placeholder = NULL) .win_input('password', inputId, label, as.character(value), width=width,placeholder=placeholder)
numericInput <- function(inputId, label, value, min = NA, max = NA, step = NA, width = NULL) .win_input('numeric', inputId, label, value, min=min,max=max,step=step,width=width)
sliderInput <- function(inputId, label, min, max, value, step = NULL, round = FALSE, ticks = TRUE, animate = FALSE, width = NULL, sep = ',', pre = NULL, post = NULL, timeFormat = NULL, timezone = NULL, dragRange = TRUE) .win_input('slider', inputId, label, value, min=min,max=max,step=step %||% 1,round=round,ticks=ticks,animate=animate,width=width,sep=sep,pre=pre,post=post,timeFormat=timeFormat,timezone=timezone,dragRange=dragRange)
dateInput <- function(inputId, label, value = NULL, min = NULL, max = NULL, format = 'yyyy-mm-dd', startview = 'month', weekstart = 0, language = 'en', width = NULL, autoclose = TRUE, datesdisabled = NULL, daysofweekdisabled = NULL) .win_input('date', inputId, label, as.character(as.Date(value %||% Sys.Date())), min=.as_chr(min),max=.as_chr(max),format=format,startview=startview,weekstart=weekstart,language=language,width=width)
dateRangeInput <- function(inputId, label, start = NULL, end = NULL, min = NULL, max = NULL, format = 'yyyy-mm-dd', startview = 'month', weekstart = 0, language = 'en', separator = ' to ', width = NULL, autoclose = TRUE) .win_input('daterange', inputId, label, c(as.character(as.Date(start %||% Sys.Date())), as.character(as.Date(end %||% Sys.Date()))), min=.as_chr(min),max=.as_chr(max),format=format,startview=startview,weekstart=weekstart,language=language,separator=separator,width=width)
checkboxInput <- function(inputId, label, value = FALSE, width = NULL) .win_input('checkbox', inputId, label, isTRUE(value), width=width)
checkboxGroupInput <- function(inputId, label, choices = NULL, selected = NULL, inline = FALSE, width = NULL, choiceNames = NULL, choiceValues = NULL) { if (!is.null(choiceValues)) choices <- stats::setNames(choiceValues, as.character(choiceNames %||% choiceValues)); .win_input('checkboxgroup', inputId, label, as.character(selected %||% character()), choices=.normalize_choices(choices), inline=inline, width=width) }
radioButtons <- function(inputId, label, choices = NULL, selected = NULL, inline = FALSE, width = NULL, choiceNames = NULL, choiceValues = NULL) { if (!is.null(choiceValues)) choices <- stats::setNames(choiceValues, as.character(choiceNames %||% choiceValues)); ch <- .normalize_choices(choices); selected <- selected %||% if (length(ch)) unname(ch)[[1]] else NULL; .win_input('radio', inputId, label, as.character(selected), choices=ch, inline=inline, width=width) }
selectInput <- function(inputId, label, choices, selected = NULL, multiple = FALSE, selectize = TRUE, width = NULL, size = NULL) { ch <- .normalize_choices(choices); if (is.null(selected) && !multiple && length(ch)) selected <- unname(ch)[[1]]; .win_input('select', inputId, label, as.character(selected %||% character()), choices=ch, multiple=multiple, selectize=selectize, width=width,size=size) }
selectizeInput <- function(inputId, ..., options = NULL, width = NULL) { x <- selectInput(inputId, ..., selectize = TRUE, width = width); x$kind <- 'selectize'; x$args$options <- options; x }
varSelectInput <- function(inputId, label, data, selected = NULL, multiple = FALSE, selectize = TRUE, width = NULL, size = NULL) selectInput(inputId, label, choices = names(data), selected = selected, multiple = multiple, selectize = selectize, width = width, size = size)
varSelectizeInput <- function(inputId, ..., options = NULL, width = NULL) { x <- varSelectInput(inputId, ..., selectize = TRUE, width = width); x$kind <- 'varselectize'; x$args$options <- options; x }
fileInput <- function(inputId, label, multiple = FALSE, accept = NULL, width = NULL, buttonLabel = 'Browse...', placeholder = 'No file selected') .win_input('file', inputId, label, if (multiple) character() else '', multiple=multiple,accept=accept,width=width,buttonLabel=buttonLabel,placeholder=placeholder)
actionButton <- function(inputId, label, icon = NULL, width = NULL, disabled = FALSE, ...) .win_input('button', inputId, label, 0L, icon=icon,width=width,disabled=disabled)
clipboardButton <- function(inputId, label = 'Import table from clipboard', icon = NULL, width = NULL, disabled = FALSE, ...) .win_input('clipboard', inputId, label, NULL, icon=icon,width=width,disabled=disabled)
copyTableButton <- function(inputId, label = 'Copy tables to clipboard', outputIds, title = NULL, subtitle = NULL, notes = NULL, width = NULL, ...) { ids <- as.character(outputIds); labels <- names(outputIds); if (is.null(labels)) labels <- ids; labels[!nzchar(labels)] <- ids[!nzchar(labels)]; .win_input('copytable', inputId, label, NULL, outputIds = unname(ids), outputLabels = unname(labels), title = title, subtitle = subtitle, notes = notes, width = width) }
copyPlotButton <- function(inputId, label = 'Copy plot to clipboard', outputId, width = NULL, ...) .win_input('copyplot', inputId, label, NULL, outputId = as.character(outputId)[1L], width = width)
actionLink <- function(inputId, label, icon = NULL, width = NULL, ...) .win_input('link', inputId, label, 0L, icon=icon,width=width)
submitButton <- function(text = 'Apply Changes', icon = NULL, width = NULL) .win_input('submit', paste0('submit_', sample.int(.Machine$integer.max, 1)), text, 0L, icon=icon,width=width)

# Outputs and render functions
textOutput <- function(outputId, container = if (inline) tags$span else tags$div, inline = FALSE) .win_output('text', outputId, inline=inline)
verbatimTextOutput <- function(outputId, placeholder = FALSE) .win_output('verbatim', outputId, placeholder=placeholder)
plotOutput <- function(outputId, width = '100%', height = '400px', inline = FALSE, click = NULL, dblclick = NULL, hover = NULL, brush = NULL, hoverDelay = NULL, hoverDelayType = NULL, brushDelay = NULL, brushDelayType = NULL, dblclickDelay = NULL) .win_output('plot', outputId, width=width,height=height,inline=inline,click=click,dblclick=dblclick,hover=hover,brush=brush)
imageOutput <- function(outputId, width = '100%', height = '400px', click = NULL, dblclick = NULL, hover = NULL, brush = NULL, inline = FALSE) .win_output('image', outputId, width=width,height=height,inline=inline,click=click,dblclick=dblclick,hover=hover,brush=brush)
tableOutput <- function(outputId, height = NULL, fill = FALSE) .win_output('table', outputId, height=height,fill=isTRUE(fill))
dataTableOutput <- function(outputId, width = '100%', height = 'auto', fill = FALSE) .win_output('datatable', outputId, width=width,height=height,fill=isTRUE(fill))
htmlOutput <- function(outputId, inline = FALSE, container = if (inline) tags$span else tags$div, ...) .win_output('html', outputId, inline=inline)
uiOutput <- htmlOutput
downloadButton <- function(outputId, label = 'Download', class = NULL, ...) .win_output('download', outputId, label=label,class=class)
downloadLink <- downloadButton

# Force the caller environment while the render function is being created.
# Leaving `env = parent.frame()` as an unforced promise makes parent.frame()
# resolve later, during output execution, when the server call frame is no
# longer the dynamic caller. That loses `input`, `output`, and `session`.
.capture_render_env <- function(env) {
  force(env)
  if (!is.environment(env)) stop('`env` must be an environment.', call. = FALSE)
  env
}

renderText <- function(expr, env = parent.frame(), quoted = FALSE, outputArgs = list(), sep = ' ') {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function() paste(as.character(eval(ex, envir = env)), collapse = sep)
  class(f) <- c('winshiny.render.text', 'function')
  f
}
renderPrint <- function(expr, env = parent.frame(), quoted = FALSE, outputArgs = list(), width = getOption('width')) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function() paste(capture.output(print(eval(ex, envir = env)), width = width), collapse = '\n')
  class(f) <- c('winshiny.render.print', 'function')
  f
}
renderTable <- function(expr, striped = FALSE, hover = FALSE, bordered = FALSE, spacing = c('s','xs','m','l'), width = 'auto', align = NULL, rownames = FALSE, colnames = TRUE, digits = NULL, na = 'NA', ..., env = parent.frame(), quoted = FALSE, outputArgs = list()) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function() paste(capture.output(print(as.data.frame(eval(ex, envir = env)), row.names = rownames)), collapse = '\n')
  class(f) <- c('winshiny.render.table', 'function')
  f
}
renderDataTable <- function(expr, options = NULL, searchDelay = 500, callback = 'function(oTable) {}', escape = TRUE, env = parent.frame(), quoted = FALSE, outputArgs = list()) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function() paste(capture.output(print(as.data.frame(eval(ex, envir = env)), row.names = FALSE)), collapse = '\n')
  class(f) <- c('winshiny.render.datatable', 'function')
  f
}
renderPlot <- function(expr, width = 'auto', height = 'auto', res = 96, ..., alt = NA,
                       env = parent.frame(), quoted = FALSE, execOnResize = FALSE,
                       outputArgs = list()) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function(file = tempfile('winshiny_plot_', fileext = '.png')) {
    file <- normalizePath(file, winslash = '/', mustWork = FALSE)
    dev <- NULL
    closed <- FALSE
    on.exit({
      if (!closed && !is.null(dev) && dev %in% grDevices::dev.list()) {
        try(grDevices::dev.off(dev), silent = TRUE)
      }
    }, add = TRUE)

    grDevices::png(filename = file, width = 800, height = 500, units = 'px', res = res)
    dev <- grDevices::dev.cur()
    value <- eval(ex, envir = env)
    if (inherits(value, c('ggplot', 'trellis'))) print(value)
    grDevices::dev.off(dev)
    closed <- TRUE

    info <- file.info(file)
    if (!file.exists(file) || is.na(info$size) || info$size <= 0) {
      stop('renderPlot() did not produce a non-empty PNG file.', call. = FALSE)
    }
    file
  }
  class(f) <- c('winshiny.render.plot', 'function')
  f
}
renderCachedPlot <- renderPlot
renderImage <- function(expr, env = parent.frame(), quoted = FALSE, deleteFile = TRUE, outputArgs = list()) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function() {
    z <- eval(ex, envir = env)
    if (is.list(z) && !is.null(z$src)) normalizePath(z$src, winslash = '/', mustWork = FALSE) else normalizePath(as.character(z), winslash = '/', mustWork = FALSE)
  }
  class(f) <- c('winshiny.render.image', 'function')
  f
}
.render_ui_text <- function(x) { if (inherits(x, 'winshiny.tag')) paste(unlist(lapply(x$children, .render_ui_text)), collapse='\n') else if (inherits(x, 'winshiny.ui_input')) paste0('[input ', x$id, ']') else if (inherits(x, 'winshiny.ui_output')) paste0('[output ', x$id, ']') else if (is.list(x) && !is.data.frame(x)) paste(unlist(lapply(x, .render_ui_text)), collapse='\n') else paste(as.character(x), collapse='\n') }
renderUI <- function(expr, env = parent.frame(), quoted = FALSE, outputArgs = list()) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function() .render_ui_text(eval(ex, envir = env))
  class(f) <- c('winshiny.render.ui', 'function')
  f
}
downloadHandler <- function(filename, content, contentType = NA, outputArgs = list()) structure(list(filename=filename, content=content, contentType=contentType, outputArgs=outputArgs), class='winshiny.downloadHandler')

createRenderFunction <- function(func, transform = function(value, session, name, ...) value, outputFunc = NULL, outputArgs = NULL, cacheHint = 'auto', cacheWriteHook = NULL, cacheReadHook = NULL) { force(func); function(...) func(...) }
markRenderFunction <- function(uiFunc, renderFunc, outputArgs = list(), cacheHint = 'auto') renderFunc
outputOptions <- function(x, name, ...) invisible(NULL)
getCurrentOutputInfo <- function(session = getDefaultReactiveDomain()) NULL

# Update functions. In browser Shiny these send client messages; here they mutate session$input immediately.
.update_input <- function(session, inputId, value = NULL, ...) { if (!is.null(session) && !is.null(value) && !is.null(session$input)) session$input[[inputId]] <- value; invisible(NULL) }
updateTextInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, placeholder = NULL) .update_input(session,inputId,value)
updateTextAreaInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, placeholder = NULL) .update_input(session,inputId,value)
updateNumericInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, min = NULL, max = NULL, step = NULL) .update_input(session,inputId,value)
updateSliderInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, min = NULL, max = NULL, step = NULL, timeFormat = NULL, timezone = NULL) .update_input(session,inputId,value)
updateCheckboxInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL) .update_input(session,inputId,value)
updateCheckboxGroupInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL, selected = NULL, inline = FALSE, choiceNames = NULL, choiceValues = NULL) .update_input(session,inputId,selected)
updateRadioButtons <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL, selected = NULL, inline = FALSE, choiceNames = NULL, choiceValues = NULL) .update_input(session,inputId,selected)
updateSelectInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL, selected = NULL) .update_input(session,inputId,selected)
updateSelectizeInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL, selected = NULL, options = list(), server = FALSE) .update_input(session,inputId,selected)
updateVarSelectInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, data = NULL, selected = NULL) .update_input(session,inputId,selected)
updateVarSelectizeInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, data = NULL, selected = NULL, options = list(), server = FALSE) .update_input(session,inputId,selected)
updateDateInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, min = NULL, max = NULL) .update_input(session,inputId,as.character(value))
updateDateRangeInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, start = NULL, end = NULL, min = NULL, max = NULL) .update_input(session,inputId,c(as.character(start),as.character(end)))
restoreInput <- function(id, default) default
registerInputHandler <- function(type, fun, force = FALSE) invisible(NULL)
removeInputHandler <- function(type) invisible(NULL)
snapshotPreprocessInput <- function(inputId, func) invisible(NULL)
snapshotPreprocessOutput <- function(outputId, func) invisible(NULL)
bootstrapPage <- fluidPage

# -------------------------------------------------------------------------
# Native Windows layouts, navigation, themes, and compatibility helpers
# -------------------------------------------------------------------------

basicPage <- function(...) .win_tag('basicPage', ...)
pageWithSidebar <- function(headerPanel, sidebarPanel, mainPanel) {
  fluidPage(headerPanel, sidebarLayout(sidebarPanel, mainPanel))
}
inputPanel <- function(..., tag = NULL) .win_tag('inputPanel', ...)
helpText <- function(...) .win_tag('helpText', ...)
splitLayout <- function(..., cellWidths = NULL, cellArgs = list()) {
  .win_tag('splitLayout', ..., attribs = list(cellWidths = cellWidths, cellArgs = cellArgs))
}
fixedRow <- function(...) .win_tag('fixedRow', ...)
fillRow <- function(..., flex = c(1, 1), gap = NULL, class = NULL, height = NULL) {
  .win_tag('fillRow', ..., attribs = list(flex = flex, gap = gap, class = class, height = height))
}
fillCol <- function(..., flex = c(1, 1), gap = NULL, class = NULL, height = NULL) {
  .win_tag('fillCol', ..., attribs = list(flex = flex, gap = gap, class = class, height = height))
}

navbarPage <- function(title, ..., id = NULL, selected = NULL, position = c('static-top', 'fixed-top', 'fixed-bottom'),
                       header = NULL, footer = NULL, inverse = FALSE, collapsible = FALSE,
                       fluid = TRUE, theme = NULL, windowTitle = title, lang = NULL) {
  .win_tag('navbarPage', ..., attribs = list(
    title = title, id = id, selected = selected, position = match.arg(position),
    header = header, footer = footer, inverse = inverse, collapsible = collapsible,
    fluid = fluid, theme = theme, windowTitle = windowTitle, lang = lang
  ))
}

tabsetPanel <- function(..., id = NULL, selected = NULL, type = c('tabs', 'pills', 'hidden'),
                        header = NULL, footer = NULL) {
  .win_tag('tabsetPanel', ..., attribs = list(
    id = id, selected = selected, type = match.arg(type), header = header, footer = footer
  ))
}

tabPanel <- function(title, ..., value = title, icon = NULL) {
  .win_tag('tabPanel', ..., attribs = list(title = title, value = value, icon = icon))
}

tabPanelBody <- function(value, ..., icon = NULL) {
  .win_tag('tabPanel', ..., attribs = list(title = value, value = value, icon = icon))
}

navbarMenu <- function(title, ..., icon = NULL) {
  .win_tag('navbarMenu', ..., attribs = list(title = title, icon = icon))
}

navlistPanel <- function(..., id = NULL, selected = NULL, well = TRUE, fluid = TRUE, widths = c(4, 8)) {
  .win_tag('navlistPanel', ..., attribs = list(
    id = id, selected = selected, well = well, fluid = fluid, widths = widths
  ))
}

# WinShiny-native theme control. Base Shiny has no exact equivalent; bslib
# supplies related browser-side dark-mode facilities.
themeToggle <- function(inputId = 'winshiny_theme', label = 'Dark mode', value = FALSE, width = NULL) {
  .win_input('theme', inputId, label, isTRUE(value), width = width)
}
winThemeToggle <- themeToggle

# Direct tag helpers commonly exported by Shiny.
a <- tags$a
br <- tags$br
code <- tags$code
div <- tags$div
em <- tags$em
h1 <- tags$h1
h2 <- tags$h2
h3 <- tags$h3
h4 <- tags$h4
h5 <- tags$h5
h6 <- tags$h6
hr <- tags$hr
img <- tags$img
p <- tags$p
pre <- tags$pre
span <- tags$span
strong <- tags$strong

icon <- function(name, class = NULL, lib = 'font-awesome', verify_fa = FALSE, a11y = 'auto') {
  structure(list(name = as.character(name), class = class, lib = lib), class = 'winshiny.icon')
}

# uiOutput is a dynamic native WPF content host, not an alias for htmlOutput.
uiOutput <- function(outputId, inline = FALSE, container = if (inline) tags$span else tags$div, ...) {
  .win_output('ui', outputId, inline = inline)
}

# Preserve data frames so the WPF backend can bind them to a native DataGrid.
renderTable <- function(expr, striped = FALSE, hover = FALSE, bordered = FALSE,
                        spacing = c('s','xs','m','l'), width = 'auto', align = NULL,
                        rownames = FALSE, colnames = TRUE, digits = NULL, na = 'NA', ...,
                        env = parent.frame(), quoted = FALSE, outputArgs = list()) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function() {
    value <- eval(ex, envir = env)
    if (is.null(value)) return(data.frame())
    value <- as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE)
    value[] <- lapply(value, function(column) {
      if (is.factor(column) || inherits(column, c('Date', 'POSIXt'))) column <- as.character(column)
      if (!is.null(digits) && is.numeric(column)) column <- round(column, digits = digits)
      if (is.character(column)) column[is.na(column)] <- na
      column
    })
    if (isTRUE(rownames)) value <- cbind(data.frame(`Row names` = rownames(value), check.names = FALSE), value)
    value
  }
  attr(f, 'winshiny.table.options') <- list(
    striped = striped, hover = hover, bordered = bordered,
    spacing = match.arg(spacing), width = width, align = align,
    rownames = rownames, colnames = colnames, digits = digits, na = na
  )
  class(f) <- c('winshiny.render.table', 'function')
  f
}

renderDataTable <- function(expr, options = NULL, searchDelay = 500,
                            callback = 'function(oTable) {}', escape = TRUE,
                            env = parent.frame(), quoted = FALSE, outputArgs = list()) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function() {
    value <- eval(ex, envir = env)
    if (is.null(value)) data.frame() else as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE)
  }
  attr(f, 'winshiny.datatable.options') <- options
  class(f) <- c('winshiny.render.datatable', 'winshiny.render.table', 'function')
  f
}

renderPlot <- function(expr, width = 'auto', height = 'auto', res = 96, ..., alt = NA,
                       env = parent.frame(), quoted = FALSE, execOnResize = TRUE,
                       outputArgs = list()) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  dots <- list(...)
  f <- function(file = tempfile('winshiny_plot_', fileext = '.png'),
                width_px = NULL, height_px = NULL, theme = NULL,
                res_px = NULL) {
    file <- normalizePath(file, winslash = '/', mustWork = FALSE)
    width_px <- suppressWarnings(as.integer(width_px %||% if (is.numeric(width)) width else 800L))
    height_px <- suppressWarnings(as.integer(height_px %||% if (is.numeric(height)) height else 500L))
    if (is.na(width_px) || width_px < 200L) width_px <- 800L
    if (is.na(height_px) || height_px < 150L) height_px <- 500L
    width_px <- min(width_px, 12000L)
    height_px <- min(height_px, 12000L)
    res_px <- suppressWarnings(as.numeric(res_px %||% res))
    if (is.na(res_px) || res_px <= 0) res_px <- res

    dev <- NULL
    closed <- FALSE
    on.exit({
      if (!closed && !is.null(dev) && dev %in% grDevices::dev.list()) {
        try(grDevices::dev.off(dev), silent = TRUE)
      }
    }, add = TRUE)

    theme <- tolower(as.character(theme %||% 'light')[1L])
    dark <- identical(theme, 'dark')
    png_args <- c(list(
      filename = file, width = width_px, height = height_px,
      units = 'px', res = res_px
    ), dots)
    if (is.null(png_args$bg)) png_args$bg <- if (dark) '#1E1E1E' else 'white'
    do.call(grDevices::png, png_args)
    dev <- grDevices::dev.cur()
    if (dark) {
      graphics::par(
        bg = '#1E1E1E', fg = '#E6E6E6', col.axis = '#E6E6E6',
        col.lab = '#E6E6E6', col.main = '#FFFFFF', col.sub = '#D0D0D0'
      )
    }
    value <- eval(ex, envir = env)
    if (inherits(value, 'ggplot') && dark && requireNamespace('ggplot2', quietly = TRUE)) {
      major_blank <- inherits(value$theme$panel.grid, 'element_blank') ||
        inherits(value$theme$panel.grid.major, 'element_blank')
      minor_blank <- major_blank || inherits(value$theme$panel.grid.minor, 'element_blank')
      value <- value + ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = '#1E1E1E', colour = NA),
        panel.background = ggplot2::element_rect(fill = '#1E1E1E', colour = NA),
        legend.background = ggplot2::element_rect(fill = '#1E1E1E', colour = NA),
        legend.key = ggplot2::element_rect(fill = '#1E1E1E', colour = NA),
        text = ggplot2::element_text(colour = '#E6E6E6'),
        axis.text = ggplot2::element_text(colour = '#E6E6E6'),
        axis.title = ggplot2::element_text(colour = '#E6E6E6'),
        plot.title = ggplot2::element_text(colour = '#FFFFFF'),
        panel.grid.major = if (major_blank) ggplot2::element_blank() else ggplot2::element_line(colour = '#55555A'),
        panel.grid.minor = if (minor_blank) ggplot2::element_blank() else ggplot2::element_line(colour = '#3D3D42')
      )

      # ggplot2's default point colour is black, which is nearly invisible on
      # a dark panel. Preserve application-supplied or mapped colours and only
      # replace the implicit default used by otherwise unstyled GeomPoint
      # layers.
      global_colour <- !is.null(value$mapping$colour) || !is.null(value$mapping$color)
      for (i in seq_along(value$layers)) {
        layer <- value$layers[[i]]
        if (!inherits(layer$geom, 'GeomPoint')) next
        layer_colour <- !is.null(layer$mapping$colour) || !is.null(layer$mapping$color)
        fixed_colour <- !is.null(layer$aes_params$colour) || !is.null(layer$aes_params$color)
        if (!global_colour && !layer_colour && !fixed_colour) {
          value$layers[[i]]$aes_params$colour <- '#69B7FF'
        }
      }
    }
    if (inherits(value, c('ggplot', 'trellis'))) print(value)
    grDevices::dev.off(dev)
    closed <- TRUE

    info <- file.info(file)
    if (!file.exists(file) || is.na(info$size) || info$size <= 0) {
      stop('renderPlot() did not produce a non-empty PNG file.', call. = FALSE)
    }
    file
  }
  attr(f, 'winshiny.plot.options') <- list(
    width = width, height = height, res = res, alt = alt,
    execOnResize = isTRUE(execOnResize), outputArgs = outputArgs
  )
  class(f) <- c('winshiny.render.plot', 'function')
  f
}
renderCachedPlot <- renderPlot

.ui_to_spec <- function(x) {
  if (is.null(x)) return(NULL)
  if (inherits(x, 'winshiny.ui_input')) {
    return(list(
      nodeType = 'input', kind = x$kind, id = x$id,
      label = as.character(x$label %||% x$id), value = x$value,
      args = x$args %||% list()
    ))
  }
  if (inherits(x, 'winshiny.ui_output')) {
    return(list(
      nodeType = 'output', kind = x$kind, id = x$id,
      args = x$args %||% list()
    ))
  }
  if (inherits(x, 'winshiny.tag')) {
    return(list(
      nodeType = 'tag', type = x$type,
      attribs = x$attribs %||% list(),
      children = Filter(Negate(is.null), lapply(x$children, .ui_to_spec))
    ))
  }
  if (inherits(x, 'winshiny.icon')) {
    return(list(nodeType = 'text', value = paste0('[', x$name, ']')))
  }
  if (is.list(x) && !is.data.frame(x)) {
    return(list(nodeType = 'tag', type = 'tagList', attribs = list(),
                children = Filter(Negate(is.null), lapply(x, .ui_to_spec))))
  }
  list(nodeType = 'text', value = paste(as.character(x), collapse = '\n'))
}

renderUI <- function(expr, env = parent.frame(), quoted = FALSE, outputArgs = list()) {
  env <- .capture_render_env(env)
  ex <- if (quoted) expr else substitute(expr)
  f <- function() .ui_to_spec(eval(ex, envir = env))
  class(f) <- c('winshiny.render.ui', 'function')
  f
}

# Validation helpers with Shiny-like call shapes.
isTruthy <- function(x) {
  if (is.null(x) || length(x) == 0L) return(FALSE)
  if (identical(x, FALSE)) return(FALSE)
  if (is.character(x) && length(x) == 1L && !nzchar(x)) return(FALSE)
  if (inherits(x, 'try-error')) return(FALSE)
  if (is.logical(x) && all(is.na(x))) return(FALSE)
  TRUE
}
need <- function(expr, message = paste(label, 'must be provided'), label) {
  if (isTruthy(expr)) NULL else message
}
validate <- function(..., errorClass = character()) {
  messages <- unlist(list(...), recursive = TRUE, use.names = FALSE)
  messages <- messages[!vapply(messages, is.null, logical(1))]
  messages <- as.character(messages[nzchar(as.character(messages))])
  if (length(messages)) stop(paste(messages, collapse = '\n'), call. = FALSE)
  invisible(NULL)
}
validateCssUnit <- function(x) {
  if (is.null(x) || identical(x, 'auto') || identical(x, '100%')) return(x)
  if (is.numeric(x) && length(x) == 1L) return(paste0(x, 'px'))
  x <- as.character(x)
  if (!grepl('^[0-9.]+(px|%|em|rem|vh|vw)$', x)) stop('Invalid CSS unit: ', x, call. = FALSE)
  x
}

NS <- function(namespace, id = NULL) {
  ns_prefix <- paste(namespace, collapse = '-')
  ns_fun <- if (!nzchar(ns_prefix)) identity else function(id) paste(ns_prefix, id, sep = '-')
  if (is.null(id)) return(ns_fun)
  ns_fun(id)
}
ns.sep <- '-'
moduleServer <- function(id, module, session = getDefaultReactiveDomain()) {
  if (is.null(session)) stop('moduleServer() must be called from an active WinShiny session.', call. = FALSE)
  child <- new.env(parent = emptyenv())
  child$input <- session$input
  child$userData <- session$userData
  child$ns <- NS(id)
  child$sendInputMessage <- session$sendInputMessage
  child$sendOutput <- session$sendOutput
  child$registerDownload <- session$registerDownload
  child$sendCommand <- session$sendCommand
  withReactiveDomain(child, module(child$input, session$output %||% NULL, child))
}
callModule <- function(module, id, ..., session = getDefaultReactiveDomain()) {
  moduleServer(id, function(input, output, session) module(input, output, session, ...), session = session)
}

# Client update functions now send native WPF commands and update the R-side value.
.update_input <- function(session, inputId, value = NULL, ...) {
  message <- c(list(value = value), list(...))
  message <- message[!vapply(message, is.null, logical(1))]
  if (!is.null(session) && !is.null(session$sendInputMessage)) {
    session$sendInputMessage(inputId, message)
  }
  if (!is.null(session) && !is.null(value) && !is.null(session$input)) {
    session$input[[inputId]] <- value
  }
  invisible(NULL)
}
updateTextInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, placeholder = NULL) .update_input(session,inputId,value,label=label,placeholder=placeholder)
updateTextAreaInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, placeholder = NULL) .update_input(session,inputId,value,label=label,placeholder=placeholder)
updateNumericInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, min = NULL, max = NULL, step = NULL) .update_input(session,inputId,value,label=label,min=min,max=max,step=step)
updateSliderInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, min = NULL, max = NULL, step = NULL, timeFormat = NULL, timezone = NULL) .update_input(session,inputId,value,label=label,min=min,max=max,step=step)
updateCheckboxInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL) .update_input(session,inputId,value,label=label)
updateCheckboxGroupInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL, selected = NULL, inline = FALSE, choiceNames = NULL, choiceValues = NULL) .update_input(session,inputId,selected,label=label,choices=.normalize_choices(choices),inline=inline)
updateRadioButtons <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL, selected = NULL, inline = FALSE, choiceNames = NULL, choiceValues = NULL) .update_input(session,inputId,selected,label=label,choices=.normalize_choices(choices),inline=inline)
updateSelectInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL, selected = NULL) .update_input(session,inputId,selected,label=label,choices=.normalize_choices(choices))
updateSelectizeInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL, selected = NULL, options = list(), server = FALSE) .update_input(session,inputId,selected,label=label,choices=.normalize_choices(choices),options=options)
updateVarSelectInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, data = NULL, selected = NULL) .update_input(session,inputId,selected,label=label,choices=names(data))
updateVarSelectizeInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, data = NULL, selected = NULL, options = list(), server = FALSE) .update_input(session,inputId,selected,label=label,choices=names(data),options=options)
updateDateInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, min = NULL, max = NULL) .update_input(session,inputId,as.character(value),label=label,min=as.character(min),max=as.character(max))
updateDateRangeInput <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, start = NULL, end = NULL, min = NULL, max = NULL) .update_input(session,inputId,c(as.character(start),as.character(end)),label=label,min=as.character(min),max=as.character(max))
updateActionButton <- function(session = getDefaultReactiveDomain(), inputId, label = NULL, icon = NULL, disabled = NULL) .update_input(session,inputId,NULL,label=label,disabled=disabled)
updateActionLink <- updateActionButton

.update_tab <- function(session, inputId, selected) {
  if (!is.null(session) && !is.null(session$sendCommand)) {
    session$sendCommand('selectTab', list(id = inputId, selected = selected))
  }
  if (!is.null(session) && !is.null(session$input) && !is.null(inputId)) session$input[[inputId]] <- selected
  invisible(NULL)
}
updateTabsetPanel <- function(session = getDefaultReactiveDomain(), inputId, selected = NULL) .update_tab(session, inputId, selected)
updateNavbarPage <- updateTabsetPanel
updateNavlistPanel <- updateTabsetPanel

# Native dialogs and notifications.
modalButton <- function(label, icon = NULL) actionButton(paste0('modal_', sample.int(.Machine$integer.max, 1)), label, icon = icon)
modalDialog <- function(..., title = NULL, footer = NULL, size = c('m','s','l','xl'), easyClose = FALSE, fade = TRUE) {
  structure(list(title = title, body = .ui_to_spec(tagList(...)), footer = .ui_to_spec(footer),
                 size = match.arg(size), easyClose = easyClose), class = 'winshiny.modal')
}
showModal <- function(ui, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && !is.null(session$sendCommand)) session$sendCommand('showModal', ui)
  invisible(NULL)
}
removeModal <- function(session = getDefaultReactiveDomain()) {
  if (!is.null(session) && !is.null(session$sendCommand)) session$sendCommand('removeModal', list())
  invisible(NULL)
}
showNotification <- function(ui, action = NULL, duration = 5, closeButton = TRUE,
                             id = NULL, type = c('default','message','warning','error'),
                             session = getDefaultReactiveDomain()) {
  id <- id %||% paste0('notification_', sample.int(.Machine$integer.max, 1))
  if (!is.null(session) && !is.null(session$sendCommand)) {
    session$sendCommand('notification', list(
      id = id, text = .render_ui_text(ui), duration = duration,
      closeButton = closeButton, type = match.arg(type)
    ))
  }
  id
}
removeNotification <- function(id, session = getDefaultReactiveDomain()) invisible(NULL)

# Common lifecycle wrappers.
shinyUI <- function(ui) ui
shinyServer <- function(func) func
onFlush <- function(fun, once = TRUE, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && !is.null(session$onFlush)) session$onFlush(fun, once = once) else invisible(NULL)
}
onFlushed <- function(fun, once = TRUE, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && !is.null(session$onFlushed)) session$onFlushed(fun, once = once) else invisible(NULL)
}
onSessionEnded <- function(fun, session = getDefaultReactiveDomain()) {
  if (!is.null(session) && !is.null(session$onSessionEnded)) session$onSessionEnded(fun) else invisible(NULL)
}
onStop <- onSessionEnded
