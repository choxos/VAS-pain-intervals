# Robustness of the ozone result. Two checks that decide what the finding means.
#
# A. Null simulation. Build a VAS that is exactly linear in latent pain, with a
#    realistic floor and realistic noise, give it the real latent distribution and
#    the real WOMAC item parameters, and run the identical pipeline. Whatever
#    shape comes out is what the method produces when the VAS IS an interval
#    scale. Only departures outside that null band count as evidence.
#
# B. Sum score benchmark. Run the same curve on each instrument's own raw total
#    against the other instrument's latent metric. If raw totals show the same
#    U shape, the shape is the generic bounded score versus logit ogive rather
#    than anything specific to the VAS.
suppressMessages({library(readxl); library(dplyr); library(mirt); library(scam)})
source("R/04_interval_curve.R")

x <- read_excel("data/newdata/pone.0179185.s004.xls", sheet = 1, .name_repair = "minimal")
vas <- as.numeric(x[["VAS"]]); id <- as.integer(x[["Number"]])
wp <- as.data.frame(lapply(x[paste0("WOM A-", 1:5)], function(v) as.integer(as.numeric(v) / 25)))
gpm <- as.data.frame(lapply(x[paste0("GPM ", c(1:18, 21:24))], as.numeric))
gpm <- gpm[, colMeans(gpm) > 0.05 & colMeans(gpm) < 0.95]

GRID <- 0:9; K <- 6
contrast <- function(D, vasgrid) mean(D[vasgrid %in% 1:2]) / mean(D[vasgrid %in% 5:6])

# ---- observed ---------------------------------------------------------------
th_obs <- fit_theta(wp, "graded")
cv_obs <- interval_curve(vas, th_obs, width = 1, grid = GRID, k = K)
obs_ratio <- contrast(cv_obs$D, cv_obs$vas)

# ---- A. null simulation ------------------------------------------------------
m  <- mirt(wp, 1, itemtype = "graded", verbose = FALSE)
cf <- coef(m, simplify = TRUE)$items
a  <- matrix(cf[, "a1"]); d <- as.matrix(cf[, grep("^d", colnames(cf))])
# Plausible values carry the real latent distribution, lumps and floor included,
# without the extreme single values WLE assigns to all zero patterns.
pv <- as.numeric(fscores(m, plausible.draws = 1, verbose = FALSE))
lf <- lm(vas ~ pv)
alpha <- coef(lf)[1]; beta <- coef(lf)[2]
sig_grid <- seq(1.0, 3.0, by = 0.25)

sim_vas <- function(theta, s) round(pmin(pmax(alpha + beta * theta + rnorm(length(theta), 0, s), 0), 10))

# Tune the VAS noise so the simulated data look like the real data on the two
# numbers that matter: correlation with the latent estimate and the floor.
set.seed(1)
tune <- sapply(sig_grid, function(s) {
  it <- simdata(a = a, d = d, itemtype = "graded", Theta = matrix(pv))
  v  <- sim_vas(pv, s); th <- fit_theta(it, "graded")
  c(sigma = s, r = cor(th, v), floor = mean(v == 0))
})
tune <- as.data.frame(t(tune))
real <- c(r = cor(th_obs, vas), floor = mean(vas == 0))
s_best <- tune$sigma[which.min(abs(tune$r - real["r"]) + abs(tune$floor - real["floor"]))]

ids <- unique(id); B <- 200
null <- lapply(seq_len(B), function(b) {
  take <- sample(ids, length(ids), replace = TRUE)
  rows <- unlist(lapply(take, function(i) which(id == i)))
  th_true <- pv[rows]
  it <- simdata(a = a, d = d, itemtype = "graded", Theta = matrix(th_true))
  v  <- sim_vas(th_true, s_best)
  th <- try(fit_theta(it, "graded"), silent = TRUE)
  if (inherits(th, "try-error")) return(NULL)
  cv <- try(interval_curve(v, th, width = 1, grid = GRID, k = K), silent = TRUE)
  if (inherits(cv, "try-error")) return(NULL)
  cv$rep <- b; cv
})
null <- bind_rows(null)
null_band <- null |> group_by(vas) |>
  summarise(med = median(D), lo = quantile(D, .10), hi = quantile(D, .90),
            lo025 = quantile(D, .025), hi975 = quantile(D, .975), .groups = "drop")
null_ratio <- null |> group_by(rep) |> summarise(r = contrast(D, vas), .groups = "drop")

# ---- B. sum score benchmark --------------------------------------------------
th_wp  <- th_obs
th_gpm <- fit_theta(gpm, "graded")
wp_sum  <- rowSums(wp)
gpm_sum <- rowSums(gpm)
rel <- function(score, theta, width, lab) {
  cv <- interval_curve(score, theta, width = width,
                       grid = seq(0, max(score) - width), k = 8)
  cv$pos <- 100 * (cv$vas + width / 2) / max(score); cv$measure <- lab; cv
}
bench <- bind_rows(
  rel(vas,     th_gpm, 1, "VAS vs GPM latent"),
  rel(vas,     th_wp,  1, "VAS vs WOMAC latent"),
  rel(wp_sum,  th_gpm, 2, "WOMAC pain sum vs GPM latent"),
  rel(gpm_sum, th_wp,  2, "GPM sum vs WOMAC latent"))

saveRDS(list(cv_obs = cv_obs, obs_ratio = obs_ratio, null = null, null_band = null_band,
             null_ratio = null_ratio, tune = tune, real = real, s_best = s_best,
             bench = bench), "out/robustness.rds")

cat("\n==== A. NULL SIMULATION ====\n")
cat(sprintf("real data: r = %.3f, floor = %.3f; chosen VAS noise sd = %.2f\n", real["r"], real["floor"], s_best))
print(tune |> mutate(across(everything(), ~ round(.x, 3))), row.names = FALSE)
cat("\nobserved vs null, D by VAS:\n")
print(left_join(cv_obs |> select(vas, D_obs = D), null_band, by = "vas") |>
        mutate(across(-vas, ~ round(.x, 2)), outside80 = D_obs < lo | D_obs > hi,
               outside95 = D_obs < lo025 | D_obs > hi975) |> as.data.frame(), row.names = FALSE)
cat(sprintf("\ncontrast D(1,2)/D(5,6): observed %.2f; null median %.2f, 90th %.2f, 97.5th %.2f; P(null >= obs) = %.3f\n",
            obs_ratio, median(null_ratio$r), quantile(null_ratio$r, .9), quantile(null_ratio$r, .975),
            mean(null_ratio$r >= obs_ratio)))
cat("\n==== B. SUM SCORE BENCHMARK (D by relative position, % of range) ====\n")
print(bench |> mutate(bin = cut(pos, c(0, 20, 40, 60, 80, 100))) |>
        group_by(measure, bin) |> summarise(D = round(mean(D), 2), .groups = "drop") |>
        tidyr::pivot_wider(names_from = bin, values_from = D) |> as.data.frame(), row.names = FALSE)
