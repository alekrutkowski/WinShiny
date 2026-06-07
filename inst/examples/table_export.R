library(WinShiny)

ui <- fluidPage(
  titlePanel("Native DataGrid and CSV export"),
  fluidRow(
    column(
      4,
      checkboxGroupInput(
        "cylinders", "Cylinders",
        choices = c("4 cylinders" = "4", "6 cylinders" = "6", "8 cylinders" = "8"),
        selected = c("4", "6", "8")
      ),
      selectInput("sort", "Sort by", choices = names(mtcars), selected = "mpg"),
      checkboxInput("descending", "Descending", TRUE),
      downloadButton("csv", "Save filtered data")
    ),
    column(8, tableOutput("cars"))
  )
)

server <- function(input, output, session) {
  filtered <- reactive({
    keep <- as.character(mtcars$cyl) %in% as.character(input$cylinders)
    data <- data.frame(Car = rownames(mtcars)[keep], mtcars[keep, , drop = FALSE], row.names = NULL, check.names = FALSE)
    order_value <- data[[input$sort]]
    data[order(order_value, decreasing = isTRUE(input$descending)), , drop = FALSE]
  })

  output$cars <- renderTable(filtered(), digits = 3)

  output$csv <- downloadHandler(
    filename = function() "mtcars-filtered.csv",
    content = function(file) utils::write.csv(filtered(), file, row.names = FALSE),
    contentType = "text/csv"
  )
}

runApp(shinyApp(ui, server))
