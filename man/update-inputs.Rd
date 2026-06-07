\name{update-inputs}
\alias{registerInputHandler}
\alias{removeInputHandler}
\alias{restoreInput}
\alias{snapshotPreprocessInput}
\alias{snapshotPreprocessOutput}
\alias{updateActionButton}
\alias{updateActionLink}
\alias{updateCheckboxGroupInput}
\alias{updateCheckboxInput}
\alias{updateDateInput}
\alias{updateDateRangeInput}
\alias{updateNumericInput}
\alias{updateQueryString}
\alias{updateRadioButtons}
\alias{updateSelectInput}
\alias{updateSelectizeInput}
\alias{updateSliderInput}
\alias{updateTextAreaInput}
\alias{updateTextInput}
\alias{updateVarSelectInput}
\alias{updateVarSelectizeInput}
\title{Update native controls}
\description{Send updates from the server to existing native input and navigation controls.}
\usage{
registerInputHandler(type, fun, force = FALSE)

removeInputHandler(type)

restoreInput(id, default)

snapshotPreprocessInput(inputId, func)

snapshotPreprocessOutput(outputId, func)

updateActionButton(
  session = getDefaultReactiveDomain(), inputId, label = NULL, icon = NULL,
  disabled = NULL
)

updateActionLink(
  session = getDefaultReactiveDomain(), inputId, label = NULL, icon = NULL,
  disabled = NULL
)

updateCheckboxGroupInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL,
  selected = NULL, inline = FALSE, choiceNames = NULL, choiceValues = NULL
)

updateCheckboxInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL
)

updateDateInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, min = NULL,
  max = NULL
)

updateDateRangeInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, start = NULL, end = NULL,
  min = NULL, max = NULL
)

updateNumericInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, min = NULL,
  max = NULL, step = NULL
)

updateQueryString(
  queryString, mode = c('replace', 'push'), session = getDefaultReactiveDomain()
)

updateRadioButtons(
  session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL,
  selected = NULL, inline = FALSE, choiceNames = NULL, choiceValues = NULL
)

updateSelectInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL,
  selected = NULL
)

updateSelectizeInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, choices = NULL,
  selected = NULL, options = list(), server = FALSE
)

updateSliderInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL, min = NULL,
  max = NULL, step = NULL, timeFormat = NULL, timezone = NULL
)

updateTextAreaInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL,
  placeholder = NULL
)

updateTextInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, value = NULL,
  placeholder = NULL
)

updateVarSelectInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, data = NULL,
  selected = NULL
)

updateVarSelectizeInput(
  session = getDefaultReactiveDomain(), inputId, label = NULL, data = NULL,
  selected = NULL, options = list(), server = FALSE
)
}
\arguments{
  \item{type}{Type or style selector.}
  \item{fun}{Function.}
  \item{force}{Whether an existing registration is replaced.}
  \item{id}{Identifier or namespace component.}
  \item{default}{Fallback value.}
  \item{inputId}{Character input identifier.}
  \item{func}{Function.}
  \item{outputId}{Character output identifier.}
  \item{session}{Active WinShiny session; defaults to the current reactive domain.}
  \item{label}{Human-readable label.}
  \item{icon}{Optional icon descriptor.}
  \item{disabled}{Whether the control starts disabled.}
  \item{choices}{Available choices.}
  \item{selected}{Selected value or values.}
  \item{inline}{Whether controls should be arranged inline.}
  \item{choiceNames}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{choiceValues}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{value}{Initial or updated value.}
  \item{min}{Minimum value.}
  \item{max}{Maximum value.}
  \item{start}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{end}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{step}{Step or tick interval.}
  \item{queryString}{Query-string text.}
  \item{mode}{Operation mode.}
  \item{options}{Application options list.}
  \item{server}{Server function or server-related option.}
  \item{timeFormat}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{timezone}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{placeholder}{Placeholder text.}
  \item{data}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
}
\details{Messages are translated into WPF property changes. Browser-specific client messages and selectize JavaScript options are only partially applicable.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}
