# Intra-articular ozone knee osteoarthritis RCT (PLOS ONE, pone.0179185; the
# same study as PMC5524330 in the corpus). 98 patients, four assessment waves,
# 386 observations.
#
# This is the one admissible dataset. The displayed rating is a VAS recorded as
# integer centimeters, so it behaves as an 11 point scale and the analogue of a
# 10 point interval on a 0 to 100 VAS is one unit here.
#
# The latent metric is estimated three ways, none of which uses the VAS:
#   WOMAC pain     five items, five categories, the on construct primary
#   GPM binary     22 yes or no items of the Geriatric Pain Measure, an
#                  independent instrument, so a near replication
#   WOMAC full     all 24 items including stiffness and function, which is
#                  off construct and reported only as a sensitivity check
suppressMessages({library(readxl); library(dplyr); library(tidyr); library(purrr)})
source("R/04_interval_curve.R")

RAW <- "data/newdata/pone.0179185.s004.xls"
x <- read_excel(RAW, sheet = 1, .name_repair = "minimal")

vas <- as.numeric(x[["VAS"]])
id  <- as.integer(x[["Number"]])
wk  <- as.integer(x[["Week"]])

# WOMAC is stored as a Likert response rescaled to percent. Recode explicitly
# rather than relying on mirt to re-map categories for us.
womac_cols <- grep("^WOM ", names(x), value = TRUE)
womac <- as.data.frame(lapply(x[womac_cols], function(v) as.numeric(v) / 25))
names(womac) <- womac_cols
stopifnot(all(unlist(womac) %in% c(0:4, NA)))

womac_pain <- womac[, paste0("WOM A-", 1:5)]

# GPM 19 and 20 are themselves pain intensity ratings, correlating 0.998 and
# 0.882 with the VAS. They are displays, not items, and are excluded by name.
gpm_all  <- paste0("GPM ", 1:24)
gpm_bin  <- paste0("GPM ", c(1:18, 21:24))
gpm <- as.data.frame(lapply(x[gpm_bin], as.numeric))
names(gpm) <- gpm_bin

# Near constant binary items give unstable slopes at n = 386. Drop them.
p_endorse <- colMeans(gpm, na.rm = TRUE)
keep_gpm <- names(p_endorse)[p_endorse > 0.05 & p_endorse < 0.95]
message("GPM binary items kept: ", length(keep_gpm), " of ", length(gpm_bin),
        " (dropped: ", paste(setdiff(gpm_bin, keep_gpm), collapse = ", "), ")")
gpm <- gpm[, keep_gpm, drop = FALSE]

BLOCKS <- list(
  "WOMAC pain (5 items)"      = womac_pain,
  "GPM binary (independent)"  = gpm,
  "WOMAC all 24 (sensitivity)" = womac)

GRID <- 0:9; WIDTH <- 1; K <- 6

run_block <- function(items, label) {
  bind_rows(lapply(c("graded", "rasch"), function(m) {
    th <- try(fit_theta(items, m), silent = TRUE)
    if (inherits(th, "try-error")) return(NULL)
    r <- suppressWarnings(cor(th, vas, use = "complete.obs"))
    if (r < 0) th <- -th
    cv <- try(interval_curve(vas, th, width = WIDTH, grid = GRID, k = K), silent = TRUE)
    if (inherits(cv, "try-error")) return(NULL)
    cv$model <- m; cv$block <- label; cv$r <- abs(r)
    cv$scorer <- attr(th, "scorer") %||% NA_character_
    cv
  }))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

curves <- bind_rows(imap(BLOCKS, ~ run_block(.x, .y)))
message("scorers used: ", paste(unique(curves$scorer), collapse = ", "))
print(curves |> group_by(block, model) |> summarise(r = first(r), .groups = "drop"))

# --- cluster bootstrap over patients ------------------------------------------
set.seed(20260911)
boot_block <- function(items, B = 100, model = "graded") {
  ids <- unique(id)
  bind_rows(lapply(seq_len(B), function(b) {
    take <- sample(ids, length(ids), replace = TRUE)
    rows <- unlist(lapply(take, function(i) which(id == i)))
    th <- try(fit_theta(items[rows, , drop = FALSE], model), silent = TRUE)
    if (inherits(th, "try-error")) return(NULL)
    r <- suppressWarnings(cor(th, vas[rows], use = "complete.obs"))
    if (!is.finite(r)) return(NULL)
    if (r < 0) th <- -th
    cv <- try(interval_curve(vas[rows], th, width = WIDTH, grid = GRID, k = K), silent = TRUE)
    if (inherits(cv, "try-error")) return(NULL)
    cv$rep <- b; cv
  }))
}
bb <- boot_block(womac_pain, B = 100)
band <- bb |> group_by(vas) |>
  summarise(lo = quantile(D, 0.1, na.rm = TRUE),
            hi = quantile(D, 0.9, na.rm = TRUE), .groups = "drop")

# --- within person change ------------------------------------------------------
# The question trials actually rely on: does a one unit drop mean the same latent
# improvement starting from a high VAS as from a low one?
th_p <- fit_theta(womac_pain, "graded")
if (cor(th_p, vas, use = "complete.obs") < 0) th_p <- -th_p
long <- tibble(id = id, week = wk, vas = vas, theta = as.numeric(th_p)) |>
  arrange(id, week) |> group_by(id) |>
  mutate(d_vas = vas - lag(vas), d_theta = theta - lag(theta),
         vas_start = lag(vas)) |> ungroup() |>
  filter(is.finite(d_vas), is.finite(d_theta))

# The cross sectional spline gives a prediction for every observed transition.
# Comparing it against what actually happened within each patient is the check
# on whether the curve describes real change or only a between person contrast.
fx <- scam::scam(theta ~ s(vas, bs = "mpi", k = K), data = long)
fpred <- function(v) as.numeric(predict(fx, newdata = data.frame(vas = v)))

drops <- long |> filter(d_vas < 0) |>
  mutate(start_band = cut(vas_start, c(-Inf, 3, 6, Inf),
                          labels = c("start 0 to 3", "start 4 to 6", "start 7 to 10")),
         pred_d_theta = fpred(vas) - fpred(vas_start))
chg <- drops |> group_by(start_band) |>
  summarise(n = n(),
            mean_drop = mean(-d_vas),
            observed_per_unit = mean(d_theta) / mean(-d_vas),
            predicted_per_unit = mean(pred_d_theta) / mean(-d_vas),
            .groups = "drop")
print(as.data.frame(chg))
message("observed vs predicted change, r = ",
        round(cor(drops$d_theta, drops$pred_d_theta), 3))

saveRDS(list(curves = curves, band = band, boot = bb, change = chg, drops = drops,
             long = long, vas = vas, id = id, week = wk,
             n_obs = length(vas), n_pat = length(unique(id))),
        "out/ozone_results.rds")
write.csv(chg, "out/within_person_change.csv", row.names = FALSE)
message("ozone analysis written")
