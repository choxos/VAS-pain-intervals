# The corrected headline figure.
#  A  validation: the estimator recovers a known nonlinearity in simulated data
#  B  the ozone trial curve drawn over the curve a perfectly interval VAS
#     produces through the same pipeline when, as here, 27 percent of answers
#     are zero. Most of the apparent U shape is already in the null.
suppressMessages({library(ggplot2); library(dplyr); library(patchwork)})

SURF <- "#fcfcfb"; INK <- "#0b0b0b"; INK2 <- "#52514e"; GRID <- "#e6e5e1"
S1 <- "#2a78d6"; S2 <- "#eb6834"

sim <- readRDS("out/sim_validation.rds")
rob <- readRDS("out/robustness.rds")
an  <- readRDS("out/anchored.rds")
obs  <- rob$cv_obs
nb   <- an$null2_band

common <- theme_minimal(base_size = 11.5) + theme(
  plot.background = element_rect(fill = SURF, colour = NA),
  panel.background = element_rect(fill = SURF, colour = NA),
  panel.grid.minor = element_blank(),
  panel.grid.major = element_line(colour = GRID, linewidth = 0.3),
  plot.subtitle = element_text(face = "bold", size = 11, colour = INK),
  axis.text = element_text(colour = INK2), axis.title = element_text(colour = INK2, size = 9.5),
  legend.position = "top", legend.text = element_text(colour = INK2, size = 9))

pA <- ggplot() +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = 9.5, ymax = 10.5, fill = "#ecebe7") +
  geom_hline(yintercept = 10, linetype = "dashed", colour = INK2, linewidth = 0.4) +
  geom_line(data = sim$thin, aes(vas, D, group = interaction(cohort, model)),
            colour = "#b9c6d6", linewidth = 0.3) +
  geom_line(data = sim$truth, aes(vas, D), colour = INK, linewidth = 1.4, linetype = "21") +
  geom_line(data = sim$med, aes(vas, D, colour = model), linewidth = 1.2) +
  scale_colour_manual(values = c(graded = S2, rasch = S1), limits = c("graded", "rasch"),
                      labels = c("Graded model", "Rasch model"), name = NULL) +
  annotate("text", x = 74, y = 15.6, label = "True curve", hjust = 0, size = 3.3,
           colour = INK, fontface = "bold") +
  scale_x_continuous(limits = c(5, 95), breaks = seq(10, 80, 20)) +
  coord_cartesian(ylim = c(0, 18)) +
  labs(subtitle = "A.  The estimator finds a real bend when one exists",
       x = "Displayed VAS score (simulated, 0 to 100)",
       y = "Latent pain per displayed interval") + common

pB <- ggplot() +
  geom_ribbon(data = nb, aes(vas, ymin = lo025, ymax = hi975), fill = "#b9c6d6", alpha = 0.55) +
  geom_line(data = nb, aes(vas, med), colour = "#6f7f93", linewidth = 1.1, linetype = "22") +
  geom_hline(yintercept = 1, linetype = "dashed", colour = INK2, linewidth = 0.4) +
  geom_line(data = obs, aes(vas, D), colour = S2, linewidth = 1.4) +
  geom_point(data = obs, aes(vas, D), colour = S2, size = 2) +
  annotate("text", x = 2.6, y = 2.05, label = "Observed, ozone trial", hjust = 0,
           size = 3.4, colour = S2, fontface = "bold") +
  annotate("text", x = 3.1, y = 0.26, hjust = 0, size = 3.2, colour = "#4f5d6e",
           label = "A perfectly interval VAS with the same\n27% floor, same pipeline (95% band)") +
  scale_x_continuous(breaks = 0:9) +
  coord_cartesian(ylim = c(0, 2.5)) +
  labs(subtitle = "B.  Most of the U is what an interval scale produces here",
       x = "Displayed VAS score (cm)", y = "Latent pain spanned by a 1 cm step") + common

fig <- (pA + pB) + plot_layout(widths = c(1, 1.1)) +
  plot_annotation(
    title = "The curve an interval scale produces when 27% of answers are zero",
    subtitle = "The exploratory estimator regresses a latent pain score on the displayed VAS. On this trial it drew a convincing U shape.\nA null simulation with a VAS that is exactly linear in latent pain, given the trial's real floor, reproduces most of that U.\nA marginal likelihood model that treats the VAS as an item shows no U at all. The headline was mostly an artifact.",
    caption = "Data: intra-articular ozone vs placebo for knee osteoarthritis (PLOS ONE pone.0179185), 98 patients, 386 observations, VAS recorded as integer centimeters.\nNull: 200 patient level resamples with the real latent distribution, the fitted WOMAC pain item parameters, and a strictly linear VAS tuned to the real floor, mean and spread.\nThe observed curve leaves the null band only at 1, 2, 5 and 6 cm, and the marginal likelihood model does not reproduce that residual.",
    theme = theme(plot.background = element_rect(fill = SURF, colour = NA),
      plot.title = element_text(face = "bold", size = 16, colour = INK),
      plot.subtitle = element_text(size = 10.2, colour = INK2, lineheight = 1.25),
      plot.caption = element_text(size = 7.8, colour = INK2, hjust = 0, lineheight = 1.25)))

ggsave("out/figures/fig4_interval_curve.png", fig, width = 13, height = 6.6, dpi = 200, bg = SURF)
message("corrected figure written")
