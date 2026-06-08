library(WinShiny)

choices <- setNames(letters[1:12], paste("Choice", LETTERS[1:12]))

ui <- fluidPage(
  titlePanel("Inline selectize smoke test"),
  selectInput(
    "single",
    "selectInput(selectize = TRUE)",
    choices,
    selected = "c",
    selectize = TRUE
  ),
  selectInput(
    "multiple",
    "selectInput(multiple = TRUE, selectize = TRUE)",
    choices,
    selected = c("b", "d"),
    multiple = TRUE,
    selectize = TRUE
  ),
  selectizeInput(
    "explicit",
    "selectizeInput()",
    choices,
    selected = "e"
  ),
  varSelectInput(
    "variable",
    "varSelectInput(selectize = TRUE)",
    mtcars,
    selected = "mpg",
    selectize = TRUE
  ),
  selectInput(
    "native",
    "selectInput(selectize = FALSE)",
    choices,
    selected = "a",
    selectize = FALSE
  ),
  actionButton("replace", "Replace choices"),
  verbatimTextOutput("values")
)

server <- function(input, output, session) {
  observeEvent(input$replace, {
    updateSelectInput(
      session,
      "single",
      choices = setNames(as.character(21:25), paste("Updated", 21:25)),
      selected = "23"
    )
    updateSelectizeInput(
      session,
      "explicit",
      choices = setNames(as.character(31:35), paste("Updated", 31:35)),
      selected = "34"
    )
  })

  output$values <- renderPrint({
    list(
      single = input$single,
      multiple = input$multiple,
      explicit = input$explicit,
      variable = input$variable,
      native = input$native
    )
  })
}

runApp(shinyApp(ui, server))
