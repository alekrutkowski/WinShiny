library(WinShiny)

ui <- fluidPage(
  titlePanel("Programmatic tab selection"),
  flowLayout(
    actionButton("main_tab", "Open main tab"),
    actionButton("diagnostics_tab", "Open diagnostics tab")
  ),
  textOutput("selected_tab"),
  tabsetPanel(
    id = "tabs",
    tabPanel(
      "Main", value = "main",
      h3("Main workspace"),
      plotOutput("plot", height = "300px")
    ),
    tabPanel(
      "Diagnostics", value = "diagnostics",
      verbatimTextOutput("diagnostics")
    )
  )
)

server <- function(input, output, session) {
  output$plot <- renderPlot(plot(pressure, type = "b", main = "Pressure"))
  output$diagnostics <- renderPrint(
    list(R = R.version.string, platform = R.version$platform)
  )
  output$selected_tab <- renderText(paste("Selected tab:", input$tabs))

  last_main <- 0
  observe({
    value <- input$main_tab
    if (is.null(value) || value <= last_main) return(invisible(NULL))
    last_main <<- value
    updateTabsetPanel(session, "tabs", selected = "main")
  })

  last_diagnostics <- 0
  observe({
    value <- input$diagnostics_tab
    if (is.null(value) || value <= last_diagnostics) return(invisible(NULL))
    last_diagnostics <<- value
    updateTabsetPanel(session, "tabs", selected = "diagnostics")
  })
}

runApp(shinyApp(ui, server))
