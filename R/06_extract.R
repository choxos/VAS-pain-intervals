# Turn a scored table into an analysis ready pair: a displayed pain rating and
# a block of item level responses measured on the same people.
#
# Auto proposes the columns, then every surviving dataset still gets looked at
# by hand before it goes on the figure. The automatic step is a shortlist, not
# a verdict.
suppressMessages({
  library(dplyr); library(stringr); library(purrr); library(tibble)
  library(readr); library(readxl); library(haven)
})
source("R/04_interval_curve.R")

RATING_RX <- "vas|visual[ _.-]*analog|pain[ _.-]*(intensity|score|rating|level)|^pain|nrs|nprs|vrs"
# Narrower bar for the item block. A column is barred from contributing to theta
# only if it is the displayed scale itself or a near copy of it. Blanket use of
# RATING_RX would delete the best instrument in the corpus, because BPI severity
# items are genuinely named pain_worst, pain_least, pain_average and pain_now.
# Those are legitimate items: the graded model frees every item threshold, so a
# 0 to 10 item response is not assumed linear in latent pain.
DISPLAY_RX <- "vas|visual[ _.-]*analog"
# Item blocks worth trusting: pain intensity and severity instruments only.
# Disability and catastrophizing scales measure a different construct.
ITEM_RX   <- "bpi|womac|koos|hoos|mpq|mcgill|promis|sfmpq|sf_mpq|pain|item|^q[0-9]"
EXCLUDE_RX <- "odi|oswestry|roland|rmdq|pcs|catastroph|hads|depress|anx|sf36|sf_36|eq5d|function|stiff|disab"
# Repeated measures of the same item are not separate items. If most proposed
# items carry a timepoint suffix, theta would become average pain over the
# trial rather than pain at the moment the rating was given.
TIME_RX   <- "(^|[^a-z])(bl|base|baseline|pre|post|before|after|fu|follow)([^a-z]|$)|[_.]?(t|w|m|v)[0-9]+$|[0-9]+(wk|week|mo|month)"

load_table <- function(file, sheet = "1") {
  ext <- tolower(tools::file_ext(file))
  if (ext %in% c("xls", "xlsx")) {
    sh <- excel_sheets(file)
    s2 <- if (sheet %in% sh) sheet else sh[1]
    return(read_excel(file, sheet = s2, .name_repair = "minimal"))
  }
  switch(ext,
    csv = read_csv(file, show_col_types = FALSE, name_repair = "minimal"),
    tsv = read_tsv(file, show_col_types = FALSE, name_repair = "minimal"),
    txt = read_delim(file, show_col_types = FALSE, name_repair = "minimal"),
    sav = read_sav(file), dta = read_dta(file), NULL)
}

numeric_frame <- function(d) {
  keep <- vapply(d, function(x) is.numeric(x) || inherits(x, "haven_labelled"), logical(1))
  n <- as.data.frame(d[, keep, drop = FALSE])
  n[] <- lapply(n, as.numeric)
  n
}

propose <- function(d) {
  num <- numeric_frame(d)
  if (!ncol(num)) return(NULL)
  nm <- tolower(trimws(names(num)))
  stat <- map_dfr(seq_along(num), function(j) {
    x <- num[[j]][is.finite(num[[j]])]
    if (!length(x)) return(tibble(j = j, lo = NA, hi = NA, nu = 0, int = FALSE))
    tibble(j = j, lo = min(x), hi = max(x), nu = length(unique(x)),
           int = all(x == round(x)))
  })
  stat$name <- nm
  stat$excl <- str_detect(stat$name, EXCLUDE_RX)

  # Rating: wide spread, many distinct values, 0 to 100 or 0 to 10.
  rate <- stat |>
    filter(!excl, !is.na(lo), lo >= 0,
           (hi > 20 & hi <= 100 & nu >= 8) | (hi >= 4 & hi <= 11 & nu >= 5)) |>
    mutate(named = str_detect(name, RATING_RX)) |>
    arrange(desc(named), desc(nu))
  if (!nrow(rate)) return(NULL)

  # Items: small integer range, few categories, plausible instrument name.
  # Every rating like column is barred from the item block. Theta has to be
  # estimated without the displayed scale it is being used to test, and a
  # second NRS or a follow-up VAS is still the display, not an item.
  items <- stat |>
    filter(!excl, int, !is.na(lo), lo >= 0, hi <= 10, nu >= 2, nu <= 11,
           !str_detect(name, DISPLAY_RX)) |>
    mutate(named = str_detect(name, ITEM_RX)) |>
    arrange(desc(named))

  longitudinal <- nrow(items) > 0 &&
    mean(str_detect(items$name, TIME_RX)) >= 0.4

  list(stat = stat, rating = rate, items = items, num = num,
       longitudinal = longitudinal)
}

# Build a dataset from a proposal, dropping the rating column from the items.
build <- function(d, rating_j = NULL, item_j = NULL, min_items = 3) {
  p <- propose(d)
  if (is.null(p)) return(NULL)
  rj <- rating_j %||% p$rating$j[1]
  ij <- item_j   %||% setdiff(p$items$j, rj)
  vas <- p$num[[rj]]
  # Drop any near copy of the display. A second recording of the same rating
  # would make theta partly a function of the scale under test.
  if (length(ij)) {
    dup <- vapply(ij, function(j) {
      r <- suppressWarnings(cor(p$num[[j]], vas, use = "complete.obs"))
      is.finite(r) && abs(r) > 0.95
    }, logical(1))
    ij <- ij[!dup]
  }
  if (length(ij) < min_items) return(NULL)
  items <- p$num[, ij, drop = FALSE]
  # mirt handles missing item responses natively, so only the rating is required.
  ok <- is.finite(vas) & rowSums(!is.na(items)) >= min_items
  if (sum(ok) < 50) return(NULL)
  list(vas = vas[ok], items = items[ok, , drop = FALSE],
       rating_name = names(p$num)[rj], item_names = names(p$num)[ij],
       n = sum(ok), scale_max = max(vas[ok], na.rm = TRUE),
       longitudinal = p$longitudinal)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Fit both models and return the interval curve, or NULL with a reason.
analyze <- function(ds, label, panel, width = NULL, B = 0, min_cor = 0.5,
                    allow_longitudinal = FALSE) {
  # Repeated measures of one item are not items. Refuse unless overridden.
  if (isTRUE(ds$longitudinal) && !allow_longitudinal) return(NULL)
  w <- width %||% if (ds$scale_max > 20) 10 else 1
  out <- list()
  for (m in c("graded", "rasch")) {
    th <- try(fit_theta(ds$items, m), silent = TRUE)
    if (inherits(th, "try-error")) next
    r <- suppressWarnings(cor(th, ds$vas, use = "complete.obs"))
    if (!is.finite(r) || abs(r) < min_cor) next
    if (r < 0) th <- -th   # orient theta so more pain is higher
    cv <- try(interval_curve(ds$vas, th, width = w), silent = TRUE)
    if (inherits(cv, "try-error")) next
    cv$model <- m; cv$dataset <- label; cv$panel <- panel
    cv$r <- r; cv$n <- ds$n; cv$width <- w
    cv$scorer <- attr(th, "scorer") %||% NA_character_
    cv$display <- ds$rating_name
    cv$n_items <- length(ds$item_names)
    out[[m]] <- cv
  }
  if (!length(out)) return(NULL)
  bind_rows(out)
}
