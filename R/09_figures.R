# Figures. Palette and checks follow the data visualization reference palette:
# categorical slots 1 to 4 (blue, orange, aqua, violet), ordinal blue ramp for
# the funnel. Every bar carries a visible value label, which is the required
# relief for the aqua slot sitting below 3:1 against the light surface.
suppressMessages({library(ggplot2); library(dplyr); library(tidyr); library(stringr)})

SURF <- "#fcfcfb"; INK <- "#0b0b0b"; INK2 <- "#52514e"; GRID <- "#e6e5e1"
S1 <- "#2a78d6"; S2 <- "#eb6834"; S3 <- "#1baf7a"; S4 <- "#4a3aa7"
RAMP <- c("#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#104281")

base_theme <- theme_minimal(base_size = 12) +
  theme(
    plot.background  = element_rect(fill = SURF, colour = NA),
    panel.background = element_rect(fill = SURF, colour = NA),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = GRID, linewidth = 0.3),
    plot.title    = element_text(face = "bold", size = 15, colour = INK),
    plot.subtitle = element_text(size = 10.5, colour = INK2, lineheight = 1.2),
    plot.caption  = element_text(size = 8.5, colour = INK2, hjust = 0),
    axis.text     = element_text(colour = INK2),
    axis.title    = element_text(colour = INK2, size = 10),
    strip.text    = element_text(face = "bold", colour = INK),
    legend.position = "top", legend.title = element_blank(),
    legend.text = element_text(colour = INK2),
    plot.title.position = "plot", plot.caption.position = "plot")

dir.create("out/figures", showWarnings = FALSE, recursive = TRUE)
fd <- readRDS("data/figdata.rds")
scr <- readRDS("data/screen.rds")

# ---------------------------------------------------------------- Figure 1 ---
# The funnel. This is the headline: the corpus is large and the usable end is
# almost empty.
fun <- tibble(
  stage = factor(c("Open access papers\nscreened",
                   "Data availability statement\ndetected",
                   "Readable tabular\ndata files",
                   "Files with a plausible\npain data shape",
                   "Item level pain\ninstrument"),
                 levels = rev(c("Open access papers\nscreened",
                                "Data availability statement\ndetected",
                                "Readable tabular\ndata files",
                                "Files with a plausible\npain data shape",
                                "Item level pain\ninstrument"))),
  n = c(4567, 493, 77, 60, 2))
fun$lab <- format(fun$n, big.mark = ",", trim = TRUE)
pc <- 100 * fun$n / 4567
fun$pct <- ifelse(pc >= 10, sprintf("%.0f%%", pc),
           ifelse(pc >= 1,  sprintf("%.1f%%", pc), sprintf("%.2f%%", pc)))

p1 <- ggplot(fun, aes(n, stage)) +
  geom_col(aes(fill = stage), width = 0.62) +
  geom_text(aes(label = paste0(lab, "  (", pct, ")")), hjust = -0.08,
            size = 3.8, colour = INK, fontface = "bold") +
  scale_fill_manual(values = setNames(rev(RAMP), levels(fun$stage)), guide = "none") +
  scale_x_continuous(trans = "log10", limits = c(1, 300000),
                     breaks = c(1, 10, 100, 1000, 10000),
                     labels = c("1", "10", "100", "1,000", "10,000"),
                     expand = c(0, 0)) +
  labs(title = "Pain data is shared. Item level pain data is not.",
       subtitle = "Europe PMC open access papers using a visual analogue scale for pain alongside a named\nmulti item pain instrument. Availability statements detected with rtransparency. Log scale.",
       x = "Number of records (log scale)", y = NULL,
       caption = "Two of 4,567 papers shared the item level responses an item response model needs.\nEverything else shared subscale or instrument totals, which cannot be modeled.\nOnly 39 of the 493 availability statements named a repository or accession; 324 said the data are in the article.") +
  base_theme + theme(panel.grid.major.y = element_blank())
ggsave("out/figures/fig1_funnel.png", p1, width = 9.5, height = 5.4, dpi = 200, bg = SURF)

# ---------------------------------------------------------------- Figure 2 ---
# Data sharing over time. Well powered and worth reporting in its own right.
yr <- fd$yr
p2 <- ggplot(yr, aes(y, pct)) +
  geom_col(fill = S1, width = 0.68) +
  geom_text(aes(label = sprintf("%.0f%%", pct)), vjust = -0.7,
            size = 3.1, colour = INK2) +
  scale_x_continuous(breaks = seq(2012, 2026, 2)) +
  scale_y_continuous(limits = c(0, 20), expand = expansion(mult = c(0, 0.05)),
                     labels = function(x) paste0(x, "%")) +
  labs(title = "Detected data availability statements rose from nothing to one paper in six",
       subtitle = "Share of open access pain papers carrying a detected data availability statement or repository deposit,\nby publication year. 4,567 papers, detection by rtransparency. Most statements point at the article itself,\nnot at a repository: only 39 of 493 named a repository or accession.",
       x = NULL, y = "Papers sharing data",
       caption = "2026 is a partial year. Detection identifies that a statement exists, not that usable data are behind it.") +
  base_theme
ggsave("out/figures/fig2_sharing_trend.png", p2, width = 9.5, height = 5, dpi = 200, bg = SURF)

# ---------------------------------------------------------------- Figure 3 ---
# What the shortlisted files actually contain.
cols <- tolower(scr$review$cols)
cls <- case_when(
  str_detect(cols, "wom[a-z ._-]*a[ ._-]?[1-5]\\b") |
    str_detect(cols, "pain.?when.?walk|pain.?climb|pain.?sleeping") ~ "Item level pain instrument",
  str_detect(cols, "womac|koos|mpq|mcgill|bpi|promis|sf-?mpq|oswestry|odi|rmdq") ~ "Instrument or subscale totals",
  str_detect(cols, "vas|nrs|pain") ~ "A pain rating, no instrument",
  TRUE ~ "No pain measure in the table")
cl <- as_tibble(table(cls)) |> rename(class = cls, n = n) |>
  mutate(class = factor(class, levels = c(
    "Item level pain instrument", "Instrument or subscale totals",
    "A pain rating, no instrument", "No pain measure in the table"))) |>
  arrange(class)

p3 <- ggplot(cl, aes(n, forcats::fct_rev(class), fill = class)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = n), hjust = -0.35, size = 4, colour = INK, fontface = "bold") +
  scale_fill_manual(values = c(
    "Item level pain instrument"    = S2,
    "Instrument or subscale totals" = S1,
    "A pain rating, no instrument"  = S3,
    "No pain measure in the table"  = S4), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.14))) +
  labs(title = "What shared pain datasets actually contain",
       subtitle = "The 60 shortlisted tables, classified by the finest grain of pain measurement present.\nOnly the top category can support an item response model.",
       x = "Tables", y = NULL,
       caption = "Shortlist drawn from 102 tabular files retrieved from supplements and repositories, 77 of them readable.") +
  base_theme + theme(panel.grid.major.y = element_blank())
ggsave("out/figures/fig3_granularity.png", p3, width = 9.5, height = 4.4, dpi = 200, bg = SURF)

message("figures 1 to 3 written")
