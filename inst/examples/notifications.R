library(WinShiny)

ui <- fluidPage(
  titlePanel("Notifications and modal windows"),
  flowLayout(
    actionButton("notify", "Show notification"),
    actionButton("modal", "Open modal")
  ),
  textOutput("status")
)

server <- function(input, output, session) {
  status <- reactiveVal("No action yet.")

  last_notify <- 0
  observe({
    value <- input$notify
    if (is.null(value) || value <= last_notify) return(invisible(NULL))
    last_notify <<- value
    showNotification(
      paste("Notification", value, "from the R server"),
      type = "message", duration = 4, session = session
    )
    status("A native notification was requested.")
  })

  last_modal <- 0
  observe({
    value <- input$modal
    if (is.null(value) || value <= last_modal) return(invisible(NULL))
    last_modal <<- value
    showModal(
      modalDialog(
        h3("Native WPF modal"),
        p("This window was requested from the R server."),
        p("Close it with the standard Windows close button.")
      ),
      session = session
    )
    status("A native modal window was requested.")
  })

  output$status <- renderText(status())
}

runApp(shinyApp(ui, server))
