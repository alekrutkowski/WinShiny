# WinShiny

WinShiny is an experimental R package for building native Windows desktop GUIs
with a Shiny-like API. Application logic and reactive computations run in R;
the window and controls are rendered by Windows PowerShell and WPF instead of a
web browser.

The package is intended for Windows environments where R scripts and the
installed PowerShell host are allowed, but launching arbitrary executables or a
browser-hosted local application is undesirable or prohibited.

## Requirements

- Windows 10 or Windows 11
- R
- Windows PowerShell or PowerShell
- the R package `jsonlite`
- optionally `ggplot2` for examples and ggplot rendering

No compiled code or Rtools is required.

## Installation

Install a local source bundle with:

```r
install.packages("WinShiny_x.y.z.tar.gz", repos = NULL, type = "source")
```

## Quick start

```r
library(WinShiny)

ui <- fluidPage(
  titlePanel("Native WinShiny app"),
  sliderInput("bins", "Histogram bins", 5, 50, 20, step = 1),
  plotOutput("plot")
)

server <- function(input, output, session) {
  output$plot <- renderPlot({
    hist(faithful$eruptions, breaks = input$bins)
  })
}

runApp(shinyApp(ui, server))
```

`runApp()` owns the calling R session while the WPF window is open. Closing the
window returns control to the R prompt.

## Architecture

A WinShiny app keeps the familiar `ui`, `server`, `input`, `output`, and
`session` model. R and WPF exchange atomic JSON state, command, and event files
inside an application-specific temporary directory. R renders plots to PNG;
WPF decodes them into native image controls. Tables are bound to read-only WPF
`DataGrid` controls.

Clipboard import is handled on the WPF STA thread. The exact Unicode clipboard
text is written to a temporary UTF-8 transfer file, and only that path travels
through the ordinary scalar input-event channel. `parseClipboardTable()` then
recognises Excel ranges, TSV, CSV, semicolon-delimited text, and pipe-delimited
text. Displayed tables and plots can be copied directly from their WPF controls;
successful copies are silent and failures display a native error dialog.

## Shiny-compatible API

WinShiny exports 219 public names. Of these, 206 also belong to the public API
of Shiny 1.13.0; 13 are WinShiny-specific extensions. Compatibility levels for
all 283 Shiny 1.13.0 exports are recorded in
`inst/SHINY_API_COMPATIBILITY.csv` and can be read with
`winShinyCapabilities()`.

### Application and reactivity

Implemented or closely mirrored:

- `shinyApp()`, `runApp()`, `runExample()`, `shinyUI()`, `shinyServer()`
- reactive `input`, `output`, and `session` objects
- `reactive()`, `reactiveVal()`, `reactiveValues()`, `observe()`
- `observeEvent()`, `eventReactive()`, `bindEvent()`, `isolate()`, `req()`
- timers and polling through `invalidateLater()`, `reactiveTimer()`,
  `reactivePoll()`, and `reactiveFileReader()`
- common module patterns through `NS()`, `moduleServer()`, and `callModule()`

The reactive scheduler is intentionally smaller than Shiny's. Promise handling,
reactlog, caching, exact priority semantics, and every reactive-domain edge case
are not reproduced.

### Native inputs

| Function | WPF control |
|---|---|
| `textInput()` | `TextBox` |
| `textAreaInput()` | multiline `TextBox` |
| `passwordInput()` | `PasswordBox` |
| `numericInput()` | validated numeric `TextBox` |
| `sliderInput()` | tick-aware `Slider` |
| `dateInput()` | `DatePicker` |
| `dateRangeInput()` | two `DatePicker` controls |

Date controls keep ISO `yyyy-mm-dd` values on the R side but honor common display formats in WPF. For a European day-first selector, use `format = "dd/mm/yyyy", language = "en-GB", weekstart = 1`.
| `checkboxInput()` | `CheckBox` |
| `checkboxGroupInput()` | checkbox panel |
| `radioButtons()` | radio-button panel |
| `selectInput()` | `ComboBox` |
| `selectizeInput()` | native `ComboBox`, not Selectize.js |
| `fileInput()` | Windows `OpenFileDialog` |
| `actionButton()` / `actionLink()` | `Button` |
| `clipboardButton()` | native clipboard-import button |
| `themeToggle()` | reactive light/dark-mode switch |

