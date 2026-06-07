\name{compatibility}
\alias{animationOptions}
\alias{brushOpts}
\alias{clickOpts}
\alias{dblclickOpts}
\alias{exprToFunction}
\alias{getCurrentTheme}
\alias{getQueryString}
\alias{getShinyOption}
\alias{getUrlHash}
\alias{hoverOpts}
\alias{installExprFunction}
\alias{isTruthy}
\alias{need}
\alias{parseQueryString}
\alias{printError}
\alias{quoToFunction}
\alias{repeatable}
\alias{safeError}
\alias{serverInfo}
\alias{shinyOptions}
\alias{validate}
\alias{validateCssUnit}
\alias{withLogErrors}
\alias{winShinyCapabilities}
\title{Additional Shiny compatibility helpers}
\usage{
animationOptions(interval = 1000, loop = TRUE, playButton = NULL, pauseButton = NULL)

brushOpts(
  id, fill = '#9cf', stroke = '#036', opacity = 0.25, delay = 300,
  delayType = c('debounce', 'throttle'), clip = TRUE, direction = c('xy', 'x', 'y'),
  resetOnNew = FALSE
)

clickOpts(id, clip = TRUE, nullOutside = FALSE)

dblclickOpts(id, clip = TRUE, nullOutside = FALSE)

exprToFunction(expr, env = parent.frame(), quoted = FALSE)

getCurrentTheme(session = getDefaultReactiveDomain())

getQueryString(session = getDefaultReactiveDomain())

getShinyOption(name, default = NULL)

getUrlHash(session = getDefaultReactiveDomain())

hoverOpts(
  id, delay = 300, delayType = c('debounce', 'throttle'), clip = TRUE,
  nullOutside = FALSE
)

installExprFunction(
  expr, name, eval.env = parent.frame(), quoted = FALSE, assign.env = parent.frame(),
  label = sys.call(-1)[[1]], wrappedWithLabel = TRUE, ..stacktraceon = FALSE
)

isTruthy(x)

need(expr, message = paste(label, 'must be provided'), label)

parseQueryString(str, nested = FALSE)

printError(cond)

quoToFunction(q, label = NULL, domain = getDefaultReactiveDomain())

repeatable(rngfunc, seed = stats::runif(1, 0, .Machine$integer.max))

safeError(error)

serverInfo()

shinyOptions(...)

validate(..., errorClass = character())

validateCssUnit(x)

withLogErrors(expr, full = getOption('shiny.fullstacktrace', FALSE), offset = 0)

winShinyCapabilities(status = NULL)
}
\arguments{
  \item{interval}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{loop}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{playButton}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{pauseButton}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{id}{Identifier or namespace component.}
  \item{fill}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{stroke}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{opacity}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{delay}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{delayType}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{clip}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{direction}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{resetOnNew}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{nullOutside}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{expr}{R expression to evaluate.}
  \item{env}{Evaluation environment.}
  \item{quoted}{Whether an expression was supplied already quoted.}
  \item{session}{Active WinShiny session; defaults to the current reactive domain.}
  \item{name}{Name of an option, attribute, symbol, or resource.}
  \item{default}{Fallback value.}
  \item{eval.env}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{assign.env}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{label}{Human-readable label.}
  \item{wrappedWithLabel}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{..stacktraceon}{Compatibility or internal-style argument retained in the public call signature.}
  \item{x}{Object or expression.}
  \item{message}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{str}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{nested}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{cond}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{q}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{domain}{Reactive domain.}
  \item{rngfunc}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{seed}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{error}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{...}{Additional arguments passed to the constructor, renderer, handler, or compatibility helper.}
  \item{errorClass}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{full}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{offset}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{status}{Optional compatibility-status filter.}
}
\description{Additional exported helpers retained to reduce source changes when adapting Shiny applications to WinShiny.}
\details{Some functions are complete utility implementations, while others are partial compatibility shims or no-ops where the original behavior is inseparable from a browser, HTTP request, CSS, JavaScript, promises, or websocket session. Consult the package README and \code{winShinyCapabilities()} for current status.}
\value{\code{winShinyCapabilities()} returns the installed Shiny API compatibility table, optionally filtered by status. Other helpers return values described by their corresponding Shiny APIs or documented compatibility behavior.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}
