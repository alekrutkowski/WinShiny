library(WinShiny)

ui <- fluidPage(
  titlePanel("Local chart and data export"),
  sidebarLayout(
    sidebarPanel(
      selectInput("variable", "Variable", names(mtcars), "mpg"),
      sliderInput("bins", "Histogram bins", 5, 40, 15, step = 1),
      downloadButton("save_plot", "Save chart as PNG"),
      downloadButton("save_data", "Save data as CSV")
    ),
    mainPanel(
      plotOutput("chart", height = "350px"),
      tableOutput("summary")
    )
  )
)

server <- function(input, output, session) {
  selected <- reactive(mtcars[[input$variable]])

  draw_chart <- function() {
    hist(selected(), breaks = as.integer(input$bins),
         main = paste("Distribution of", input$variable), xlab = input$variable)
  }

  output$chart <- renderPlot(draw_chart())

  output$summary <- renderTable({
    x <- selected()
    data.frame(
      Statistic = c("Minimum", "Mean", "Median", "Maximum"),
      Value = c(min(x), mean(x), median(x), max(x))
    )
  }, digits = 3)

  output$save_plot <- downloadHandler(
    filename = function() paste0("mtcars_", input$variable, ".png"),
    content = function(file) {
      grDevices::png(file, width = 1000, height = 650, res = 120)
      on.exit(grDevices::dev.off(), add = TRUE)
      draw_chart()
    },
    contentType = "image/png"
  )

  output$save_data <- downloadHandler(
    filename = function() paste0("mtcars_", input$variable, ".csv"),
    content = function(file) {
      utils::write.csv(
        data.frame(value = selected()), file,
        row.names = FALSE
      )
    },
    contentType = "text/csv"
  )
}

runApp(shinyApp(ui, server))
