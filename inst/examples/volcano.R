library(WinShiny)

ui <- fluidPage(
  titlePanel("Maunga Whau volcano surface"),
  selectInput(
    "palette",
    "Palette",
    choices = c(Topographic = "topo", Terrain = "terrain", Heat = "heat"),
    selected = "topo"
  ),
  sliderInput("levels", "Contour levels", min = 5, max = 40, value = 15, step = 1),
  checkboxInput("contours", "Draw contour lines", TRUE),
  checkboxInput("axes", "Show axes", FALSE),
  plotOutput("volcano_plot", height = "420px")
)

server <- function(input, output, session) {
  output$volcano_plot <- renderPlot({
    colours <- switch(
      input$palette,
      terrain = grDevices::terrain.colors(64),
      heat = grDevices::heat.colors(64),
      grDevices::topo.colors(64)
    )
    image(
      volcano,
      col = colours,
      axes = isTRUE(input$axes),
      xlab = "East-west",
      ylab = "North-south",
      main = "Volcano elevation"
    )
    if (isTRUE(input$contours)) {
      contour(volcano, add = TRUE, nlevels = as.integer(input$levels), drawlabels = FALSE)
    }
  })
}

runApp(shinyApp(ui, server))
