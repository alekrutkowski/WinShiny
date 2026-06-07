\name{navigation}
\alias{NS}
\alias{callModule}
\alias{moduleServer}
\alias{navbarMenu}
\alias{navbarPage}
\alias{navlistPanel}
\alias{ns.sep}
\alias{tabPanel}
\alias{tabPanelBody}
\alias{tabsetPanel}
\alias{updateNavbarPage}
\alias{updateNavlistPanel}
\alias{updateTabsetPanel}
\title{Navigation and modules}
\description{Create tabbed and navbar-style navigation, update the selected tab, and namespace module IDs.}
\usage{
NS(namespace, id = NULL)

callModule(module, id, ..., session = getDefaultReactiveDomain())

moduleServer(id, module, session = getDefaultReactiveDomain())

navbarMenu(title, ..., icon = NULL)

navbarPage(
  title, ..., id = NULL, selected = NULL,
  position = c('static-top', 'fixed-top', 'fixed-bottom'), header = NULL, footer = NULL,
  inverse = FALSE, collapsible = FALSE, fluid = TRUE, theme = NULL, windowTitle = title,
  lang = NULL
)

navlistPanel(
  ..., id = NULL, selected = NULL, well = TRUE, fluid = TRUE, widths = c(4, 8)
)

ns.sep

tabPanel(title, ..., value = title, icon = NULL)

tabPanelBody(value, ..., icon = NULL)

tabsetPanel(
  ..., id = NULL, selected = NULL, type = c('tabs', 'pills', 'hidden'), header = NULL,
  footer = NULL
)

updateNavbarPage(session = getDefaultReactiveDomain(), inputId, selected = NULL)

updateNavlistPanel(session = getDefaultReactiveDomain(), inputId, selected = NULL)

updateTabsetPanel(session = getDefaultReactiveDomain(), inputId, selected = NULL)
}
\arguments{
  \item{namespace}{Namespace string.}
  \item{id}{Identifier or namespace component.}
  \item{module}{Module server function.}
  \item{...}{Additional arguments passed to the constructor, renderer, handler, or compatibility helper.}
  \item{session}{Active WinShiny session; defaults to the current reactive domain.}
  \item{title}{Title text.}
  \item{icon}{Optional icon descriptor.}
  \item{selected}{Selected value or values.}
  \item{position}{Position option.}
  \item{header}{Optional header content or header-detection setting.}
  \item{footer}{Optional footer content.}
  \item{inverse}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{collapsible}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{fluid}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{theme}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{windowTitle}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{lang}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{well}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{widths}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{value}{Initial or updated value.}
  \item{type}{Type or style selector.}
  \item{inputId}{Character input identifier.}
}
\details{Navigation is implemented with native WPF TabControl and TabItem controls. Modules follow the conventional Shiny ID namespace separator.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}
