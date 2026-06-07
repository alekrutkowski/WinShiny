library(WinShiny)

numeric_columns <- names(iris)[vapply(iris, is.numeric, logical(1))]

ui <- sidebarLayout(
  sidebarPanel(
    titlePanel("K-means clustering of iris measurements"),
    selectInput("xvar", "Horizontal variable", numeric_columns, "Sepal.Length"),
    selectInput("yvar", "Vertical variable", numeric_columns, "Petal.Length"),
    sliderInput("clusters", "Number of clusters", min = 2, max = 8, value = 3, step = 1, round = TRUE),
    checkboxInput("centers", "Show cluster centres", TRUE)
  ),
  mainPanel(
    plotOutput("cluster_plot", height = "380px"),
    tableOutput("cluster_sizes")
  )
)

server <- function(input, output, session) {
  fit <- reactive({
    x <- iris[, c(input$xvar, input$yvar), drop = FALSE]
    stats::kmeans(x, centers = as.integer(input$clusters), nstart = 25)
  })

  output$cluster_plot <- renderPlot({
    model <- fit()
    x <- iris[[input$xvar]]
    y <- iris[[input$yvar]]
    plot(
      x,
      y,
      col = model$cluster,
      pch = 19,
      xlab = input$xvar,
      ylab = input$yvar,
      main = paste(input$clusters, "K-means clusters")
    )
    if (isTRUE(input$centers)) {
      points(model$centers[, 1], model$centers[, 2], pch = 8, cex = 2, lwd = 2)
    }
  })

  output$cluster_sizes <- renderTable({
    sizes <- table(Cluster = fit()$cluster)
    data.frame(Cluster = names(sizes), Observations = as.integer(sizes))
  })
}

runApp(shinyApp(ui, server))
