# Search Europe PMC for open-access papers likely to hold individual-level VAS
# pain scores alongside a multi-item pain intensity instrument.
suppressMessages({library(europepmc); library(dplyr)})

dir.create("data", showWarnings = FALSE)

# Multi-item pain intensity instruments that can carry an IRT model.
# Deliberately excludes disability and catastrophizing scales.
instruments <- c(
  "Brief Pain Inventory", "BPI",
  "McGill Pain Questionnaire", "SF-MPQ",
  "WOMAC", "KOOS", "HOOS",
  "PROMIS pain", "Pain Intensity Short Form",
  "Roland Morris", "Oswestry",              # kept for co-occurrence screening only
  "Numeric Rating Scale", "Numerical Rating Scale"
)

vas_clause <- '(ABSTRACT:"visual analogue scale" OR ABSTRACT:"visual analog scale" OR ABSTRACT:"VAS")'
pain_clause <- '(ABSTRACT:"pain")'
instr_clause <- paste0(
  "(",
  paste(sprintf('ABSTRACT:"%s"', c("Brief Pain Inventory", "McGill Pain Questionnaire",
                                   "WOMAC", "KOOS", "PROMIS", "SF-MPQ",
                                   "numeric rating scale", "numerical rating scale",
                                   "pain intensity")), collapse = " OR "),
  ")"
)

strata <- list(
  broad = paste(vas_clause, "AND", pain_clause, "AND", instr_clause,
                'AND OPEN_ACCESS:y AND IN_EPMC:y AND PUB_YEAR:[2012 TO 2026]'),
  suppl = paste(vas_clause, "AND", pain_clause, "AND", instr_clause,
                'AND OPEN_ACCESS:y AND IN_EPMC:y AND HAS_SUPPL:y AND PUB_YEAR:[2012 TO 2026]'),
  # Body-text stratum: papers that say "data availability" style things anywhere.
  shared = paste(vas_clause, "AND", pain_clause, "AND", instr_clause,
                 'AND OPEN_ACCESS:y AND IN_EPMC:y',
                 'AND (BODY:"data availability" OR BODY:"supplementary data"',
                 'OR BODY:"figshare" OR BODY:"osf.io" OR BODY:"zenodo"',
                 'OR BODY:"dryad" OR BODY:"mendeley data")',
                 'AND PUB_YEAR:[2012 TO 2026]')
)

hits <- lapply(names(strata), function(nm) {
  q <- strata[[nm]]
  n <- epmc_hits(q)
  message(nm, ": ", n, " hits")
  res <- epmc_search(q, limit = min(n, 3000), synonym = FALSE, verbose = FALSE)
  res$stratum <- nm
  res
})

recs <- bind_rows(hits) |>
  filter(!is.na(pmcid), pmcid != "") |>
  distinct(pmcid, .keep_all = TRUE)

message("unique PMC records: ", nrow(recs))
saveRDS(recs, "data/records.rds")
