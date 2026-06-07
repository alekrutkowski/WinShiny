library(WinShiny)

ui <- fluidPage(
  titlePanel("Telephones by world region"),
  selectInput(
    "region",
    "Region",
    choices = colnames(WorldPhones),
    selected = colnames(WorldPhones)[1]
  ),
  radioButtons(
    "display",
    "Display",
    choices = c(Bars = "bar", Line = "line"),
    selected = "bar"
  ),
  checkboxInput("labels", "Show values", TRUE),
  plotOutput("phones_plot", height = "340px"),
  tableOutput("phones_table")
)

server <- function(input, output, session) {
  selected_data <- reactive({
    data.frame(
      Year = as.integer(rownames(WorldPhones)),
      Telephones = as.numeric(WorldPhones[, input$region])
    )
  })

  output$phones_plot <- renderPlot({
    d <- selected_data()
    if (identical(input$display, "bar")) {
      mids <- barplot(
        d$Telephones,
        names.arg = d$Year,
        xlab = "Year",
        ylab = "Telephones (thousands)",
        main = input$region
      )
      if (isTRUE(input$labels)) {
        text(mids, d$Telephones, labels = d$Telephones, pos = 3, cex = 0.8)
      }
    } else {
      plot(
        d$Year,
        d$Telephones,
        type = "o",
        pch = 19,
        xlab = "Year",
        ylab = "Telephones (thousands)",
        main = input$region
      )
      if (isTRUE(input$labels)) {
        text(d$Year, d$Telephones, labels = d$Telephones, pos = 3, cex = 0.8)
      }
    }
  })

  output$phones_table <- renderTable(selected_data())
}

runApp(shinyApp(ui, server))
