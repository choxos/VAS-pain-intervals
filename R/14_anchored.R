# Two further checks on the ozone result.
#
# A2. Floor matched null. The first null produced 12 percent zeros against 27
#     percent in the real data. Re-tune a strictly linear VAS so its floor, mean
#     and spread match the real VAS, and rerun the pipeline.
#
# C.  VAS as an anchored item. Calibrate the WOMAC pain items without the VAS,
#     fix those parameters, then add the VAS as an 11 category graded item. The
#     VAS thresholds are estimated by marginal maximum likelihood with latent
#     pain integrated out, so there is no regression dilution and no bias from
#     plugging in individual latent estimates. The gap between consecutive
#     thresholds is the latent width of each 1 cm category.
suppressMessages({library(readxl); library(dplyr); library(mirt); library(scam)})
source("R/04_interval_curve.R")

x <- read_excel("data/newdata/pone.0179185.s004.xls", sheet = 1, .name_repair = "minimal")
vas <- as.numeric(x[["VAS"]]); id <- as.integer(x[["Number"]])
wp <- as.data.frame(lapply(x[paste0("WOM A-", 1:5)], function(v) as.integer(as.numeric(v) / 25)))
names(wp) <- paste0("WOMA", 1:5)
GRID <- 0:9; K <- 6
contrast <- function(D, g) mean(D[g %in% 1:2]) / mean(D[g %in% 5:6])
rob <- readRDS("out/robustness.rds")

# ---- A2. floor matched null --------------------------------------------------
m0 <- mirt(wp, 1, itemtype = "graded", verbose = FALSE)
cf <- coef(m0, simplify = TRUE)$items
a  <- matrix(cf[, "a1"]); d <- as.matrix(cf[, grep("^d", colnames(cf))])
set.seed(2)
pv <- as.numeric(fscores(m0, plausible.draws = 1, verbose = FALSE))
target <- c(floor = mean(vas == 0), mean = mean(vas), sd = sd(vas))
mk <- function(th, al, be, s) round(pmin(pmax(al + be * th + rnorm(length(th), 0, s), 0), 10))
grid <- expand.grid(al = seq(0, 6, 0.25), be = seq(1, 5, 0.25), s = c(1.25, 1.5, 1.75, 2))
set.seed(3)
grid$loss <- apply(grid, 1, function(g) {
  v <- mk(pv, g["al"], g["be"], g["s"])
  sum(((c(mean(v == 0), mean(v), sd(v)) - target) / c(.05, 1, 1))^2)
})
best <- grid[which.min(grid$loss), ]
set.seed(4)
chk_items <- simdata(a = a, d = d, itemtype = "graded", Theta = matrix(pv))
chk_v <- mk(pv, best$al, best$be, best$s)
chk <- c(floor = mean(chk_v == 0), mean = mean(chk_v), sd = sd(chk_v),
         r = cor(fit_theta(chk_items, "graded"), chk_v))

ids <- unique(id)
null2 <- bind_rows(lapply(1:200, function(b) {
  rows <- unlist(lapply(sample(ids, length(ids), TRUE), function(i) which(id == i)))
  th_true <- pv[rows]
  it <- simdata(a = a, d = d, itemtype = "graded", Theta = matrix(th_true))
  v <- mk(th_true, best$al, best$be, best$s)
  th <- try(fit_theta(it, "graded"), silent = TRUE); if (inherits(th, "try-error")) return(NULL)
  cv <- try(interval_curve(v, th, width = 1, grid = GRID, k = K), silent = TRUE)
  if (inherits(cv, "try-error")) return(NULL); cv$rep <- b; cv
}))
null2_band <- null2 |> group_by(vas) |>
  summarise(med = median(D), lo025 = quantile(D, .025), hi975 = quantile(D, .975), .groups = "drop")
null2_ratio <- null2 |> group_by(rep) |> summarise(r = contrast(D, vas), .groups = "drop")

