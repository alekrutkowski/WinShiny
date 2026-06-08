library(WinShiny)

choices <- c("Alpha" = "a", "Beta" = "b", "Gamma" = "c")

ui <- fluidPage(
  selectInput(
    "search_single", "Search single", choices,
    selected = "b", selectize = TRUE
  ),
  selectInput(
    "search_multiple", "Search multiple", choices,
    selected = c("a", "c"), multiple = TRUE, selectize = TRUE
  ),
  varSelectInput(
    "search_variable", "Search variable", mtcars,
    selected = "mpg", selectize = TRUE
  ),
  selectizeInput(
    "explicit_search", "Explicit search", choices,
    selected = "a", options = list(placeholder = "Find an item")
  ),
  varSelectizeInput(
    "explicit_variable", "Explicit variable", mtcars,
    selected = "wt"
  ),
  selectInput(
    "plain_single", "Plain single", choices,
    selected = "a", selectize = FALSE
  ),
  selectInput(
    "plain_multiple", "Plain multiple", choices,
    selected = c("a", "b"), multiple = TRUE, selectize = FALSE
  )
)

nodes <- WinShiny:::collect_nodes(ui)
script <- WinShiny:::make_ps1(
  nodes,
  tempfile("events"), tempfile("state"), tempfile("commands"),
  tempfile("ready"), tempfile("log")
)

stopifnot(
  grepl("function New-WinShinySelectizeControl", script, fixed = TRUE),
  grepl("function Set-WinShinySelectizeItems", script, fixed = TRUE),
  grepl("function Set-WinShinySelectizeSelectedValues", script, fixed = TRUE),
  grepl("winshiny-selectize-inline", script, fixed = TRUE),
  grepl("Find an item", script, fixed = TRUE),
  grepl("Display='Alpha';Value='a'", script, fixed = TRUE),
  grepl("ChoicesBorder.Visibility = 'Collapsed'", script, fixed = TRUE),
  grepl("Send-Event $State.InputId $values", script, fixed = TRUE),
  !grepl("function Show-SelectizeDialog", script, fixed = TRUE),
  !grepl("$window.ShowDialog()", script, fixed = TRUE),
  grepl("\\$input_search_single_[0-9]+=New-WinShinySelectizeControl", script),
  grepl("\\$input_search_multiple_[0-9]+=New-WinShinySelectizeControl", script),
  grepl("\\$input_search_variable_[0-9]+=New-WinShinySelectizeControl", script),
  grepl("\\$input_explicit_search_[0-9]+=New-WinShinySelectizeControl", script),
  grepl("\\$input_explicit_variable_[0-9]+=New-WinShinySelectizeControl", script),
  !grepl("\\$input_plain_single_[0-9]+=New-WinShinySelectizeControl", script),
  !grepl("\\$input_plain_multiple_[0-9]+=New-WinShinySelectizeControl", script),
  grepl(
    "$ctl=New-WinShinySelectizeControl -Items ([object[]]$choiceEntries)",
    script,
    fixed = TRUE
  ),
  grepl(
    "Set-WinShinySelectizeItems -Control $ctl",
    script,
    fixed = TRUE
  ),
  grepl(
    "Set-WinShinySelectizeTheme -Control $ctl -DarkMode $dark",
    script,
    fixed = TRUE
  )
)

ps1 <- system.file("powershell", "New-SelectizeControl.ps1", package = "WinShiny")
stopifnot(nzchar(ps1), file.exists(ps1))
