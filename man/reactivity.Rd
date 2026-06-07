\name{reactivity}
\alias{bindEvent}
\alias{debounce}
\alias{eventReactive}
\alias{flushReact}
\alias{freezeReactiveVal}
\alias{freezeReactiveValue}
\alias{getDefaultReactiveDomain}
\alias{invalidateLater}
\alias{is.reactive}
\alias{is.reactivevalues}
\alias{isolate}
\alias{makeReactiveBinding}
\alias{observe}
\alias{observeEvent}
\alias{onReactiveDomainEnded}
\alias{reactive}
\alias{reactiveFileReader}
\alias{reactivePoll}
\alias{reactiveTimer}
\alias{reactiveVal}
\alias{reactiveValues}
\alias{reactiveValuesToList}
\alias{req}
\alias{throttle}
\alias{withReactiveDomain}
\title{Reactive programming}
\description{Reactive values, expressions, observers, event binding, timers, and reactive-domain helpers.}
\usage{
bindEvent(x, ..., ignoreNULL = TRUE, ignoreInit = FALSE, once = FALSE, label = NULL)

debounce(r, millis, priority = 100, domain = getDefaultReactiveDomain())

eventReactive(
  eventExpr, valueExpr, event.env = parent.frame(), event.quoted = FALSE,
  value.env = parent.frame(), value.quoted = FALSE, ..., label = NULL,
  domain = getDefaultReactiveDomain(), ignoreNULL = TRUE, ignoreInit = FALSE
)

flushReact()

freezeReactiveVal(x)

freezeReactiveValue(x, name)

getDefaultReactiveDomain()

invalidateLater(millis, session = getDefaultReactiveDomain())

is.reactive(x)

is.reactivevalues(x)

isolate(expr)

makeReactiveBinding(symbol, env = parent.frame())

observe(
  x, env = parent.frame(), quoted = FALSE, ..., label = NULL, suspended = FALSE,
  priority = 0, domain = getDefaultReactiveDomain(), autoDestroy = TRUE
)

observeEvent(
  eventExpr, handlerExpr, event.env = parent.frame(), event.quoted = FALSE,
  handler.env = parent.frame(), handler.quoted = FALSE, ..., label = NULL,
  suspended = FALSE, priority = 0, domain = getDefaultReactiveDomain(),
  autoDestroy = TRUE, ignoreNULL = TRUE, ignoreInit = FALSE, once = FALSE
)

onReactiveDomainEnded(domain, callback, failIfNull = FALSE)

reactive(
  x, env = parent.frame(), quoted = FALSE, ..., label = NULL,
  domain = getDefaultReactiveDomain()
)

reactiveFileReader(intervalMillis, session, filePath, readFunc, ...)

reactivePoll(intervalMillis, session, checkFunc, valueFunc)

reactiveTimer(intervalMs = 1000, session = getDefaultReactiveDomain())

reactiveVal(value = NULL, label = NULL)

reactiveValues(...)

reactiveValuesToList(x, all.names = FALSE)

req(..., cancelOutput = FALSE)

throttle(r, millis, priority = 100, domain = getDefaultReactiveDomain())

withReactiveDomain(domain, expr)
}
\arguments{
  \item{x}{Object or expression.}
  \item{...}{Additional arguments passed to the constructor, renderer, handler, or compatibility helper.}
  \item{ignoreNULL}{Whether null-like event values are ignored.}
  \item{ignoreInit}{Whether the initial event is ignored.}
  \item{once}{Whether the observer runs once.}
  \item{label}{Human-readable label.}
  \item{r}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{millis}{Delay in milliseconds.}
  \item{priority}{Observer or scheduler priority.}
  \item{domain}{Reactive domain.}
  \item{eventExpr}{Reactive event expression.}
  \item{valueExpr}{Value expression.}
  \item{event.env}{Environment for the event expression.}
  \item{event.quoted}{Whether the event expression is quoted.}
  \item{value.env}{Environment for the value expression.}
  \item{value.quoted}{Whether the value expression is quoted.}
  \item{name}{Name of an option, attribute, symbol, or resource.}
  \item{session}{Active WinShiny session; defaults to the current reactive domain.}
  \item{expr}{R expression to evaluate.}
  \item{symbol}{Name of a binding.}
  \item{env}{Evaluation environment.}
  \item{quoted}{Whether an expression was supplied already quoted.}
  \item{suspended}{Whether an observer starts suspended.}
  \item{autoDestroy}{Whether an observer is destroyed with its domain.}
  \item{handlerExpr}{Handler expression.}
  \item{handler.env}{Environment for the handler expression.}
  \item{handler.quoted}{Whether the handler expression is quoted.}
  \item{callback}{Callback function.}
  \item{failIfNull}{Whether a missing domain is an error.}
  \item{intervalMillis}{Interval in milliseconds.}
  \item{filePath}{File path or a function returning one.}
  \item{readFunc}{Function used to read a file.}
  \item{checkFunc}{Function returning a change token.}
  \item{valueFunc}{Function returning the current value.}
  \item{intervalMs}{Interval in milliseconds.}
  \item{value}{Initial or updated value.}
  \item{all.names}{Whether names beginning with a dot are included.}
  \item{cancelOutput}{Compatibility flag controlling output cancellation.}
}
\details{The API follows Shiny terminology. The current scheduler is a compact native implementation and does not reproduce every priority, async, promise, or reactive-log detail of Shiny.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}
