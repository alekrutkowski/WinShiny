\name{layouts}
\alias{HTML}
\alias{absolutePanel}
\alias{basicPage}
\alias{bootstrapPage}
\alias{column}
\alias{conditionalPanel}
\alias{fillCol}
\alias{fillPage}
\alias{fillRow}
\alias{fixedPage}
\alias{fixedPanel}
\alias{fixedRow}
\alias{flowLayout}
\alias{fluidPage}
\alias{fluidRow}
\alias{headerPanel}
\alias{helpText}
\alias{htmlTemplate}
\alias{inputPanel}
\alias{mainPanel}
\alias{pageWithSidebar}
\alias{sidebarLayout}
\alias{sidebarPanel}
\alias{splitLayout}
\alias{tagList}
\alias{titlePanel}
\alias{verticalLayout}
\alias{wellPanel}
\title{Pages, panels, rows, and columns}
\description{Compose native WPF pages and layouts using names corresponding to common Shiny layout functions.}
\usage{
HTML(text, ...)

absolutePanel(
  ..., top = NULL, left = NULL, right = NULL, bottom = NULL, width = NULL,
  height = NULL, draggable = FALSE, fixed = FALSE,
  cursor = c('auto','move','default','inherit')
)

basicPage(...)

bootstrapPage(..., title = NULL, theme = NULL, lang = NULL)

column(width, ..., offset = 0)

conditionalPanel(condition, ..., ns = NS(NULL))

fillCol(..., flex = c(1, 1), gap = NULL, class = NULL, height = NULL)

fillPage(..., padding = 0, title = NULL, bootstrap = TRUE, theme = NULL)

fillRow(..., flex = c(1, 1), gap = NULL, class = NULL, height = NULL)

fixedPage(...)

fixedPanel(...)

fixedRow(...)

flowLayout(..., cellArgs = list())

fluidPage(..., title = NULL, theme = NULL, lang = NULL)

fluidRow(...)

headerPanel(title, windowTitle = title)

helpText(...)

htmlTemplate(filename, ..., document_ = 'auto')

inputPanel(..., tag = NULL)

mainPanel(..., width = 8)

pageWithSidebar(headerPanel, sidebarPanel, mainPanel)

sidebarLayout(sidebarPanel, mainPanel, position = c('left','right'), fluid = TRUE)

sidebarPanel(..., width = 4)

splitLayout(..., cellWidths = NULL, cellArgs = list())

tagList(...)

titlePanel(title, windowTitle = title)

verticalLayout(..., fluid = TRUE)

wellPanel(...)
}
\arguments{
  \item{text}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{...}{Additional arguments passed to the constructor, renderer, handler, or compatibility helper.}
  \item{top}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{left}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{right}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{bottom}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{width}{Width request; interpretation depends on the native control.}
  \item{height}{Height request.}
  \item{draggable}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{fixed}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{cursor}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{title}{Title text.}
  \item{theme}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{lang}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{offset}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{condition}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{ns}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{flex}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{gap}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{class}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{padding}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{bootstrap}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{cellArgs}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{windowTitle}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{filename}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{document_}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{tag}{WinShiny tag object.}
  \item{headerPanel}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{sidebarPanel}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{mainPanel}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{position}{Position option.}
  \item{fluid}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{cellWidths}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
}
\details{Grid and column widths are interpreted as WPF proportional grid units. HTML/CSS semantics are approximated where a direct native equivalent does not exist.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}
