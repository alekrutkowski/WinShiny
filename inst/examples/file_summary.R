library(WinShiny)

ui <- fluidPage(
  titlePanel("CSV file summary"),
  fileInput("file", "Choose a CSV or delimited text file"),
  selectInput(
    "separator",
    "Field separator",
    choices = c(Comma = ",", Semicolon = ";", Tab = "\t"),
    selected = ","
  ),
  checkboxInput("header", "First row contains column names", TRUE),
  numericInput("rows", "Rows to preview", 10, min = 1, max = 100, step = 1),
  textOutput("file_info"),
  tableOutput("preview")
)

server <- function(input, output, session) {
  selected_path <- reactive({
    path <- as.character(input$file)
    if (!length(path) || !nzchar(path[1])) return(NULL)
    path[1]
  })

  loaded_data <- reactive({
    path <- selected_path()
    if (is.null(path)) return(NULL)
    tryCatch(
      utils::read.table(
        path,
        header = isTRUE(input$header),
        sep = input$separator,
        stringsAsFactors = FALSE,
        check.names = FALSE
      ),
      error = function(e) structure(list(message = conditionMessage(e)), class = "winshiny_file_error")
    )
  })

  output$file_info <- renderText({
    path <- selected_path()
    data <- loaded_data()
    if (is.null(path)) {
      "Choose a file to display its dimensions and first rows."
    } else if (inherits(data, "winshiny_file_error")) {
      paste("Could not read file:", data$message)
    } else {
      paste(basename(path), "-", nrow(data), "rows x", ncol(data), "columns")
    }
  })

  output$preview <- renderTable({
    data <- loaded_data()
    if (is.null(data)) {
      data.frame(Message = "No file selected")
    } else if (inherits(data, "winshiny_file_error")) {
      data.frame(Error = data$message)
    } else {
      utils::head(data, as.integer(input$rows))
    }
  })
}

runApp(shinyApp(ui, server))
