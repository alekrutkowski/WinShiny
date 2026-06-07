\name{application}
\alias{as.shiny.appobj}
\alias{is.shiny.appobj}
\alias{isRunning}
\alias{onFlush}
\alias{onFlushed}
\alias{onSessionEnded}
\alias{onStop}
\alias{runApp}
\alias{runExample}
\alias{shinyApp}
\alias{shinyServer}
\alias{shinyUI}
\alias{stopApp}
\title{Application objects and lifecycle}
\description{Create, run, inspect, and stop WinShiny applications and register lifecycle callbacks.}
\usage{
as.shiny.appobj(x)

is.shiny.appobj(x)

isRunning()

onFlush(fun, once = TRUE, session = getDefaultReactiveDomain())

onFlushed(fun, once = TRUE, session = getDefaultReactiveDomain())

onSessionEnded(fun, session = getDefaultReactiveDomain())

onStop(fun, session = getDefaultReactiveDomain())

runApp(
  appDir = getwd(), port = getOption('shiny.port'),
  launch.browser = getOption('shiny.launch.browser', interactive()),
  host = getOption('shiny.host','127.0.0.1'), workerId = '', quiet = FALSE,
  display.mode = c('auto','normal','showcase'),
  test.mode = getOption('shiny.testmode', FALSE), app = NULL, wait = TRUE,
  startupTimeout = 8, ...
)

runExample(
  example = NA, port = getOption('shiny.port'),
  launch.browser = getOption('shiny.launch.browser', interactive()),
  host = getOption('shiny.host', '127.0.0.1'),
  display.mode = c('auto', 'normal', 'showcase')
)

shinyApp(
  ui, server, onStart = NULL, options = list(), uiPattern = '/',
  enableBookmarking = NULL
)

shinyServer(func)

shinyUI(ui)

stopApp(returnValue = invisible())
}
\arguments{
  \item{x}{Object or expression.}
  \item{fun}{Function.}
  \item{once}{Whether the observer runs once.}
  \item{session}{Active WinShiny session; defaults to the current reactive domain.}
  \item{appDir}{WinShiny app object or compatibility app location.}
  \item{port}{Compatibility port option; no HTTP listener is created.}
  \item{launch.browser}{Compatibility option; WinShiny opens a WPF window instead.}
  \item{host}{Compatibility host option; no HTTP listener is created.}
  \item{workerId}{Compatibility worker identifier.}
  \item{quiet}{Whether startup messages are suppressed.}
  \item{display.mode}{Compatibility display mode.}
  \item{test.mode}{Compatibility test-mode flag.}
  \item{app}{Explicit WinShiny app object.}
  \item{wait}{Whether the call waits for the WPF window to close.}
  \item{startupTimeout}{PowerShell host startup timeout in seconds.}
  \item{...}{Additional arguments passed to the constructor, renderer, handler, or compatibility helper.}
  \item{example}{Installed example name.}
  \item{ui}{UI object or native UI description.}
  \item{server}{Server function or server-related option.}
  \item{onStart}{Optional function run before the application starts.}
  \item{options}{Application options list.}
  \item{uiPattern}{Compatibility UI route pattern.}
  \item{enableBookmarking}{Bookmarking compatibility option.}
  \item{func}{Function.}
  \item{returnValue}{Value returned when stopping an application.}
}
\details{Unlike browser Shiny, \code{runApp()} launches a native WPF window and normally occupies the calling R session while it processes GUI events.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}
