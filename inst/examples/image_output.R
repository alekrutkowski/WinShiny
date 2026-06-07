library(WinShiny)

ui <- fluidPage(
  titlePanel("renderImage() and native image display"),
  sidebarLayout(
    sidebarPanel(
      selectInput("palette", "Palette", c("topo", "terrain", "heat")),
      sliderInput("resolution", "Image resolution", 300, 1000, 600, step = 100, post = " px")
    ),
    mainPanel(imageOutput("surface", height = "430px"))
  )
)

server <- function(input, output, session) {
  output$surface <- renderImage({
    file <- tempfile(fileext = ".png")
    size <- as.integer(input$resolution)
    grDevices::png(file, width = size, height = size, res = 100)
    colours <- switch(
      input$palette,
      terrain = grDevices::terrain.colors(64),
      heat = grDevices::heat.colors(64),
      grDevices::topo.colors(64)
    )
    image(volcano, col = colours, axes = FALSE, main = "Volcano raster image")
    contour(volcano, add = TRUE, drawlabels = FALSE)
    grDevices::dev.off()
    list(src = file, contentType = "image/png", alt = "Volcano image")
  }, deleteFile = TRUE)
}

runApp(shinyApp(ui, server))