# ---- C. VAS as an anchored graded item ---------------------------------------
anchored <- function(wp, vas, dentype = "Gaussian") {
  m0 <- mirt(wp, 1, itemtype = "graded", verbose = FALSE, dentype = dentype)
  dat <- cbind(wp, VAS = as.integer(vas))
  sv <- mirt(dat, 1, itemtype = "graded", pars = "values", dentype = dentype)
  v0 <- mod2values(m0)
  key_sv <- paste(sv$item, sv$name); key_v0 <- paste(v0$item, v0$name)
  w <- sv$item %in% names(wp)
  stopifnot(all(key_sv[w] %in% key_v0))
  sv$value[w] <- v0$value[match(key_sv[w], key_v0)]
  sv$est[w] <- FALSE
  m1 <- mirt(dat, 1, itemtype = "graded", pars = sv, verbose = FALSE, dentype = dentype,
             technical = list(NCYCLES = 3000))
  p <- coef(m1, IRTpars = TRUE, simplify = TRUE)$items["VAS", ]
  b <- p[grep("^b", names(p))]
  b <- b[is.finite(b)]
  w <- diff(b)                       # latent width of VAS categories 1 to 9
  list(a = p["a"], b = b, width = w / mean(w[1:8]), m1 = m1)
}
cG <- anchored(wp, vas, "Gaussian")
cE <- anchored(wp, vas, "empiricalhist")

set.seed(20260927)
boot_c <- bind_rows(lapply(1:100, function(bb) {
  rows <- unlist(lapply(sample(ids, length(ids), TRUE), function(i) which(id == i)))
  if (length(unique(vas[rows])) < 11) return(NULL)
  r <- try(anchored(wp[rows, ], vas[rows]), silent = TRUE)
  if (inherits(r, "try-error") || length(r$width) != 9) return(NULL)
  data.frame(category = 1:9, width = r$width, rep = bb)
}))
cband <- boot_c |> group_by(category) |>
  summarise(lo = quantile(width, .10), hi = quantile(width, .90),
            lo025 = quantile(width, .025), hi975 = quantile(width, .975), .groups = "drop")
c_ratio <- boot_c |> group_by(rep) |>
  summarise(r = mean(width[category %in% 1:2]) / mean(width[category %in% 5:6]), .groups = "drop")

saveRDS(list(best = best, chk = chk, target = target, null2 = null2, null2_band = null2_band,
             null2_ratio = null2_ratio, cG = cG[c("a", "b", "width")], cE = cE[c("a", "b", "width")],
             boot_c = boot_c, cband = cband, c_ratio = c_ratio), "out/anchored.rds")

cat("\n==== A2. FLOOR MATCHED NULL ====\n")
cat("target:", round(target, 3), "\nsimulated:", round(chk, 3), "\n")
print(left_join(rob$cv_obs |> select(vas, D_obs = D), null2_band, by = "vas") |>
        mutate(across(-vas, ~ round(.x, 2)), outside95 = D_obs < lo025 | D_obs > hi975) |>
        as.data.frame(), row.names = FALSE)
cat(sprintf("contrast D(1,2)/D(5,6): observed %.2f; null median %.2f, 97.5th %.2f; P(null >= obs) = %.3f\n",
            rob$obs_ratio, median(null2_ratio$r), quantile(null2_ratio$r, .975),
            mean(null2_ratio$r >= rob$obs_ratio)))
cat("\n==== C. VAS AS ANCHORED ITEM ====\n")
cat(sprintf("VAS discrimination a = %.2f (Gaussian), %.2f (empirical histogram)\n", cG$a, cE$a))
cat("thresholds (Gaussian):", round(cG$b, 2), "\n")
print(data.frame(category = 1:9, width_gauss = round(cG$width, 2), width_emphist = round(cE$width, 2)) |>
        left_join(cband |> mutate(across(-category, ~ round(.x, 2))), by = "category"), row.names = FALSE)
cat(sprintf("contrast width(1,2)/width(5,6): Gaussian %.2f, empirical histogram %.2f; bootstrap 95%% %.2f to %.2f, n reps = %d\n",
            mean(cG$width[1:2]) / mean(cG$width[5:6]), mean(cE$width[1:2]) / mean(cE$width[5:6]),
            quantile(c_ratio$r, .025), quantile(c_ratio$r, .975), nrow(c_ratio)))
