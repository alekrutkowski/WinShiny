library(WinShiny)

ui <- fluidPage(
  titlePanel("Mortgage amortization calculator"),
  fluidRow(
    column(3, numericInput("principal", "Loan amount", 300000, min = 1000, step = 1000)),
    column(3, numericInput("rate", "Annual interest rate (%)", 4.5, min = 0, step = 0.1)),
    column(3, sliderInput("years", "Term", 1, 40, 25, step = 1, post = " years")),
    column(3, numericInput("extra", "Extra monthly payment", 0, min = 0, step = 25))
  ),
  tabsetPanel(
    id = "mortgage_tab",
    tabPanel("Summary", tableOutput("loan_summary")),
    tabPanel("Balance chart", plotOutput("balance_plot", height = "360px")),
    tabPanel("Schedule", dataTableOutput("schedule"))
  )
)

server <- function(input, output, session) {
  amortization <- reactive({
    principal <- as.numeric(input$principal)
    monthly_rate <- as.numeric(input$rate) / 1200
    months <- as.integer(input$years) * 12L
    regular <- if (monthly_rate == 0) principal / months else
      principal * monthly_rate / (1 - (1 + monthly_rate)^(-months))
    payment <- regular + as.numeric(input$extra)
    balance <- principal
    rows <- vector("list", months)
    for (month in seq_len(months)) {
      interest <- balance * monthly_rate
      principal_paid <- min(balance, payment - interest)
      balance <- max(0, balance - principal_paid)
      rows[[month]] <- data.frame(
        Month = month, Payment = principal_paid + interest,
        Principal = principal_paid, Interest = interest, Balance = balance
      )
      if (balance <= 0) break
    }
    do.call(rbind, rows[seq_len(month)])
  })

  output$loan_summary <- renderTable({
    d <- amortization()
    data.frame(
      Measure = c("Monthly payment", "Payments made", "Total interest", "Total paid"),
      Value = c(d$Payment[1], nrow(d), sum(d$Interest), sum(d$Payment))
    )
  }, digits = 2)

  output$balance_plot <- renderPlot({
    d <- amortization()
    plot(d$Month, d$Balance, type = "l", lwd = 2,
         xlab = "Month", ylab = "Remaining balance", main = "Loan balance")
    grid()
  })

  output$schedule <- renderDataTable({
    d <- amortization()
    d[-1] <- lapply(d[-1], round, 2)
    d
  })
}

runApp(shinyApp(ui, server))
