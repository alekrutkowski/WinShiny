library(WinShiny)

numeric_columns <- names(iris)[vapply(iris, is.numeric, logical(1))]
species <- levels(iris$Species)

ui <- fluidPage(
  titlePanel("Iris species explorer"),
  selectInput("xvar", "Horizontal variable", numeric_columns, "Sepal.Length"),
  selectInput("yvar", "Vertical variable", numeric_columns, "Petal.Width"),
  checkboxGroupInput(
    "species",
    "Species",
    choices = stats::setNames(species, species),
    selected = species
  ),
  checkboxInput("legend", "Show legend", TRUE),
  plotOutput("iris_plot", height = "360px"),
  tableOutput("species_summary")
)

server <- function(input, output, session) {
  selected_iris <- reactive({
    iris[as.character(iris$Species) %in% as.character(input$species), , drop = FALSE]
  })

  output$iris_plot <- renderPlot({
    d <- selected_iris()
    if (!nrow(d)) {
      plot.new()
      text(0.5, 0.5, "Select at least one species")
    } else {
      groups <- droplevels(d$Species)
      plot(
        d[[input$xvar]],
        d[[input$yvar]],
        col = as.integer(groups),
        pch = 19,
        xlab = input$xvar,
        ylab = input$yvar,
        main = "Iris measurements"
      )
      if (isTRUE(input$legend)) {
        legend("topleft", legend = levels(groups), col = seq_along(levels(groups)), pch = 19)
      }
    }
  })

  output$species_summary <- renderTable({
    d <- selected_iris()
    if (!nrow(d)) {
      data.frame(Message = "No species selected")
    } else {
      aggregate(
        d[, numeric_columns, drop = FALSE],
        list(Species = d$Species),
        mean
      )
    }
  })
}

runApp(shinyApp(ui, server))
