\name{readClipboardTable}
\alias{readClipboardTable}
\alias{parseClipboardTable}
\alias{copyTableToClipboard}
\alias{copyImageToClipboard}
\alias{copyWordTable}
\title{Exchange tabular data with the Windows clipboard}
\description{Read an Excel cell range or delimited plain text from the Windows clipboard, and copy styled tables in formats that paste into Word, Excel, and text applications.}
\usage{
readClipboardTable(header = "auto", sep = "auto",
  stringsAsFactors = FALSE, check.names = FALSE,
  details = FALSE, ...)

parseClipboardTable(payload, header = "auto", sep = "auto",
  stringsAsFactors = FALSE, check.names = FALSE,
  details = FALSE, ...)

copyTableToClipboard(x, title = NULL, subtitle = NULL,
  notes = NULL, digits = 3L)

copyImageToClipboard(file)

copyWordTable(x, title = NULL, subtitle = NULL,
  notes = NULL, digits = 3L)
}
\arguments{
  \item{payload}{Clipboard text, or the value produced by \code{clipboardButton()}.}
  \item{header}{Logical value or \code{"auto"}. Automatic mode compares the first row with subsequent column values and uses clipboard format hints.}
  \item{sep}{A field separator or \code{"auto"}. Automatic mode recognizes tab-, comma-, semicolon-, and pipe-delimited text.}
  \item{stringsAsFactors}{Whether imported character columns should become factors.}
  \item{check.names}{Whether imported column names should be converted to syntactically valid, unique R names.}
  \item{details}{If true, return a list containing both the data and detection metadata.}
  \item{...}{Additional arguments passed to \code{utils::read.table()}.}
  \item{x}{A data frame or a named, non-empty list of data frames.}
  \item{title}{Optional title copied above the tables.}
  \item{subtitle}{Optional subtitle copied below the title.}
  \item{notes}{Optional notes copied below the tables.}
  \item{digits}{Significant digits used to format numeric table cells.}
  \item{file}{Path to a BMP image file.}
}
\details{The regression clipboard example uses three native WPF controls: \code{clipboardButton()} for import, \code{copyTableButton()} for copying displayed DataGrid outputs, and \code{copyPlotButton()} for copying a displayed bitmap. Clipboard import writes the exact Unicode clipboard text to a temporary UTF-8 file and sends only the file path through WinShiny's ordinary scalar event channel. R reads the file before exposing the text as \code{input$inputId}. Successful table and plot copies are silent; clipboard failures display a native error dialog.

\code{readClipboardTable()} is a console-oriented fallback based on the Windows \code{utils::readClipboard()} implementation. \code{parseClipboardTable()} performs delimiter, header-row, and decimal-mark detection on supplied text or clipboard-button values.

\code{copyTableToClipboard()} and \code{copyImageToClipboard()} remain available for an active WinShiny session, but direct copy buttons are preferred for displayed native outputs because they copy the exact DataGrid or bitmap already present in the WPF window.} 
\value{\code{readClipboardTable()} and \code{parseClipboardTable()} return a data frame, or an object with \code{data} and \code{metadata} when \code{details = TRUE}. The table copy functions return clipboard format and table-size information invisibly. \code{copyImageToClipboard()} returns the normalized image path invisibly.}
\seealso{\code{writeDocxTable()}, \code{renderTable()}, and \code{runExample("regression_clipboard")}.}
\keyword{utilities}
\examples{
\dontrun{
imported <- readClipboardTable(details = TRUE)
copyWordTable(
  list(Coefficients = data.frame(term = c("x", "z"), estimate = c(1.2, -0.4))),
  title = "Regression output"
)
}
}