The corresponding `update*Input()` functions update both the live WPF control
and the R-side input value for the supported properties.

### Outputs

Implemented output/render pairs include:

- `textOutput()` / `renderText()`
- `verbatimTextOutput()` / `renderPrint()`
- `plotOutput()` / `renderPlot()`
- `imageOutput()` / `renderImage()`
- `tableOutput()` / `renderTable()`
- `dataTableOutput()` / `renderDataTable()`
- `uiOutput()` / `renderUI()`
- `downloadButton()` or `downloadLink()` / `downloadHandler()`

Plots are rerendered by R after WPF reports the current output width and height.
Plot export can reuse the same renderer at a higher resolution while preserving
the displayed aspect ratio. Base graphics and ggplot2 outputs follow the active
light/dark theme where possible.

`renderTable()` and `renderDataTable()` use a native `DataGrid` rather than an
HTML table. `tableOutput(id, fill = TRUE)` and
`dataTableOutput(id, fill = TRUE)` are WinShiny extensions for a table that uses
the remaining vertical space of its tab.

### Layout, navigation, and desktop integration

Native equivalents include page, row, column, sidebar, split, fill, tabset,
navbar, nav-list, conditional, modal, notification, open-file, and save-file
controls. `downloadHandler()` opens a Windows `SaveFileDialog` and writes to the
selected local path rather than returning an HTTP download.

## WinShiny-specific API

- `themeToggle()` and `winThemeToggle()`
- `clipboardButton()`, `copyTableButton()`, and `copyPlotButton()`
- `readClipboardTable()`, `parseClipboardTable()`,
  `copyTableToClipboard()`, `copyWordTable()`, and `copyImageToClipboard()`
- `writeDocxTable()` for WordprocessingML `.docx` tables without `officer`,
  `flextable`, or Word automation
- `flushReact()`
- `winShinyCapabilities()`

## Important differences from browser Shiny

- There is no HTTP server, WebSocket, DOM, JavaScript runtime, or CSS cascade.
- `HTML()` and `htmlOutput()` do not provide a general HTML renderer.
- htmlwidgets such as Leaflet, plotly, DT JavaScript extensions, and visNetwork
  are not supported.
- Plot click, hover, double-click, and brush events are not implemented.
- `selectizeInput()` does not reproduce Selectize.js behavior.
- `fileInput()` returns local file paths, not browser-upload metadata.
- Browser resource paths, bookmarking, URL mutation, dynamic DOM insertion,
  test-server emulation, caches, promises, reactlog, and telemetry are absent or
  represented only by limited compatibility shims.
- Bootstrap and CSS arguments may be accepted for source compatibility without
  having a native WPF effect.

An exported name means source-level availability, not identical browser
semantics. Use `winShinyCapabilities()` for the function-by-function status.

## Examples

Call `runExample()` without an argument to list the installed examples. The
current set is:

- `dates`
- `distributions`
- `dynamic_ui`
- `exports`
- `file_summary`
- `histogram`
- `image_output`
- `iris_explorer`
- `kmeans`
- `mortgage`
- `mtcars_explorer`
- `navigation_dashboard`
- `notifications`
- `plot_export`
- `regression_clipboard`
- `tab_management`
- `table_export`
- `tabset_form`
- `telephones`
- `volcano`
- `widgets`

Notable examples:

```r
runExample("navigation_dashboard")
runExample("regression_clipboard")
runExample("dynamic_ui")
runExample("plot_export")
```

## Documentation

Standard `.Rd` help is installed with the package:

```r
help(package = "WinShiny")
?shinyApp
?reactive
?textInput
?renderPlot
?readClipboardTable
?writeDocxTable
```

WinShiny remains an experimental compatibility backend. Applications should be
tested against the native controls and limitations described above.
