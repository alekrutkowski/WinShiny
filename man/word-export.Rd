\name{writeDocxTable}
\alias{writeDocxTable}
\title{Write native table output to a Word document}
\description{Create a standards-based Office Open XML \code{.docx} document containing one or more data-frame tables. The helper is a WinShiny extension and does not require \pkg{officer}, \pkg{flextable}, or Microsoft Word automation.}
\usage{
writeDocxTable(x, file, title = NULL, subtitle = NULL,
  notes = NULL, digits = 3L)
}
\arguments{
  \item{x}{A data frame or a named, non-empty list of data frames. List names become table headings.}
  \item{file}{Destination path ending in \code{.docx}.}
  \item{title}{Optional document title.}
  \item{subtitle}{Optional paragraph placed below the title.}
  \item{notes}{Optional character vector written after the tables.}
  \item{digits}{Significant digits used when formatting numeric cells.}
}
\details{The document is written directly as WordprocessingML and packaged with the PowerShell/.NET compression runtime already used by WinShiny. In a WinShiny app, call this function from the \code{content} function of \code{downloadHandler()} and use the Office Open XML Word MIME type.}
\value{The normalized output path, invisibly.}
\seealso{\code{downloadHandler()}, \code{renderTable()}, and \code{copyWordTable()}.}
\keyword{utilities}
\examples{
\dontrun{
writeDocxTable(
  list(
    Coefficients = data.frame(term = c("(Intercept)", "x"), estimate = c(1, 2)),
    `Model statistics` = data.frame(statistic = "R-squared", value = 0.75)
  ),
  "model.docx",
  title = "Regression model"
)
}
}
