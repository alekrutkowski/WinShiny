\name{outputs}
\alias{createRenderFunction}
\alias{dataTableOutput}
\alias{downloadButton}
\alias{downloadHandler}
\alias{downloadLink}
\alias{getCurrentOutputInfo}
\alias{htmlOutput}
\alias{imageOutput}
\alias{markRenderFunction}
\alias{outputOptions}
\alias{plotOutput}
\alias{renderCachedPlot}
\alias{renderDataTable}
\alias{renderImage}
\alias{renderPlot}
\alias{renderPrint}
\alias{renderTable}
\alias{renderText}
\alias{renderUI}
\alias{tableOutput}
\alias{textOutput}
\alias{uiOutput}
\alias{verbatimTextOutput}
\title{Output controls and render functions}
\description{Declare text, plot, image, table, dynamic UI, and download outputs and create their server-side renderers.}
\usage{
createRenderFunction(
  func, transform = function(value, session, name, ...) value, outputFunc = NULL,
  outputArgs = NULL, cacheHint = 'auto', cacheWriteHook = NULL, cacheReadHook = NULL
)

dataTableOutput(outputId, width = '100\%', height = 'auto', fill = FALSE)

downloadButton(outputId, label = 'Download', class = NULL, ...)

downloadHandler(filename, content, contentType = NA, outputArgs = list())

downloadLink(outputId, label = 'Download', class = NULL, ...)

getCurrentOutputInfo(session = getDefaultReactiveDomain())

htmlOutput(
  outputId, inline = FALSE, container = if (inline) tags$span else tags$div, ...
)

imageOutput(
  outputId, width = '100\%', height = '400px', click = NULL, dblclick = NULL,
  hover = NULL, brush = NULL, inline = FALSE
)

markRenderFunction(uiFunc, renderFunc, outputArgs = list(), cacheHint = 'auto')

outputOptions(x, name, ...)

plotOutput(
  outputId, width = '100\%', height = '400px', inline = FALSE, click = NULL,
  dblclick = NULL, hover = NULL, brush = NULL, hoverDelay = NULL, hoverDelayType = NULL,
  brushDelay = NULL, brushDelayType = NULL, dblclickDelay = NULL
)

renderCachedPlot(
  expr, width = 'auto', height = 'auto', res = 96, ..., alt = NA, env = parent.frame(),
  quoted = FALSE, execOnResize = TRUE, outputArgs = list()
)

renderDataTable(
  expr, options = NULL, searchDelay = 500, callback = 'function(oTable) {}',
  escape = TRUE, env = parent.frame(), quoted = FALSE, outputArgs = list()
)

renderImage(
  expr, env = parent.frame(), quoted = FALSE, deleteFile = TRUE, outputArgs = list()
)

renderPlot(
  expr, width = 'auto', height = 'auto', res = 96, ..., alt = NA, env = parent.frame(),
  quoted = FALSE, execOnResize = TRUE, outputArgs = list()
)

renderPrint(
  expr, env = parent.frame(), quoted = FALSE, outputArgs = list(),
  width = getOption('width')
)

renderTable(
  expr, striped = FALSE, hover = FALSE, bordered = FALSE, spacing = c('s','xs','m','l'),
  width = 'auto', align = NULL, rownames = FALSE, colnames = TRUE, digits = NULL,
  na = 'NA', ..., env = parent.frame(), quoted = FALSE, outputArgs = list()
)

renderText(expr, env = parent.frame(), quoted = FALSE, outputArgs = list(), sep = ' ')

renderUI(expr, env = parent.frame(), quoted = FALSE, outputArgs = list())

tableOutput(outputId, height = NULL, fill = FALSE)

textOutput(outputId, container = if (inline) tags$span else tags$div, inline = FALSE)

uiOutput(outputId, inline = FALSE, container = if (inline) tags$span else tags$div, ...)

verbatimTextOutput(outputId, placeholder = FALSE)
}
\arguments{
  \item{func}{Function.}
  \item{transform}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{outputFunc}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{outputArgs}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{cacheHint}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{cacheWriteHook}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{cacheReadHook}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{outputId}{Character output identifier.}
  \item{width}{Width request; interpretation depends on the native control.}
  \item{height}{Height request.}
  \item{fill}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{label}{Human-readable label.}
  \item{class}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{...}{Additional arguments passed to the constructor, renderer, handler, or compatibility helper.}
  \item{filename}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{content}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{contentType}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{session}{Active WinShiny session; defaults to the current reactive domain.}
  \item{inline}{Whether controls should be arranged inline.}
  \item{container}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{click}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{dblclick}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{hover}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{brush}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{uiFunc}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{renderFunc}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{x}{Object or expression.}
  \item{name}{Name of an option, attribute, symbol, or resource.}
  \item{hoverDelay}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{hoverDelayType}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{brushDelay}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{brushDelayType}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{dblclickDelay}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{expr}{R expression to evaluate.}
  \item{res}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{alt}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{env}{Evaluation environment.}
  \item{quoted}{Whether an expression was supplied already quoted.}
  \item{execOnResize}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{options}{Application options list.}
  \item{searchDelay}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{callback}{Callback function.}
  \item{escape}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{deleteFile}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{striped}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{bordered}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{spacing}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{align}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{rownames}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{colnames}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{digits}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{na}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{sep}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{placeholder}{Placeholder text.}
}
\details{Plots are rendered to PNG by R and displayed in a WPF image control. Responsive plots are rerendered with the current output width and height. Tables use a native WPF DataGrid. Downloads open a Windows save dialog and write directly to the selected local path. Use \code{writeDocxTable()} inside a download handler to export one or more data-frame tables to a standard Word \code{.docx} file without additional R packages. A plot renderer can be reused by a \code{downloadHandler()} so the exported PNG is generated from the same expression as the on-screen plot. For a close visual match, obtain the current dimensions with \code{session$getPlotSize()}, multiply both dimensions and the renderer resolution by the same factor, and pass the resulting values as \code{width_px}, \code{height_px}, and \code{res_px}. This preserves the displayed aspect ratio and relative text sizing while increasing output definition.}
\value{UI constructors return WinShiny UI objects; render functions return renderer functions suitable for assignment to \code{output}.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}

\examples{
\dontrun{
ui <- fluidPage(
  plotOutput("p"),
  downloadButton("save_plot", "Export plot PNG")
)
server <- function(input, output, session) {
  plot_renderer <- renderPlot(plot(cars))
  output$p <- plot_renderer
  output$save_plot <- downloadHandler(
    filename = "cars.png",
    content = function(file) {
      size <- isolate(session$getPlotSize("p"))
      scale <- 300 / 96
      plot_renderer(
        file = file,
        width_px = round(size$width * scale),
        height_px = round(size$height * scale),
        res_px = 300,
        theme = session$getTheme()
      )
    },
    contentType = "image/png"
  )
}
runApp(shinyApp(ui, server))
}
}
