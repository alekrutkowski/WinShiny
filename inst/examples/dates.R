library(WinShiny)

set.seed(42)
daily_data <- data.frame(
  Date = seq(as.Date("2025-01-01"), as.Date("2025-12-31"), by = "day")
)
daily_data$Value <- 100 + cumsum(stats::rnorm(nrow(daily_data), sd = 1.5))

ui <- fluidPage(
  titlePanel("Date-range time-series explorer"),
  dateRangeInput(
    "range",
    "Visible date range",
    start = as.Date("2025-03-01"),
    end = as.Date("2025-09-30"),
    min = min(daily_data$Date),
    max = max(daily_data$Date),
    format = "dd/mm/yyyy",
    language = "en-GB",
    weekstart = 1
  ),
  radioButtons(
    "display",
    "Display",
    choices = c(Level = "level", "Daily changes" = "changes"),
    selected = "level"
  ),
  sliderInput("smooth", "Moving-average window", min = 1, max = 30, value = 7, step = 1, post = " days"),
  plotOutput("date_plot", height = "350px"),
  tableOutput("date_summary")
)

server <- function(input, output, session) {
  visible_data <- reactive({
    range <- as.Date(input$range)
    daily_data[daily_data$Date >= range[1] & daily_data$Date <= range[2], , drop = FALSE]
  })

  output$date_plot <- renderPlot({
    d <- visible_data()
    y <- if (identical(input$display, "changes")) c(NA, diff(d$Value)) else d$Value
    plot(
      d$Date,
      y,
      type = "l",
      xlab = "Date",
      ylab = if (identical(input$display, "changes")) "Daily change" else "Index",
      main = "Selected period"
    )
    window <- as.integer(input$smooth)
    if (window > 1 && nrow(d) >= window) {
      smoothed <- stats::filter(y, rep(1 / window, window), sides = 2)
      lines(d$Date, smoothed, lwd = 2)
    }
  })

  output$date_summary <- renderTable({
    d <- visible_data()
    data.frame(
      Start = as.character(min(d$Date)),
      End = as.character(max(d$Date)),
      Days = nrow(d),
      Minimum = round(min(d$Value), 2),
      Maximum = round(max(d$Value), 2),
      Change = round(tail(d$Value, 1) - d$Value[1], 2)
    )
  })
}

runApp(shinyApp(ui, server))
