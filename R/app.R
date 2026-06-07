shinyApp <- function(ui, server, onStart = NULL, options = list(),
                     uiPattern = '/', enableBookmarking = NULL) {
  structure(
    list(
      ui = ui,
      server = server,
      onStart = onStart,
      options = options,
      uiPattern = uiPattern,
      enableBookmarking = enableBookmarking
    ),
    class = 'winshiny.app'
  )
}

as.shiny.appobj <- function(x) x

runExample <- function(example = NA, port = getOption('shiny.port'),
                       launch.browser = getOption('shiny.launch.browser', interactive()),
                       host = getOption('shiny.host', '127.0.0.1'),
                       display.mode = c('auto', 'normal', 'showcase')) {
  example_dir <- system.file('examples', package = 'WinShiny')
  paths <- list.files(example_dir, pattern = '[.]R$', full.names = TRUE)
  examples <- tools::file_path_sans_ext(basename(paths))

  if (!length(paths)) stop('No WinShiny examples are installed.', call. = FALSE)
  if (length(example) != 1L || is.na(example) || !nzchar(example)) {
    message('Available WinShiny examples: ', paste(examples, collapse = ', '))
    example <- 'histogram'
  }

  requested <- tools::file_path_sans_ext(basename(as.character(example)))
  index <- match(tolower(requested), tolower(examples))
  if (is.na(index)) {
    stop(
      'Unknown WinShiny example `', example, '`. Available examples: ',
      paste(examples, collapse = ', '),
      call. = FALSE
    )
  }

  base::source(paths[[index]], local = new.env(parent = globalenv()))
}
