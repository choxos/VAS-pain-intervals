# The headline figure, now that an admissible dataset exists.
#  A  simulation where the display's nonlinearity is known, as validation
#  B  the ozone trial: how much latent pain a one centimeter VAS step spans
#  C  within person check: does the curve describe real change
suppressMessages({library(ggplot2); library(dplyr); library(tidyr); library(patchwork)})

SURF <- "#fcfcfb"; INK <- "#0b0b0b"; INK2 <- "#52514e"; GRID <- "#e6e5e1"
S1 <- "#2a78d6"; S2 <- "#eb6834"; S3 <- "#1baf7a"

r <- readRDS("out/ozone_results.rds")
cv <- r$curves; band <- r$band

# Endpoints are floor and ceiling: 27 percent of observations sit at VAS 0 and
# the top step rests on 24 rows. Drawn faded, as the PISA plot fades its tails.
cv <- cv |> mutate(core = vas >= 1 & vas <= 8)
vd <- as.data.frame(table(r$vas)) |>
  transmute(vas = as.numeric(as.character(Var1)), n = Freq) |>
  mutate(y = 0.06 + 0.46 * n / max(n))

seg <- function(d) d |> arrange(block, model, vas)

pA <- {
  sim <- readRDS("out/sim_validation.rds")
  ggplot() +
    annotate("rect", xmin = -Inf, xmax = Inf, ymin = 9.5, ymax = 10.5, fill = "#ecebe7") +
    geom_hline(yintercept = 10, linetype = "dashed", colour = INK2, linewidth = 0.4) +
    geom_line(data = sim$thin, aes(vas, D, group = interaction(cohort, model)),
              colour = "#b9c6d6", linewidth = 0.3) +
    geom_line(data = sim$truth, aes(vas, D), colour = INK, linewidth = 1.4, linetype = "21") +
    geom_line(data = sim$med, aes(vas, D, colour = model), linewidth = 1.2) +
    scale_colour_manual(values = c(graded = S2, rasch = S1), limits = c("graded","rasch"),
                        labels = c("Graded model","Rasch model"), name = NULL) +
    annotate("text", x = 74, y = 15.6, label = "True curve", hjust = 0, size = 3.2,
             colour = INK, fontface = "bold") +
    scale_x_continuous(limits = c(5, 95), breaks = seq(10, 80, 20)) +
    coord_cartesian(ylim = c(0, 18)) +
    labs(subtitle = "A.  Validation: simulated data, answer known",
         x = "Displayed VAS score", y = "Latent pain per displayed interval\n(equal intervals = reference line)")
}

pB <- ggplot() +
  annotate("rect", xmin = -Inf, xmax = 0.5, ymin = -Inf, ymax = Inf, fill = "#f6f2ee") +
  annotate("rect", xmin = 8.5, xmax = Inf, ymin = -Inf, ymax = Inf, fill = "#f6f2ee") +
  geom_col(data = vd, aes(vas, y), fill = "#cfdae8", width = 0.85) +
  geom_text(data = vd, aes(vas, y, label = n), vjust = -0.45, size = 2.5, colour = INK2) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = 0.95, ymax = 1.05, fill = "#ecebe7") +
  geom_hline(yintercept = 1, linetype = "dashed", colour = INK2, linewidth = 0.4) +
  geom_ribbon(data = band, aes(vas, ymin = lo, ymax = hi), fill = S1, alpha = 0.15) +
  geom_line(data = seg(filter(cv, model == "graded")),
            aes(vas, D, colour = block), linewidth = 1.2) +
  geom_point(data = seg(filter(cv, model == "graded")),
             aes(vas, D, colour = block), size = 1.7) +
  scale_colour_manual(values = setNames(c(S2, S1, S3), unique(cv$block)), name = NULL) +
  scale_x_continuous(breaks = 0:9) +
  annotate("text", x = 0, y = 2.45, label = "floor", size = 2.8, colour = "#8a7a6a") +
  annotate("text", x = 9, y = 2.45, label = "ceiling", size = 2.8, colour = "#8a7a6a") +
  annotate("text", x = 4.5, y = 1.14, label = "Equal intervals", size = 3, colour = INK2) +
  coord_cartesian(ylim = c(0, 2.6)) +
  labs(subtitle = "B.  Ozone knee OA trial: 98 patients, 386 observations",
       x = "Displayed VAS score (cm)", y = "Latent pain spanned by a 1 cm step")

chg <- r$change |>
  pivot_longer(c(observed_per_unit, predicted_per_unit)) |>
  mutate(value = abs(value),
         name = recode(name, observed_per_unit = "Observed within patient",
                             predicted_per_unit = "Predicted by panel B"))
pC <- ggplot(chg, aes(start_band, value, fill = name)) +
  geom_col(position = position_dodge(width = 0.72), width = 0.62) +
  geom_text(aes(label = sprintf("%.2f", value)), position = position_dodge(width = 0.72),
            vjust = -0.6, size = 3, colour = INK2) +
  scale_fill_manual(values = c("Observed within patient" = S2,
                               "Predicted by panel B" = "#b9c6d6"), name = NULL) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
  labs(subtitle = "C.  Does the curve describe real change?",
       x = NULL, y = "Latent improvement per 1 cm drop")

common <- theme_minimal(base_size = 11) + theme(
  plot.background = element_rect(fill = SURF, colour = NA),
  panel.background = element_rect(fill = SURF, colour = NA),
  panel.grid.minor = element_blank(),
  panel.grid.major = element_line(colour = GRID, linewidth = 0.3),
  plot.subtitle = element_text(face = "bold", size = 10.5, colour = INK),
  axis.text = element_text(colour = INK2), axis.title = element_text(colour = INK2, size = 9),
  legend.position = "top", legend.text = element_text(colour = INK2, size = 8.5),
  legend.key.height = unit(9, "pt"))

fig <- (pA + common) + (pB + common) + (pC + common) +
  plot_layout(widths = c(1, 1.15, 0.85)) +
  plot_annotation(
    title = "A centimeter of pain is not a centimeter of pain",
    subtitle = "On this trial's VAS, a 1 cm step near the middle of the scale spans about half the latent pain of a 1 cm step near either end.\nLatent pain is estimated from a multi item pain instrument, never from the VAS. Curves normalized so an equal interval scale reads 1.\nThree independent item blocks agree, including the Geriatric Pain Measure, a separate instrument from the WOMAC.",
    caption = "Data: intra-articular ozone vs placebo for knee osteoarthritis (PLOS ONE pone.0179185), 98 patients at baseline, 4, 8 and 16 weeks. VAS recorded as integer centimeters, so it behaves as an 11 point scale.\nPanel B band is a 100 replicate patient level bootstrap of the WOMAC pain block, 10th to 90th percentile. Shaded VAS 0 and 9 are floor and ceiling: 27 percent of observations sit at 0.\nPanel C bins every observed drop by its starting VAS. Observed and predicted agree at mid and high start, and diverge at the floor, which is why the endpoints in panel B are faded.",
    theme = theme(plot.background = element_rect(fill = SURF, colour = NA),
      plot.title = element_text(face = "bold", size = 16, colour = INK),
      plot.subtitle = element_text(size = 10, colour = INK2, lineheight = 1.25),
      plot.caption = element_text(size = 7.4, colour = INK2, hjust = 0, lineheight = 1.25)))

ggsave("out/figures/fig4_interval_curve.png", fig, width = 14, height = 6.6, dpi = 200, bg = SURF)
message("ozone figure written")
