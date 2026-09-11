# The PISA style figure, in the two forms the evidence actually supports.
#
# Panel A is simulated data where the display's nonlinearity is known by
# construction, so the estimator can be checked against a truth curve. This is
# what the figure looks like when the data exist.
# Panel B is the only corpus dataset that qualified. It is shown with its
# bootstrap band and its coverage gap, and it does not support a conclusion.
suppressMessages({library(ggplot2); library(dplyr); library(tidyr); library(scam); library(mirt)})
source("R/04_interval_curve.R")

SURF <- "#fcfcfb"; INK <- "#0b0b0b"; INK2 <- "#52514e"; GRID <- "#e6e5e1"
S1 <- "#2a78d6"; S2 <- "#eb6834"; THIN <- "#b9c6d6"
set.seed(20260910)

# --- truth: VAS = 100 * pnorm(theta)^(1/2.2), so the top is compressed --------
POW <- 2.2
f_inv <- function(v) qnorm(pmin(pmax((v / 100)^POW, 1e-6), 1 - 1e-6))
# Restrict to where simulated respondents actually sit. Below about VAS 5 the
# inverse normal diverges and the curve there describes the tail of the prior,
# not the display.
grid  <- 8:82
D_true <- f_inv(grid + 10) - f_inv(grid)
truth <- tibble(vas = grid, D = 10 * D_true / mean(D_true), model = "Truth")

sim_cohort <- function(n = 600, J = 8) {
  theta <- rnorm(n)
  vas <- round(100 * pnorm(theta)^(1 / POW))
  a <- runif(J, 1.2, 2.5); b <- seq(-1.5, 1.5, length.out = J)
  items <- sapply(seq_len(J), function(j) rbinom(n, 3, plogis(a[j] * (theta - b[j]))))
  list(vas = vas, items = items)
}

sims <- lapply(1:12, function(k) {
  d <- sim_cohort()
  bind_rows(lapply(c("graded", "rasch"), function(m) {
    th <- try(fit_theta(d$items, m), silent = TRUE)
    if (inherits(th, "try-error")) return(NULL)
    cv <- try(interval_curve(d$vas, th, width = 10, grid = grid), silent = TRUE)
    if (inherits(cv, "try-error")) return(NULL)
    cv$model <- m; cv$cohort <- k; cv
  }))
})
sim <- bind_rows(sims)
sim_med <- sim |> group_by(model, vas) |> summarise(D = median(D), .groups = "drop")

dsamp <- density(round(100 * pnorm(rnorm(2e5))^(1 / POW)), from = min(grid), to = max(grid), n = 120)
dens <- tibble(vas = dsamp$x, y = 0.4 + 3.6 * dsamp$y / max(dsamp$y))

pA <- ggplot() +
  geom_area(data = dens, aes(vas, y), fill = "#dfe6ee", colour = NA) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = 9.5, ymax = 10.5,
           fill = "#ecebe7") +
  geom_hline(yintercept = 10, linetype = "dashed", colour = INK2, linewidth = 0.4) +
  geom_line(data = sim, aes(vas, D, group = interaction(cohort, model)),
            colour = THIN, linewidth = 0.3) +
  geom_line(data = truth, aes(vas, D), colour = INK, linewidth = 1.5, linetype = "21") +
  geom_line(data = sim_med, aes(vas, D, colour = model), linewidth = 1.3) +
  scale_colour_manual(values = c(graded = S2, rasch = S1),
                      limits = c("graded", "rasch"),
                      labels = c("Graded model", "Rasch model"), name = NULL) +
  annotate("text", x = 40, y = 10.7, label = "Equal intervals = 10",
           hjust = 0, size = 3.1, colour = INK2) +
  annotate("text", x = 46, y = 1.4, label = "Where people are",
           hjust = 0.5, size = 3.1, colour = INK2, fontface = "italic") +
  annotate("text", x = 76, y = 15.6, label = "True curve", hjust = 0, size = 3.4,
           colour = INK, fontface = "bold") +
  scale_x_continuous(limits = c(5, 95), breaks = seq(10, 80, 20)) +
  coord_cartesian(ylim = c(0, 18)) +
  labs(subtitle = "A.  Simulated data, where the answer is known",
       x = "Displayed VAS score", y = "Latent pain spanned by 10 displayed VAS points") +
  theme_minimal(base_size = 12)

