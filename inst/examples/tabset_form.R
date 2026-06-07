library(WinShiny)

ui <- fluidPage(
  titlePanel("Tabbed form and native notifications"),
  tabsetPanel(
    id = "step",
    selected = "identity",
    tabPanel(
      "Identity", value = "identity",
      textInput("name", "Name", "Ada Lovelace"),
      dateInput("date", "Reference date", Sys.Date(), format = "dd/mm/yyyy", language = "en-GB", weekstart = 1)
    ),
    tabPanel(
      "Preferences", value = "preferences",
      radioButtons("priority", "Priority", c(Low = "low", Normal = "normal", High = "high")),
      checkboxGroupInput("formats", "Formats", c(CSV = "csv", PNG = "png", RDS = "rds"), c("csv", "png"))
    ),
    tabPanel(
      "Review", value = "review",
      tableOutput("review"),
      actionButton("submit", "Submit")
    )
  )
)

server <- function(input, output, session) {
  output$review <- renderTable({
    data.frame(
      Field = c("Name", "Date", "Priority", "Formats"),
      Value = c(input$name, input$date, input$priority, paste(input$formats, collapse = ", "))
    )
  })

  last_submit <- 0
  observe({
    value <- input$submit
    if (is.null(value) || value <= last_submit) return(invisible(NULL))
    last_submit <<- value
    if (!nzchar(input$name)) {
      showNotification("A name is required.", type = "warning", session = session)
    } else {
      showNotification(paste("Submitted for", input$name), type = "message", session = session)
    }
  })
}

runApp(shinyApp(ui, server))
