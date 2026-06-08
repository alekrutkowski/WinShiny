\name{inputs}
\alias{actionButton}
\alias{actionLink}
\alias{checkboxGroupInput}
\alias{clipboardButton}
\alias{copyTableButton}
\alias{copyPlotButton}
\alias{checkboxInput}
\alias{dateInput}
\alias{dateRangeInput}
\alias{fileInput}
\alias{numericInput}
\alias{passwordInput}
\alias{radioButtons}
\alias{selectInput}
\alias{selectizeInput}
\alias{sliderInput}
\alias{submitButton}
\alias{textAreaInput}
\alias{textInput}
\alias{themeToggle}
\alias{varSelectInput}
\alias{varSelectizeInput}
\alias{winThemeToggle}
\title{Native input controls}
\description{Construct native WPF text, numeric, slider, date, checkbox, selection, file, action, clipboard, and theme controls.}
\usage{
actionButton(inputId, label, icon = NULL, width = NULL, disabled = FALSE, ...)

actionLink(inputId, label, icon = NULL, width = NULL, ...)

checkboxGroupInput(
  inputId, label, choices = NULL, selected = NULL, inline = FALSE, width = NULL,
  choiceNames = NULL, choiceValues = NULL
)

clipboardButton(
  inputId, label = 'Import table from clipboard', icon = NULL, width = NULL,
  disabled = FALSE, ...
)

copyTableButton(
  inputId, label = 'Copy tables to clipboard', outputIds, title = NULL, subtitle = NULL,
  notes = NULL, width = NULL, ...
)

copyPlotButton(inputId, label = 'Copy plot to clipboard', outputId, width = NULL, ...)

checkboxInput(inputId, label, value = FALSE, width = NULL)

dateInput(
  inputId, label, value = NULL, min = NULL, max = NULL, format = 'yyyy-mm-dd',
  startview = 'month', weekstart = 0, language = 'en', width = NULL, autoclose = TRUE,
  datesdisabled = NULL, daysofweekdisabled = NULL
)

dateRangeInput(
  inputId, label, start = NULL, end = NULL, min = NULL, max = NULL,
  format = 'yyyy-mm-dd', startview = 'month', weekstart = 0, language = 'en',
  separator = ' to ', width = NULL, autoclose = TRUE
)

fileInput(
  inputId, label, multiple = FALSE, accept = NULL, width = NULL,
  buttonLabel = 'Browse...', placeholder = 'No file selected'
)

numericInput(inputId, label, value, min = NA, max = NA, step = NA, width = NULL)

passwordInput(inputId, label, value = '', width = NULL, placeholder = NULL)

radioButtons(
  inputId, label, choices = NULL, selected = NULL, inline = FALSE, width = NULL,
  choiceNames = NULL, choiceValues = NULL
)

selectInput(
  inputId, label, choices, selected = NULL, multiple = FALSE, selectize = TRUE,
  width = NULL, size = NULL
)

selectizeInput(inputId, ..., options = NULL, width = NULL)

sliderInput(
  inputId, label, min, max, value, step = NULL, round = FALSE, ticks = TRUE,
  animate = FALSE, width = NULL, sep = ',', pre = NULL, post = NULL, timeFormat = NULL,
  timezone = NULL, dragRange = TRUE
)

submitButton(text = 'Apply Changes', icon = NULL, width = NULL)

textAreaInput(
  inputId, label, value = '', width = NULL, height = NULL, cols = NULL, rows = NULL,
  placeholder = NULL, resize = NULL
)

textInput(inputId, label, value = '', width = NULL, placeholder = NULL)

themeToggle(
  inputId = 'winshiny_theme', label = 'Dark mode', value = FALSE, width = NULL
)

varSelectInput(
  inputId, label, data, selected = NULL, multiple = FALSE, selectize = TRUE,
  width = NULL, size = NULL
)

varSelectizeInput(inputId, ..., options = NULL, width = NULL)

winThemeToggle(
  inputId = 'winshiny_theme', label = 'Dark mode', value = FALSE, width = NULL
)
}
\arguments{
  \item{inputId}{Character input identifier.}
  \item{label}{Human-readable label.}
  \item{icon}{Optional icon descriptor.}
  \item{width}{Width request; interpretation depends on the native control.}
  \item{disabled}{Whether the control starts disabled.}
  \item{...}{Additional arguments passed to the constructor, renderer, handler, or compatibility helper.}
  \item{choices}{Available choices.}
  \item{selected}{Selected value or values.}
  \item{inline}{Whether controls should be arranged inline.}
  \item{choiceNames}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{choiceValues}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{outputIds}{Character vector of displayed output identifiers to copy.}
  \item{title}{Title text.}
  \item{subtitle}{Subtitle text.}
  \item{notes}{Optional notes.}
  \item{outputId}{Character output identifier.}
  \item{value}{Initial or updated value.}
  \item{min}{Minimum value.}
  \item{max}{Maximum value.}
  \item{format}{Displayed date format. Common Shiny patterns such as \code{yyyy-mm-dd}, \code{dd/mm/yyyy}, and \code{mm/dd/yyyy} are translated to the native WPF date picker. Values sent to R remain ISO \code{yyyy-mm-dd}.}
  \item{startview}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{weekstart}{First day of the calendar week: use 0 for Sunday or 1 for Monday.}
  \item{language}{Culture tag used for date entry and calendar localization, for example \code{en-GB}, \code{pl-PL}, or \code{en-US}. A suitable culture is inferred from common numeric formats when a generic language such as \code{en} is supplied.}
  \item{autoclose}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{datesdisabled}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{daysofweekdisabled}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{start}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{end}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{separator}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{multiple}{Whether multiple selection is allowed.}
  \item{accept}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{buttonLabel}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{placeholder}{Placeholder text.}
  \item{step}{Step or tick interval.}
  \item{selectize}{If true, use an inline searchable native PowerShell/WPF control with removable selection chips and a filtered choice list; if false, use the original native ComboBox or ListBox.}
  \item{size}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{options}{Application options list.}
  \item{round}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{ticks}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{animate}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{sep}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{pre}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{post}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{timeFormat}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{timezone}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{dragRange}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{text}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{height}{Height request.}
  \item{cols}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{rows}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{resize}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{data}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
}
\details{Input IDs and values are exposed through the server \code{input} object. For \code{selectInput(..., selectize = TRUE)}, \code{varSelectInput(..., selectize = TRUE)}, \code{selectizeInput()}, and \code{varSelectizeInput()}, the native PowerShell/WPF interface is embedded directly in the main application window. Selected values are displayed as removable chips inside the input field, typing filters the choice list immediately below the field, and mouse or keyboard selection updates the input without opening a separate window. Single and multiple selection, initial values, live input updates, and light or dark styling are supported. The \code{placeholder} member of \code{options} supplies the field prompt; Selectize.js plugins, remote loading, and arbitrary JavaScript are not reproduced. With \code{selectize = FALSE}, single selection uses the original native WPF \code{ComboBox}; \code{multiple = TRUE} uses a native multi-selection \code{ListBox} and returns a character vector, while \code{size} controls the approximate number of visible rows. Date controls honor common numeric \code{format} patterns in their displayed text while continuing to expose ISO date strings to R. For European display use \code{format = "dd/mm/yyyy"}, \code{language = "en-GB"} (or another day-first culture), and typically \code{weekstart = 1}. \code{clipboardButton()} reads Unicode clipboard text on the WPF STA thread, writes it to a temporary UTF-8 transfer file, and sends only the file path through the ordinary scalar event channel. R reads and removes the file before exposing the clipboard text as \code{input$inputId}. \code{copyTableButton()} copies displayed WPF DataGrid outputs as Word-compatible HTML and Unicode tab-separated text. \code{copyPlotButton()} copies the displayed WPF bitmap. Successful copies are silent; failures display a native error dialog. \code{themeToggle()} is WinShiny-specific and applies light or dark styling to the WPF window and plot renderer.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}
