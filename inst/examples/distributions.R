library(WinShiny)

ui <- fluidPage(
  titlePanel("Probability distribution simulator"),
  radioButtons(
    "distribution",
    "Distribution",
    choices = c(Normal = "normal", Exponential = "exponential"),
    selected = "normal"
  ),
  sliderInput("sample_size", "Sample size", min = 100, max = 5000, value = 1000, step = 100),
  sliderInput("bins", "Histogram bins", min = 5, max = 80, value = 30, step = 1),
  conditionalPanel(
    "input.distribution == 'normal'",
    numericInput("mean", "Mean", 0, step = 0.25),
    numericInput("sd", "Standard deviation", 1, min = 0.1, step = 0.1)
  ),
  conditionalPanel(
    "input.distribution == 'exponential'",
    numericInput("rate", "Rate", 1, min = 0.1, step = 0.1)
  ),
  plotOutput("distribution_plot", height = "340px"),
  tableOutput("distribution_summary")
)

server <- function(input, output, session) {
  sample_values <- reactive({
    set.seed(2026)
    n <- as.integer(input$sample_size)
    if (identical(input$distribution, "normal")) {
      stats::rnorm(n, mean = as.numeric(input$mean), sd = max(0.1, as.numeric(input$sd)))
    } else {
      stats::rexp(n, rate = max(0.1, as.numeric(input$rate)))
    }
  })

  output$distribution_plot <- renderPlot({
    x <- sample_values()
    hist(
      x,
      breaks = as.integer(input$bins),
      probability = TRUE,
      xlab = "Value",
      main = paste("Simulated", input$distribution, "distribution")
    )
    lines(stats::density(x), lwd = 2)
  })

  output$distribution_summary <- renderTable({
    x <- sample_values()
    data.frame(
      Statistic = c("Minimum", "Mean", "Median", "Standard deviation", "Maximum"),
      Value = round(c(min(x), mean(x), median(x), stats::sd(x), max(x)), 4)
    )
  })
}

runApp(shinyApp(ui, server))
