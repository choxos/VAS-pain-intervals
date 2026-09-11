# Core estimator: how much latent pain does a fixed displayed VAS interval span?
#
# Step 1  fit a unidimensional IRT model to the multi item pain instrument,
#         excluding the VAS, and take EAP factor scores as theta.
# Step 2  regress theta on the displayed VAS with a monotone increasing spline.
# Step 3  D(v) = f(v + w) - f(v) is the latent distance spanned by a w point
#         displayed interval starting at v. Under an interval scale D is flat.
# Step 4  rescale so the mean of D over the middle of the observed VAS
#         distribution equals w, giving the PISA style ruler reading.

suppressMessages({library(mirt); library(scam); library(dplyr)})

fit_theta <- function(items, model = c("graded", "rasch")) {
  model <- match.arg(model)
  items <- as.data.frame(items)
  items[] <- lapply(items, function(x) as.integer(round(as.numeric(x))))
  # mirt needs categories coded from a common floor per item
  items[] <- lapply(items, function(x) x - min(x, na.rm = TRUE))
  keep <- vapply(items, function(x) length(unique(na.omit(x))) > 1, logical(1))
  items <- items[, keep, drop = FALSE]
  stopifnot(ncol(items) >= 3)
  itemtype <- if (model == "graded") "graded" else "Rasch"
  fit <- mirt::mirt(items, model = 1, itemtype = itemtype, verbose = FALSE,
                    technical = list(NCYCLES = 2000))
  as.numeric(mirt::fscores(fit, method = "EAP"))
}

# Monotone increasing spline of theta on displayed score, then first differences.
interval_curve <- function(vas, theta, width = 10, grid = NULL,
                           trim = c(0.05, 0.95), k = 10) {
  ok <- is.finite(vas) & is.finite(theta)
  vas <- vas[ok]; theta <- theta[ok]
  if (is.null(grid)) grid <- seq(floor(min(vas)), ceiling(max(vas)) - width, by = 1)
  d <- data.frame(vas = vas, theta = theta)
  fit <- scam::scam(theta ~ s(vas, bs = "mpi", k = k), data = d)
  f <- function(x) as.numeric(predict(fit, newdata = data.frame(vas = x)))
  D <- f(grid + width) - f(grid)
  # Normalize over the middle of where people actually are, not the empty tails.
  lo <- quantile(vas, trim[1]); hi <- quantile(vas, trim[2]) - width
  core <- grid >= lo & grid <= hi
  if (!any(core)) core <- rep(TRUE, length(grid))
  tibble(vas = grid, D_raw = D, D = width * D / mean(D[core]), in_core = core)
}

boot_curve <- function(vas, items, model = "graded", width = 10, B = 200, ...) {
  n <- length(vas)
  reps <- lapply(seq_len(B), function(b) {
    i <- sample.int(n, n, replace = TRUE)
    th <- try(fit_theta(items[i, , drop = FALSE], model), silent = TRUE)
    if (inherits(th, "try-error")) return(NULL)
    cv <- try(interval_curve(vas[i], th, width = width, ...), silent = TRUE)
    if (inherits(cv, "try-error")) return(NULL)
    cv$rep <- b
    cv
  })
  bind_rows(reps)
}

# --- self check ---------------------------------------------------------------
# Simulate a known compressive display: VAS = 100 * (theta_std)^2 style bend, so
# a 10 point interval near the top must span more latent pain than near the
# bottom. The estimator has to recover an increasing D curve.
demo <- function() {
  set.seed(1)
  n <- 3000
  theta <- rnorm(n)
  # Displayed VAS compresses the top: high theta crowded into few VAS points.
  u <- pnorm(theta)
  vas <- round(100 * u^(1/2.2))          # f_inv is convex, so D should increase
  J <- 8
  a <- runif(J, 1.2, 2.5); b <- seq(-1.5, 1.5, length.out = J)
  items <- sapply(seq_len(J), function(j) {
    p <- plogis(a[j] * (theta - b[j]))
    rbinom(n, 3, p) # 4 category graded-ish item
  })
  th <- fit_theta(items, "graded")
  stopifnot(cor(th, theta) > 0.85)
  th_r <- fit_theta(items, "rasch")
  stopifnot(cor(th_r, theta) > 0.80)
  cv <- interval_curve(vas, th, width = 10)
  core <- cv[cv$in_core, ]
  lowD  <- mean(core$D[core$vas < quantile(core$vas, 0.33)])
  highD <- mean(core$D[core$vas > quantile(core$vas, 0.67)])
  stopifnot(highD > lowD * 1.3)                  # top intervals span more
  stopifnot(abs(mean(core$D) - 10) < 0.5)        # normalization holds
  cat("self check passed: low", round(lowD, 2), "high", round(highD, 2), "\n")
  invisible(cv)
}

if (sys.nframe() == 0L && !interactive()) demo()