pB_data <- readRDS("out/results.rds")
cv <- pB_data$curves; band <- pB_data$band
st <- pB_data$stacked
gap <- range(st$vas[st$vas > 50 & st$vas < 62])

d2 <- density(st$vas, from = 0, to = 90, n = 120)
dens2 <- tibble(vas = d2$x, y = 0.7 + 6.5 * d2$y / max(d2$y))

pB <- ggplot() +
  geom_area(data = dens2, aes(vas, y), fill = "#dfe6ee", colour = NA) +
  annotate("rect", xmin = 55, xmax = 60, ymin = -Inf, ymax = Inf,
           fill = "#f3d9cd", alpha = 0.85) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = 9.5, ymax = 10.5, fill = "#ecebe7") +
  geom_hline(yintercept = 10, linetype = "dashed", colour = INK2, linewidth = 0.4) +
  geom_ribbon(data = band, aes(vas, ymin = lo, ymax = hi), fill = S1, alpha = 0.16) +
  geom_line(data = cv, aes(vas, D, colour = model), linewidth = 1.2) +
  scale_colour_manual(values = c(graded = S2, rasch = S1),
                      limits = c("graded", "rasch"),
                      labels = c("Graded model", "Rasch model"), name = NULL) +
  annotate("text", x = 57.5, y = 31, label = "no data\nhere", size = 3, colour = "#9a4a22",
           lineheight = 0.95, fontface = "bold") +
  annotate("text", x = 6, y = 11.4, label = "Equal intervals = 10",
           hjust = 0, size = 3.1, colour = INK2) +
  scale_x_continuous(limits = c(0, 95), breaks = seq(0, 80, 20)) +
  coord_cartesian(ylim = c(0, 34)) +
  labs(subtitle = "B.  The only qualifying dataset: n = 57, two occasions",
       x = "Displayed VAS score", y = NULL) +
  theme_minimal(base_size = 12)

common <- theme(
  plot.background  = element_rect(fill = SURF, colour = NA),
  panel.background = element_rect(fill = SURF, colour = NA),
  panel.grid.minor = element_blank(),
  panel.grid.major = element_line(colour = GRID, linewidth = 0.3),
  plot.subtitle = element_text(face = "bold", size = 12, colour = INK),
  axis.text = element_text(colour = INK2), axis.title = element_text(colour = INK2, size = 9.5),
  legend.position = "top", legend.text = element_text(colour = INK2))

suppressMessages(library(patchwork))
fig <- (pA + common) + (pB + common + theme(legend.position = "none")) +
  plot_layout(guides = "keep") +
  plot_annotation(
    title = "Is 10 points of pain always 10 points? The method works; the shared data cannot carry it.",
    subtitle = "Latent pain spanned by a 10 point interval on the 0 to 100 VAS, normalized so an equal interval scale reads 10.\nLeft: 12 simulated cohorts where the display compresses the top by construction; the estimator recovers it.\nRight: the single dataset out of 4,567 papers with item level pain responses. Its curve rises through a stretch of the scale where it has no data.",
    caption = "Latent pain estimated by item response models fitted to a multi item pain instrument, excluding the VAS. Thin lines are cohorts, bold lines medians.\nPanel B band is a 150 replicate participant level bootstrap, 10th to 90th percentile. Note the panels use different y ranges: B reaches 34, A only 18.\nPanel B is not evidence about the VAS. It is evidence about the data supply.",
    theme = theme(
      plot.background = element_rect(fill = SURF, colour = NA),
      plot.title = element_text(face = "bold", size = 16, colour = INK),
      plot.subtitle = element_text(size = 10.5, colour = INK2, lineheight = 1.25),
      plot.caption = element_text(size = 8, colour = INK2, hjust = 0, lineheight = 1.2)))

ggsave("out/figures/fig4_interval_curve.png", fig, width = 13, height = 7, dpi = 200, bg = SURF)
message("main figure written")
