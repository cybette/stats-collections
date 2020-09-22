#' Takes a list of issues / PRs from Mongo and computes the survival
#' fit for both types
#'
#' @keywords internal
#' @export
#' @importFrom lubridate ymd_hms
#' @importFrom dplyr select mutate
#' @noRd
get_survival_fit <- function(d) {
  d %>%
    filter(type == 'issue' | baseRefName %in% c('main', 'master')) %>%
    mutate(final_time = if_else(is.na(closedAt), Sys.time(), ymd_hms(closedAt)),
           time       = difftime(final_time, ymd_hms(createdAt), units = 'days'),
           status     = if_else(state == 'OPEN', 0, 1)
    ) %>%
    select(time, status, type)
}

#' Takes a list of issues / PRs from Mongo and counts them up by
#' day/week/month for both opened (createdAt) and closed (closedAt) values.
#'
#' @keywords internal
#' @export
#' @importFrom lubridate ymd_hms
#' @importFrom dplyr bind_rows mutate
#' @noRd
get_issue_trends <- function(d) {
  # We start with a list of Issues and PRs

  d <- d %>%
    mutate(createdAt = ymd_hms(createdAt),
           closedAt  = ymd_hms(closedAt))

  bind_rows(
    bin_by_time(d, createdAt, 'week', 'opened'),
    bin_by_time(d, closedAt, 'week', 'closed')
  ) %>%
    group_by(id) %>%
    arrange(desc(date)) %>%
    slice(2:9) # last 8 weeks, not counting this week as it's likely incomplete
}

#' Tidyeval function to do the actual date-cutting and counting on a given
#' column.
#'
#' @keywords internal
#' @import rlang
#' @importFrom dplyr mutate filter count arrange if_else
#' @noRd
bin_by_time <- function(dat,var,period='month',id=NULL) {
  dat %>%
    filter(!(is.na({{var}}))) %>%
    mutate(date = as.Date(cut({{var}},period))) %>%
    count(date) %>%
    mutate(id = if_else(is.null(id),
                        rlang::as_name(ensym(var)),
                        id)) %>%
    arrange(date)
}