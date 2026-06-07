library(WinShiny)

ui <- fluidPage(
  titlePanel("Native Windows widget gallery"),
  textInput("name", "Name", "Ada Lovelace"),
  textAreaInput("notes", "Notes", "Analytical engines\nand native Windows controls"),
  numericInput("quantity", "Quantity", 3, min = 0, max = 100, step = 1),
  sliderInput("confidence", "Confidence", min = 0, max = 100, value = 75, step = 5, post = "%"),
  radioButtons("priority", "Priority", choices = c(Low = "low", Normal = "normal", High = "high"), selected = "normal"),
  selectInput("category", "Category", choices = c("Analysis", "Reporting", "Automation"), selected = "Analysis"),
  selectInput(
    "formats", "Output formats",
    choices = c("CSV", "Word", "PDF", "PNG"),
    selected = c("CSV", "Word"),
    multiple = TRUE,
    size = 4
  ),
  selectizeInput(
    "audiences", "Audiences",
    choices = c("Analysts", "Managers", "Clients", "Public"),
    selected = c("Analysts", "Managers"),
    multiple = TRUE,
    size = 4
  ),
  checkboxGroupInput(
    "channels",
    "Output channels",
    choices = c(Console = "console", File = "file", Email = "email"),
    selected = c("console", "file")
  ),
  checkboxInput("approved", "Approved", FALSE),
  textOutput("sentence"),
  tableOutput("settings")
)

server <- function(input, output, session) {
  output$sentence <- renderText({
    paste0(
      input$name,
      " configured ",
      input$quantity,
      " ",
      tolower(input$category),
      " item(s) at ",
      round(as.numeric(input$confidence)),
      "% confidence."
    )
  })

  output$settings <- renderTable({
    data.frame(
      Setting = c("Priority", "Formats", "Audiences", "Channels", "Approved", "Notes"),
      Value = c(
        input$priority,
        paste(as.character(input$formats), collapse = ", "),
        paste(as.character(input$audiences), collapse = ", "),
        paste(as.character(input$channels), collapse = ", "),
        as.character(isTRUE(input$approved)),
        gsub("[\r\n]+", " / ", input$notes)
      )
    )
  })
}

runApp(shinyApp(ui, server))
