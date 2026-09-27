# Validate the anchored estimator the same way the spline estimator was tested.
#  C1. Under the floor matched null (VAS exactly linear in latent pain), the
#      anchored model should return equal category widths.
#  C2. Anchor on the Geriatric Pain Measure instead of the WOMAC. If the uneven
#      widths reflect how people use the VAS, they should reappear.
suppressMessages({library(readxl); library(dplyr); library(mirt)})
x <- read_excel("data/newdata/pone.0179185.s004.xls", sheet = 1, .name_repair = "minimal")
vas <- as.numeric(x[["VAS"]]); id <- as.integer(x[["Number"]])
wp <- as.data.frame(lapply(x[paste0("WOM A-", 1:5)], function(v) as.integer(as.numeric(v) / 25)))
names(wp) <- paste0("WOMA", 1:5)
gpm <- as.data.frame(lapply(x[paste0("GPM ", c(1:18, 21:24))], as.numeric))
gpm <- gpm[, colMeans(gpm) > 0.05 & colMeans(gpm) < 0.95]
names(gpm) <- paste0("GPM", seq_along(gpm))
an <- readRDS("out/anchored.rds")

anchored_w <- function(items, vas, itemtype) {
  m0 <- mirt(items, 1, itemtype = itemtype, verbose = FALSE)
  dat <- cbind(items, VAS = as.integer(vas))
  types <- c(rep(itemtype, ncol(items)), "graded")
  sv <- mirt(dat, 1, itemtype = types, pars = "values")
  v0 <- mod2values(m0); w <- sv$item %in% names(items)
  sv$value[w] <- v0$value[match(paste(sv$item, sv$name)[w], paste(v0$item, v0$name))]
  sv$est[w] <- FALSE
  m1 <- mirt(dat, 1, itemtype = types, pars = sv, verbose = FALSE, technical = list(NCYCLES = 3000))
  p <- coef(m1, IRTpars = TRUE, simplify = TRUE)$items["VAS", ]
  b <- p[grep("^b", names(p))]; b <- b[is.finite(b)]
  wd <- diff(b); wd / mean(wd[1:min(8, length(wd))])
}

# C1: null
m0 <- mirt(wp, 1, itemtype = "graded", verbose = FALSE)
cf <- coef(m0, simplify = TRUE)$items
a <- matrix(cf[, "a1"]); d <- as.matrix(cf[, grep("^d", colnames(cf))])
set.seed(2); pv <- as.numeric(fscores(m0, plausible.draws = 1, verbose = FALSE))
be <- an$best
ids <- unique(id)
set.seed(11)
nullC <- do.call(rbind, lapply(1:60, function(r) {
  rows <- unlist(lapply(sample(ids, length(ids), TRUE), function(i) which(id == i)))
  th <- pv[rows]
  it <- as.data.frame(simdata(a = a, d = d, itemtype = "graded", Theta = matrix(th)))
  names(it) <- names(wp)
  v <- round(pmin(pmax(be$al + be$be * th + rnorm(length(th), 0, be$s), 0), 10))
  if (length(unique(v)) < 11) return(NULL)
  w <- try(anchored_w(it, v, "graded"), silent = TRUE)
  if (inherits(w, "try-error") || length(w) != 9) return(NULL)
  w
}))
cat("==== C1. anchored estimator under the floor matched null ====\n")
cat("reps:", nrow(nullC), "\n")
print(round(rbind(median = apply(nullC, 2, median),
                  q025 = apply(nullC, 2, quantile, .025),
                  q975 = apply(nullC, 2, quantile, .975)), 2))
r_null <- (nullC[, 1] + nullC[, 2]) / (nullC[, 5] + nullC[, 6])
cat(sprintf("null contrast width(1,2)/width(5,6): median %.2f, 95%% %.2f to %.2f\n",
            median(r_null), quantile(r_null, .025), quantile(r_null, .975)))

# C2: GPM anchor
wg <- anchored_w(gpm, vas, "2PL")
cat("\n==== C2. anchored on GPM (independent instrument) ====\n")
print(round(data.frame(category = 1:9, womac_anchor = an$cG$width, gpm_anchor = wg), 2), row.names = FALSE)
cat(sprintf("correlation of width profiles: %.2f\n", cor(an$cG$width, wg)))
cat("\nVAS response frequencies:\n"); print(table(vas))
fr <- as.numeric(table(vas))[2:10]
cat(sprintf("cor(category width, category frequency), WOMAC anchor: %.2f; GPM anchor: %.2f\n",
            cor(an$cG$width, fr), cor(wg, fr)))
saveRDS(list(nullC = nullC, r_null = r_null, wg = wg), "out/anchored_checks.rds")
