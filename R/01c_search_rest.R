# The broad stratum was truncated at 3000 of 4578 by relevance rank, which is
# arbitrary for this purpose. Pull the remainder so coverage does not depend on
# Europe PMC's ordering.
suppressMessages({library(europepmc); library(dplyr)})

vas   <- '(ABSTRACT:"visual analogue scale" OR ABSTRACT:"visual analog scale" OR ABSTRACT:"VAS")'
instr <- paste0("(", paste(sprintf('ABSTRACT:"%s"',
  c("Brief Pain Inventory","McGill Pain Questionnaire","WOMAC","KOOS","PROMIS",
    "SF-MPQ","numeric rating scale","numerical rating scale","pain intensity")),
  collapse = " OR "), ")")
q <- paste(vas, 'AND (ABSTRACT:"pain") AND', instr,
           'AND OPEN_ACCESS:y AND IN_EPMC:y AND PUB_YEAR:[2012 TO 2026]')

n <- epmc_hits(q); message("broad stratum total: ", n)
res <- epmc_search(q, limit = n, synonym = FALSE, verbose = FALSE)
res$stratum <- "broad_rest"

old <- readRDS("data/records.rds")
extra <- res |> filter(!is.na(pmcid), pmcid != "", !pmcid %in% old$pmcid) |>
  distinct(pmcid, .keep_all = TRUE)
message("new records: ", nrow(extra))
saveRDS(extra, "data/records_extra.rds")
