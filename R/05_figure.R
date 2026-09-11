# PISA style figure: latent pain spanned by a fixed displayed VAS interval.
suppressMessages({library(ggplot2); library(dplyr); library(tidyr)})

# curves: data frame with columns vas, D, dataset, model, in_core
# dens:   data frame with columns vas, dens, panel
make_figure <- function(curves, dens = NULL, width = 10,
                        title = "Is 10 points of pain always 10 points?",
                        subtitle = NULL, panel_var = "panel") {

  med <- curves |>
    group_by(.data[[panel_var]], model, vas) |>
    summarise(D = median(D), .groups = "drop")

  ymax <- quantile(curves$D, 0.995, na.rm = TRUE) * 1.05

  p <- ggplot() +
    annotate("rect", xmin = -Inf, xmax = Inf,
             ymin = width * 0.95, ymax = width * 1.05,
             fill = "grey85", alpha = 0.6) +
    geom_hline(yintercept = width, linetype = "dashed", colour = "grey30") +
    geom_line(data = curves,
              aes(vas, D, group = interaction(dataset, model)),
              colour = "grey65", linewidth = 0.3, alpha = 0.7) +
    geom_line(data = med, aes(vas, D, colour = model), linewidth = 1.4) +
    scale_colour_manual(values = c(graded = "#9B1B1B", rasch = "#2C3E50"),
                        labels = c(graded = "Graded (2PL-like)", rasch = "Rasch"),
                        name = NULL) +
    facet_wrap(as.formula(paste("~", panel_var)), nrow = 1) +
    coord_cartesian(ylim = c(0, ymax)) +
    labs(title = title, subtitle = subtitle,
         x = "Displayed VAS pain score (0-100)",
         y = sprintf("Latent pain spanned by\n%d displayed VAS points", width)) +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank(),
          legend.position = "top",
          plot.title = element_text(face = "bold"),
          strip.text = element_text(face = "bold", colour = "#2C3E50"))

  if (!is.null(dens)) {
    dens <- dens |> group_by(.data[[panel_var]]) |>
      mutate(y = dens / max(dens) * ymax * 0.3) |> ungroup()
    p <- p + geom_area(data = dens, aes(vas, y),
                       fill = "#D6DEE8", alpha = 0.8, colour = NA)
  }
  p
}

annotate_note <- function(p, note) {
  p + labs(caption = note) +
    theme(plot.caption = element_text(hjust = 0, colour = "grey35", size = 9))
}
