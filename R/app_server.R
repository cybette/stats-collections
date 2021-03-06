#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny ggplot2 plotly
#' @importFrom dplyr select mutate across pull
#' @importFrom purrr map
#' @importFrom survival survfit Surv
#' @importFrom survminer ggsurvplot surv_median
#' @importFrom stringr str_to_title
#' @noRd
app_server <- function( input, output, session ) {

  colours = c("closed"='#CB333B',"opened"='#5bbdc0')

  repo_data <- reactive({
    req(input$repo)
    get_repo_data(input$repo)
  })

  output$repoSelect <- renderUI({
    repositories <- get_repos()

    selectInput("repo", "Collection",
                choices = repositories,
                selected = 'ansible-collections/community.general')
  })

  output$survival_plot <- renderPlot({
    req(input$repo)
    switch (input$graph_type,
      'ttclose'   = issues_survival_plot(repo_data()),
      'ttcomment' = comments_survival_plot(repo_data()),
      'galaxy'    = galaxy_plot(input$repo)
    )
  })

  output$timeseries_plot <- renderPlot({
    req(input$repo)
    get_timeseries(input$repo)
  })

  output$bar_plot <- renderPlotly({
    p <- repo_data() %>%
      get_issue_trends() %>%
      rename(Date = date, Count = n) %>%
      ggplot(aes(x=Date, y = Count, fill = id)) +
      geom_col(position='dodge') +
      scale_x_date(date_breaks = '1 week', date_labels = '%d/%m') +
      scale_fill_manual(name = NULL,
                          values = colours,
                          labels = c("Closed","Opened")) +
      labs(title = 'Issues & PRs Opened/Closed',
           x = 'Week Commencing', y = NULL) +
      theme(legend.position = 'top')

    ggplotly(p, tooltip = c('Date','Count')) %>%
      config(modeBarButtonsToRemove = list('select2d','lasso2d'),
             displaylogo = FALSE, scrollZoom = FALSE) %>%
      layout(xaxis=list(fixedrange=TRUE)) %>%
      layout(yaxis=list(fixedrange=TRUE))
  })

  output$label_table <- DT::renderDT({
    req(input$repo)
    d <- repo_data()

    req(d$labels)
    req(purrr::map_int(d$labels,length) %>% sum() > 0)

    d %>%
      # Handle NULL vs empty lists, sigh
      mutate(id3 = purrr::map_int(labels,length)) %>%
      mutate(labels = if_else(id3==0,list(c()),labels)) %>%
      # Now we can actually split & count
      tidyr::unnest(labels) %>%
      group_by(state) %>%
      dplyr::count(labels,sort=T) %>%
      tidyr::pivot_wider(names_from = state, values_from = n) %>%
      rename(Label = labels) %>%
      DT::datatable(options = list(pageLength = 10,
                                   lengthChange = F, searching = F))
  })

  output$issuesBox <- renderValueBox({
    req(input$repo)
    d <- repo_data() %>%
        count(type,state) %>%
        filter(type == 'issue' & state == 'OPEN') %>%
        pull(n)
    if (length(d) == 0) d <- 0
    valueBox(
      d, "Issues Open", icon = icon("exclamation-circle"),
      color = "green"
    )
  })

  output$pullsBox <- renderValueBox({
    req(input$repo)
    d <- repo_data() %>%
      count(type,state) %>%
      filter(type == 'pull' & state == 'OPEN') %>%
      pull(n)
    if (length(d) == 0) d <- 0
    valueBox(
      d, "Pull Requests Open", icon = icon("exchange-alt"),
      color = "yellow"
    )
  })

  output$contribBox <- renderValueBox({
    req(input$repo)
    d <- repo_data() %>%
      distinct(author) %>%
      count() %>%
      pull(n)
    if (length(d) == 0) d <- 0
    valueBox(
      d , "Unique Contributors\n(by Github login)",
      icon = icon("users"),
      color = "aqua"
    )
  })

  output$timeSinceLastUpdate <- renderUI({
    # Get this from the DB later
    p(
      class = "text-muted",
      "Data refreshed",
      round(digits = 1,
        difftime(
          Sys.time(),
          ymd_hms(setup_mongo('cron')$find()$last_run),
          units="hours")
      ),
      " hours ago."
    )
  })
}
