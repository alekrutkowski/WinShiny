library(WinShiny)

variables <- names(mtcars)

ui <- sidebarLayout(
  sidebarPanel(
    titlePanel("Motor Trend car explorer"),
    selectInput("xvar", "Horizontal variable", variables, "wt"),
    selectInput("yvar", "Vertical variable", variables, "mpg"),
    sliderInput("point_size", "Point size", min = 0.5, max = 2.5, value = 1.2, step = 0.1),
    checkboxInput("fit", "Show linear regression", TRUE),
    checkboxInput("names", "Label cars", FALSE)
  ),
  mainPanel(
    plotOutput("scatter", height = "380px"),
    tableOutput("correlation")
  )
)

server <- function(input, output, session) {
  output$scatter <- renderPlot({
    x <- mtcars[[input$xvar]]
    y <- mtcars[[input$yvar]]
    plot(
      x,
      y,
      pch = 19,
      cex = as.numeric(input$point_size),
      xlab = input$xvar,
      ylab = input$yvar,
      main = paste(input$yvar, "versus", input$xvar)
    )
    if (isTRUE(input$fit)) {
      abline(stats::lm(y ~ x), lwd = 2)
    }
    if (isTRUE(input$names)) {
      text(x, y, labels = rownames(mtcars), pos = 3, cex = 0.65)
    }
  })

  output$correlation <- renderTable({
    x <- mtcars[[input$xvar]]
    y <- mtcars[[input$yvar]]
    data.frame(
      Statistic = c("Observations", "Correlation", "R-squared"),
      Value = c(
        length(x),
        round(stats::cor(x, y), 4),
        round(summary(stats::lm(y ~ x))$r.squared, 4)
      )
    )
  })
}

runApp(shinyApp(ui, server))
