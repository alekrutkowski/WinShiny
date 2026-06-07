library(WinShiny)

ui <- fluidPage(
  titlePanel("Reactive random walk with chart export"),
  fluidRow(
    column(
      4,
      sliderInput("length", "Walk length", 50, 1000, 250, step = 50),
      numericInput("seed", "Random seed", 2026, step = 1),
      actionButton("regenerate", "Generate walk"),
      downloadButton("png", "Save chart as PNG"),
      downloadButton("csv", "Save values as CSV")
    ),
    column(8, plotOutput("walk", height = "320px"))
  )
)

server <- function(input, output, session) {
  revision <- reactiveVal(0L)
  last_regenerate <- 0
  observe({
    value <- input$regenerate
    if (is.null(value) || value <= last_regenerate) return(invisible(NULL))
    last_regenerate <<- value
    revision(revision() + 1L)
    showNotification("A new random walk was generated.", session = session)
  })

  walk_data <- reactive({
    revision()
    set.seed(as.integer(input$seed) + revision())
    data.frame(
      Step = seq_len(as.integer(input$length)),
      Value = cumsum(stats::rnorm(as.integer(input$length)))
    )
  })

  draw_walk <- function() {
    data <- walk_data()
    plot(data$Step, data$Value, type = "l", lwd = 2,
         xlab = "Step", ylab = "Value", main = "Random walk")
    abline(h = 0, lty = 2)
  }

  walk_renderer <- renderPlot(draw_walk())
  output$walk <- walk_renderer

  output$png <- downloadHandler(
    filename = function() "random-walk.png",
    content = function(file) {
      size <- isolate(session$getPlotSize("walk"))
      screen_width <- max(200L, as.integer(size$width))
      screen_height <- max(150L, as.integer(size$height))
      screen_res <- 96
      export_res <- 300
      scale <- export_res / screen_res
      max_dimension <- 10000
      scale <- min(scale, max_dimension / screen_width, max_dimension / screen_height)
      walk_renderer(
        file = file,
        width_px = as.integer(round(screen_width * scale)),
        height_px = as.integer(round(screen_height * scale)),
        res_px = screen_res * scale,
        theme = session$getTheme()
      )
    },
    contentType = "image/png"
  )

  output$csv <- downloadHandler(
    filename = function() "random-walk.csv",
    content = function(file) utils::write.csv(walk_data(), file, row.names = FALSE),
    contentType = "text/csv"
  )
}

runApp(shinyApp(ui, server))
