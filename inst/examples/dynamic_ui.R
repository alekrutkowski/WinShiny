library(WinShiny)

ui <- fluidPage(
  titlePanel("Dynamic native UI"),
  themeToggle("dark", "Dark theme"),
  selectInput(
    "model",
    "Model family",
    choices = c("Linear" = "linear", "Polynomial" = "polynomial", "Smoothing spline" = "spline")
  ),
  uiOutput("parameters"),
  plotOutput("model_plot", height = "320px"),
  tableOutput("coefficients")
)

server <- function(input, output, session) {
  output$parameters <- renderUI({
    switch(
      input$model,
      polynomial = wellPanel(
        numericInput("degree", "Polynomial degree", 3, min = 1, max = 8, step = 1),
        checkboxInput("raw", "Use raw powers", FALSE)
      ),
      spline = wellPanel(
        numericInput("spar", "Smoothing parameter", 0.6, min = 0.05, max = 1.5, step = 0.05)
      ),
      wellPanel(
        checkboxInput("intercept", "Include intercept", TRUE)
      )
    )
  })

  fitted_model <- reactive({
    x <- seq(-3, 3, length.out = 80)
    set.seed(123)
    y <- sin(x) + stats::rnorm(length(x), sd = 0.15)
    if (identical(input$model, "polynomial")) {
      stats::lm(y ~ stats::poly(x, degree = as.integer(if (is.null(input$degree)) 3 else input$degree), raw = isTRUE(input$raw)))
    } else if (identical(input$model, "spline")) {
      stats::smooth.spline(x, y, spar = as.numeric(if (is.null(input$spar)) 0.6 else input$spar))
    } else {
      if (isFALSE(input$intercept)) stats::lm(y ~ x + 0) else stats::lm(y ~ x)
    }
  })

  output$model_plot <- renderPlot({
    x <- seq(-3, 3, length.out = 80)
    set.seed(123)
    y <- sin(x) + stats::rnorm(length(x), sd = 0.15)
    plot(x, y, pch = 19, main = paste("Model:", input$model))
    model <- fitted_model()
    if (inherits(model, "smooth.spline")) {
      lines(model, lwd = 2)
    } else {
      lines(x, stats::predict(model, newdata = data.frame(x = x)), lwd = 2)
    }
  })

  output$coefficients <- renderTable({
    model <- fitted_model()
    if (inherits(model, "smooth.spline")) {
      data.frame(Statistic = c("Effective df", "Spar"), Value = c(model$df, model$spar))
    } else {
      data.frame(Term = names(stats::coef(model)), Estimate = unname(stats::coef(model)))
    }
  }, digits = 4)
}

runApp(shinyApp(ui, server))
