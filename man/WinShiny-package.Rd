\name{WinShiny-package}
\alias{WinShiny}
\alias{WinShiny-package}
\docType{package}
\title{WinShiny: native Windows GUI applications from Shiny-style R code}
\description{WinShiny is an experimental native Windows GUI backend. It preserves familiar Shiny-style application, reactivity, input, output, layout, module, and session APIs while rendering controls with PowerShell and WPF instead of HTML and a web browser.}
\details{Use \code{shinyApp()} and \code{runApp()} to launch an application. The implementation is intentionally compatible with common Shiny code, but browser-only HTML, JavaScript, CSS, websocket, and htmlwidget behavior is not equivalent. The native WPF window uses the default PowerShell/WPF host icon. WinShiny provides direct WPF clipboard controls for importing Excel, CSV, or TSV text and copying displayed tables or plots.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{package}
