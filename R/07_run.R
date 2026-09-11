# Curated analysis. Every dataset here was inspected by hand: the automatic
# proposer in 06 ranks candidates, it does not decide which are admissible.
#
# Admission rules applied by hand:
#   1. The item block must measure pain intensity or severity, not disability,
#      mood or comorbidity. Most shortlisted tables failed here: their small
#      integer columns were sex, ASA grade and comorbidity flags.
#   2. The items must not themselves be visual analogue scales. Testing a VAS
#      against a metric built out of other VAS responses cannot detect a
#      nonlinearity the two displays share, so it is biased toward finding no
#      effect.
#   3. Items must be item level responses, not subscale or instrument totals.
suppressMessages({library(dplyr); library(ggplot2); library(readxl)})
source("R/06_extract.R")
source("R/05_figure.R")

screen <- readRDS("data/screen.rds")
pick <- function(pmcid) unique(screen$scored$file[screen$scored$pmcid == pmcid])[1]

curves <- list(); notes <- list()

# ---------------------------------------------------------------------------
# PMC10695107. Knee osteoarthritis, WOMAC pain subscale as five 0 to 4 Likert
# items, global VAS separately. Measured at baseline and at six weeks, so the
# two occasions are stacked to cover the VAS range: baseline spans 60 to 90 and
# six weeks spans 1 to 55, and neither alone covers enough of the scale.
# Clustered by participant, so the bootstrap resamples participants.
# ---------------------------------------------------------------------------
f <- pick("PMC10695107")
d <- load_table(f, "1")

base_items <- c("Painwhenwalking", "Painclimbingstairs", "Painsleepingatnight",
                "Painwhenresting", "Painwhenstanding")
wk6_items  <- c("Painwhenwalking1", "Painwhenclimbingstairs1", "Painatnight1",
                "Painwhenresting1", "Painwhenstanding1")

stack_occasions <- function(d, vas_cols, item_sets, occ_names) {
  out <- lapply(seq_along(vas_cols), function(k) {
    v <- as.numeric(d[[vas_cols[k]]])
    it <- as.data.frame(lapply(d[item_sets[[k]]], as.numeric))
    names(it) <- paste0("item", seq_along(item_sets[[k]]))
    cbind(id = seq_len(nrow(d)), occasion = occ_names[k], vas = v, it)
  })
  bind_rows(out)
}

st <- stack_occasions(d, c("VASbaseline", "VASat6thweek"),
                      list(base_items, wk6_items), c("baseline", "week6"))
st <- st[is.finite(st$vas) & rowSums(!is.na(st[, grep("^item", names(st))])) >= 3, ]

ds <- list(vas = st$vas, items = st[, grep("^item", names(st))],
           rating_name = "VAS 0-100", item_names = base_items,
           n = nrow(st), scale_max = max(st$vas), longitudinal = FALSE)

cv <- analyze(ds, label = "PMC10695107 knee OA (WOMAC pain, 2 occasions)",
              panel = "Knee osteoarthritis", width = 10)
if (!is.null(cv)) {
  cv$id <- NA
  curves[["PMC10695107"]] <- cv
  notes[["PMC10695107"]] <- sprintf(
    "n=%d observations from %d participants, r(theta,VAS)=%.2f, VAS range %g to %g",
    nrow(st), length(unique(st$id)), cv$r[1], min(st$vas), max(st$vas))
}

# ---------------------------------------------------------------------------
# Cluster bootstrap over participants for the band.
# ---------------------------------------------------------------------------
cluster_boot <- function(st, width = 10, B = 150, model = "graded") {
  ids <- unique(st$id)
  icols <- grep("^item", names(st))
  reps <- lapply(seq_len(B), function(b) {
    take <- sample(ids, length(ids), replace = TRUE)
    rows <- unlist(lapply(take, function(i) which(st$id == i)))
    sub <- st[rows, ]
    th <- try(fit_theta(sub[, icols], model), silent = TRUE)
    if (inherits(th, "try-error")) return(NULL)
    r <- suppressWarnings(cor(th, sub$vas, use = "complete.obs"))
    if (!is.finite(r)) return(NULL)
    if (r < 0) th <- -th
    cvb <- try(interval_curve(sub$vas, th, width = width), silent = TRUE)
    if (inherits(cvb, "try-error")) return(NULL)
    cvb$rep <- b
    cvb
  })
  bind_rows(reps)
}

set.seed(20260910)
bb <- cluster_boot(st, width = 10, B = 150)
band <- bb |> group_by(vas) |>
  summarise(lo = quantile(D, 0.1, na.rm = TRUE),
            hi = quantile(D, 0.9, na.rm = TRUE), .groups = "drop")

all_curves <- bind_rows(curves)
saveRDS(list(curves = all_curves, band = band, notes = notes, stacked = st),
        "out/results.rds")

for (n in names(notes)) message(n, ": ", notes[[n]])
message("datasets on the figure: ", length(curves))
