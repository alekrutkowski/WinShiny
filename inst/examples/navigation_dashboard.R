library(WinShiny)

ui <- navbarPage(
  "Native analytics dashboard",
  id = "page",
  selected = "Overview",
  tabPanel(
    "Overview",
    value = "Overview",
    fluidRow(
      column(
        4,
        wellPanel(
          themeToggle("dark", "Use dark theme"),
          selectInput("dataset", "Dataset", c("mtcars", "iris", "faithful"), selected = "iris"),
          sliderInput("points", "Maximum observations", 5, 150, 50, step = 5),
          checkboxInput("grid", "Draw grid", TRUE),
          checkboxInput("use_ggplot2", "Draw with ggplot2", FALSE),
          downloadButton("download_plot", "Export plot PNG"),
          textOutput("overview_text")
        )
      ),
      column(
        8,
        plotOutput("overview_plot", height = "250px")
      )
    )
  ),
  tabPanel(
    "Data grid",
    value = "Data",
    fluidRow(
      column(9, tableOutput("preview", fill = TRUE)),
      column(3, downloadButton("download_data", "Export displayed CSV"))
    )
  ),
  navbarMenu(
    "More",
    tabPanel(
      "Summary",
      value = "Summary",
      tableOutput("summary")
    ),
    tabPanel(
      "About",
      value = "About",
      h2("WinShiny navigation"),
      p("This example uses navbarPage(), tabPanel(), navbarMenu(), fluidRow(), column(), a native DataGrid, and a theme switch."),
      p("Resize the window to request a new plot at the current WPF pixel dimensions.")
    )
  )
)

server <- function(input, output, session) {
  selected_data <- reactive({
    data <- switch(input$dataset, iris = iris, faithful = faithful, mtcars)
    utils::head(data, as.integer(input$points))
  })

  overview_plot_renderer <- renderPlot({
    data <- selected_data()
    numeric <- data[vapply(data, is.numeric, logical(1))]
    use_ggplot2 <- isTRUE(input$use_ggplot2) && requireNamespace("ggplot2", quietly = TRUE)

    if (use_ggplot2) {
      x_name <- names(numeric)[1]
      if (ncol(numeric) < 2L) {
        p <- ggplot2::ggplot(numeric, ggplot2::aes_string(x = x_name)) +
          ggplot2::geom_histogram(bins = 20, colour = "white") +
          ggplot2::labs(title = input$dataset, x = x_name, y = "Count")
      } else {
        y_name <- names(numeric)[2]
        p <- ggplot2::ggplot(numeric, ggplot2::aes_string(x = x_name, y = y_name)) +
          ggplot2::geom_point(size = 2) +
          ggplot2::labs(title = input$dataset, x = x_name, y = y_name)
      }
      p + if (isTRUE(input$grid)) ggplot2::theme_minimal() else ggplot2::theme_classic()
    } else if (ncol(numeric) < 2L) {
      graphics::hist(numeric[[1]], main = input$dataset, xlab = names(numeric)[1])
    } else {
      graphics::plot(numeric[[1]], numeric[[2]], pch = 19,
                     xlab = names(numeric)[1], ylab = names(numeric)[2],
                     main = input$dataset)
      if (isTRUE(input$grid)) graphics::grid()
    }
  })
  output$overview_plot <- overview_plot_renderer

  output$download_plot <- downloadHandler(
    filename = function() paste0(input$dataset, "-overview.png"),
    content = function(file) {
      # Preserve the current on-screen aspect ratio and physical layout, but
      # render at 300 DPI instead of the 96 DPI used by the WPF display.
      size <- isolate(session$getPlotSize("overview_plot"))
      screen_width <- max(200L, as.integer(size$width))
      screen_height <- max(150L, as.integer(size$height))
      screen_res <- 96
      export_res <- 300
      scale <- export_res / screen_res

      # Keep memory use bounded on unusually large/high-DPI desktops while
      # retaining the exact aspect ratio.
      max_dimension <- 10000
      scale <- min(scale, max_dimension / screen_width, max_dimension / screen_height)

      overview_plot_renderer(
        file = file,
        width_px = as.integer(round(screen_width * scale)),
        height_px = as.integer(round(screen_height * scale)),
        res_px = screen_res * scale,
        theme = if (isTRUE(input$dark)) "dark" else "light"
      )
    },
    contentType = "image/png"
  )

  output$overview_text <- renderText({
    data <- selected_data()
    paste(nrow(data), "rows and", ncol(data), "columns are currently displayed.")
  })

  output$preview <- renderTable(selected_data(), rownames = TRUE)

  output$summary <- renderTable({
    data <- selected_data()
    numeric <- data[vapply(data, is.numeric, logical(1))]
    if (!ncol(numeric)) data.frame(Message = "No numeric columns") else {
      data.frame(
        Variable = names(numeric),
        Mean = vapply(numeric, mean, numeric(1), na.rm = TRUE),
        SD = vapply(numeric, stats::sd, numeric(1), na.rm = TRUE),
        Minimum = vapply(numeric, min, numeric(1), na.rm = TRUE),
        Maximum = vapply(numeric, max, numeric(1), na.rm = TRUE),
        check.names = FALSE
      )
    }
  }, digits = 3)

  output$download_data <- downloadHandler(
    filename = function() paste0(input$dataset, "-preview.csv"),
    content = function(file) utils::write.csv(selected_data(), file, row.names = FALSE)
  )
}

runApp(shinyApp(ui, server))
