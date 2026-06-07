\name{dialogs}
\alias{modalButton}
\alias{modalDialog}
\alias{removeModal}
\alias{removeNotification}
\alias{showModal}
\alias{showNotification}
\title{Dialogs and notifications}
\description{Show and remove native modal dialogs and notifications.}
\usage{
modalButton(label, icon = NULL)

modalDialog(
  ..., title = NULL, footer = modalButton('Dismiss'), size = c('m', 's', 'l', 'xl'),
  easyClose = FALSE, fade = TRUE
)

removeModal(session = getDefaultReactiveDomain())

removeNotification(id, session = getDefaultReactiveDomain())

showModal(ui, session = getDefaultReactiveDomain())

showNotification(
  ui, action = NULL, duration = 5, closeButton = TRUE, id = NULL,
  type = c('default', 'message', 'warning', 'error'),
  session = getDefaultReactiveDomain()
)
}
\arguments{
  \item{label}{Human-readable label.}
  \item{icon}{Optional icon descriptor.}
  \item{...}{Additional arguments passed to the constructor, renderer, handler, or compatibility helper.}
  \item{title}{Title text.}
  \item{footer}{Optional footer content.}
  \item{size}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{easyClose}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{fade}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{session}{Active WinShiny session; defaults to the current reactive domain.}
  \item{id}{Identifier or namespace component.}
  \item{ui}{UI object or native UI description.}
  \item{action}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{duration}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{closeButton}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{type}{Type or style selector.}
}
\details{These functions use native Windows dialogs. Appearance and timing differ from browser Shiny notifications and Bootstrap modals.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}
