library(WinShiny)

initial_data <- mtcars
initial_response <- "mpg"
initial_predictors <- c("wt", "hp", "am")
initial_numeric <- names(initial_data)[vapply(initial_data, is.numeric, logical(1))]
`%or%` <- function(x, y) if (is.null(x)) y else x

ui <- fluidPage(
  titlePanel("Linear regression with Windows clipboard data"),
  sidebarLayout(
    sidebarPanel(
      clipboardButton("import_clipboard", "Import table from clipboard"),
      textOutput("clipboard_status"),
      selectInput(
        "response", "Dependent variable",
        choices = initial_numeric,
        selected = initial_response
      ),
      checkboxGroupInput(
        "predictors", "Explanatory variables",
        choices = setdiff(initial_numeric, initial_response),
        selected = initial_predictors
      ),
      checkboxInput("intercept", "Include intercept", TRUE),
      copyTableButton(
        "copy_word", "Copy displayed model tables to Word",
        outputIds = c(
          "Coefficient estimates" = "coefficients",
          "Model statistics" = "fit_statistics"
        ),
        title = "Linear regression model",
        subtitle = "Displayed WinShiny model results"
      ),
      copyPlotButton(
        "copy_plot", "Copy displayed diagnostic plot",
        outputId = "diagnostic"
      )
    ),
    mainPanel(
      tabsetPanel(
        id = "results_tab",
        tabPanel(
          "Model results",
          h3("Model specification"),
          textOutput("formula"),
          h3("Coefficient estimates"),
          tableOutput("coefficients"),
          h3("Model statistics"),
          tableOutput("fit_statistics")
        ),
        tabPanel(
          "Diagnostic plot",
          plotOutput("diagnostic", height = "420px")
        ),
        tabPanel(
          "Imported data",
          tableOutput("data_preview", fill = TRUE)
        )
      )
    )
  )
)

