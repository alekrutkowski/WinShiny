library(WinShiny)

ui <- bootstrapPage(
  titlePanel("WinShiny histogram demo"),
  selectInput(
    inputId = "n_breaks",
    label = "Number of bins in histogram (approximate):",
    choices = c(10, 20, 35, 50),
    selected = 20
  ),
  checkboxInput(
    inputId = "individual_obs",
    label = "Show individual observations",
    value = FALSE
  ),
  checkboxInput(
    inputId = "density",
    label = "Show density estimate",
    value = FALSE
  ),
  conditionalPanel(
    condition = "input.density == true",
    sliderInput(
      inputId = "bw_adjust",
      label = "Bandwidth adjustment:",
      min = 0.2,
      max = 2,
      value = 1,
      step = 0.2
    )
  ),
  plotOutput(outputId = "main_plot", height = "300px")
)

server <- function(input, output, session) {
  output$main_plot <- renderPlot({
    hist(
      faithful$eruptions,
      probability = TRUE,
      breaks = as.numeric(input$n_breaks),
      xlab = "Duration (minutes)",
      main = "Geyser eruption duration"
    )

    if (isTRUE(input$individual_obs)) {
      rug(faithful$eruptions)
    }

    if (isTRUE(input$density)) {
      dens <- density(
        faithful$eruptions,
        adjust = as.numeric(input$bw_adjust)
      )
      lines(dens, lwd = 2)
    }
  })
}

runApp(shinyApp(ui, server))