server <- function(input, output, session) {
  model_data <- reactiveVal(initial_data)
  clipboard_status <- reactiveVal(
    "Using the built-in mtcars data. Copy an Excel range or delimited text, then click Import table from clipboard."
  )

  fit_model <- function(data, response, predictors, intercept = TRUE) {
    response <- as.character(response %or% "")[1L]
    predictors <- unique(as.character(predictors %or% character()))
    predictors <- setdiff(predictors, response)
    if (!nzchar(response) || !response %in% names(data)) {
      stop("Select a valid dependent variable.", call. = FALSE)
    }
    predictors <- predictors[predictors %in% names(data)]
    if (!length(predictors)) {
      stop("Select at least one explanatory variable.", call. = FALSE)
    }
    stats::lm(
      stats::reformulate(
        predictors,
        response = response,
        intercept = isTRUE(intercept)
      ),
      data = data
    )
  }

  fit_result <- reactive({
    tryCatch(
      list(
        model = fit_model(
          model_data(), input$response, input$predictors,
          isTRUE(input$intercept)
        ),
        error = NULL
      ),
      error = function(e) list(model = NULL, error = conditionMessage(e))
    )
  })

  numeric_variables <- reactive({
    data <- model_data()
    names(data)[vapply(data, is.numeric, logical(1))]
  })

  observe({
    clipboard_payload <- input$import_clipboard
    if (is.null(clipboard_payload) || !length(clipboard_payload)) return(invisible(NULL))
    clipboard_status("Parsing clipboard contents...")
    imported <- tryCatch(
      parseClipboardTable(clipboard_payload, details = TRUE, check.names = TRUE),
      error = function(e) e
    )
    if (inherits(imported, "error")) {
      clipboard_status(paste("Clipboard import failed:", conditionMessage(imported)))
      return()
    }

    data <- imported$data
    numeric <- names(data)[vapply(data, is.numeric, logical(1))]
    if (length(numeric) < 2L) {
      clipboard_status("The imported table must contain at least two numeric columns for regression.")
      return()
    }

    response <- numeric[[1L]]
    predictors <- utils::head(setdiff(numeric, response), 3L)
    model_data(data)
    updateSelectInput(session, "response", choices = numeric, selected = response)
    updateCheckboxGroupInput(
      session, "predictors",
      choices = setdiff(numeric, response), selected = predictors
    )

    meta <- imported$metadata
    clipboard_status(sprintf(
      "Imported %d rows and %d columns from %s; separator: %s; decimal mark: %s; header row: %s.",
      meta$rows, meta$columns, meta$source, meta$separator_label,
      meta$decimal_mark, if (isTRUE(meta$header)) "yes" else "no"
    ))
  })

  previous_response <- reactiveVal(initial_response)

  observe({
    response <- as.character(input$response %or% "")[1L]
    numeric <- numeric_variables()
    if (!nzchar(response) || !response %in% numeric) return(invisible(NULL))

    previous <- isolate(previous_response())
    choices <- setdiff(numeric, response)
    selected <- intersect(
      as.character(isolate(input$predictors) %or% character()),
      choices
    )

    # When the response changes, make the old response available as a
    # predictor and select it by default. The new response is always removed.
    if (!identical(previous, response) && previous %in% choices) {
      selected <- unique(c(selected, previous))
    }
    selected <- setdiff(selected, response)
    if (!length(selected)) selected <- utils::head(choices, 3L)

    updateCheckboxGroupInput(
      session, "predictors", choices = choices, selected = selected
    )
    previous_response(response)
    invisible(NULL)
  })

  coefficient_table <- reactive({
    result <- fit_result()
    fit <- result$model
    if (is.null(fit)) return(data.frame(Status = result$error %or% "Model unavailable."))
    estimates <- summary(fit)$coefficients
    intervals <- stats::confint(fit)

    data.frame(
      Term = rownames(estimates),
      Estimate = estimates[, 1],
      `Std. error` = estimates[, 2],
      `t statistic` = estimates[, 3],
      `p value` = estimates[, 4],
      `95% confidence interval` = sprintf(
        "[%.*f, %.*f]", 3L, intervals[, 1], 3L, intervals[, 2]
      ),
      row.names = NULL,
      check.names = FALSE
    )
  })

  fit_statistics <- reactive({
    result <- fit_result()
    fit <- result$model
    if (is.null(fit)) return(data.frame(Status = result$error %or% "Model unavailable."))
    info <- summary(fit)
    data.frame(
      Statistic = c(
        "Observations", "R-squared", "Adjusted R-squared",
        "Residual standard error", "AIC", "BIC"
      ),
      Value = c(
        stats::nobs(fit), info$r.squared, info$adj.r.squared,
        info$sigma, stats::AIC(fit), stats::BIC(fit)
      ),
      check.names = FALSE
    )
  })

  draw_diagnostic <- function(fit, dark = FALSE) {
    point_colour <- if (dark) "#72B7F2" else "#1F5A94"
    zero_colour <- if (dark) "#E0E0E0" else "#555555"
    grid_colour <- if (dark) "#55555A" else "#D6D6D6"
    graphics::plot(
      stats::fitted(fit), stats::residuals(fit),
      pch = 19, col = point_colour,
      xlab = "Fitted values", ylab = "Residuals",
      main = "Residuals versus fitted values"
    )
    graphics::abline(h = 0, lty = 2, col = zero_colour)
    graphics::grid(col = grid_colour)
  }

  output$clipboard_status <- renderText(clipboard_status())
  output$data_preview <- renderTable(utils::head(model_data(), 100L), digits = 5)
  output$formula <- renderText({
    result <- fit_result()
    if (is.null(result$model)) return(result$error %or% "Model unavailable.")
    paste(deparse(stats::formula(result$model)), collapse = " ")
  })
  output$coefficients <- renderTable(coefficient_table(), digits = 4)
  output$fit_statistics <- renderTable(fit_statistics(), digits = 4)
  output$diagnostic <- renderPlot({
    result <- fit_result()
    if (is.null(result$model)) {
      graphics::plot.new()
      graphics::text(0.5, 0.5, result$error %or% "Model unavailable.")
      return(invisible(NULL))
    }
    draw_diagnostic(result$model, identical(session$getTheme(), "dark"))
  })
}

runApp(shinyApp(ui, server))
