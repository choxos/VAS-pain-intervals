# Extra stratum: journals with a mandatory data availability policy, where
# "the data are in S1" reliably means individual level data.
suppressMessages({library(europepmc); library(dplyr)})

vas   <- '(ABSTRACT:"visual analogue scale" OR ABSTRACT:"visual analog scale" OR ABSTRACT:"VAS")'
instr <- paste0("(", paste(sprintf('ABSTRACT:"%s"',
  c("Brief Pain Inventory","McGill Pain Questionnaire","WOMAC","KOOS","PROMIS",
    "SF-MPQ","numeric rating scale","numerical rating scale","pain intensity")),
  collapse = " OR "), ")")

journals <- c("PLoS one", "Scientific reports", "BMJ open", "PeerJ",
              "Frontiers in pain research", "Journal of pain research")
jclause <- paste0("(", paste(sprintf('JOURNAL:"%s"', journals), collapse = " OR "), ")")

q <- paste(vas, 'AND ABSTRACT:"pain" AND', instr, 'AND', jclause,
           'AND OPEN_ACCESS:y AND IN_EPMC:y AND HAS_SUPPL:y AND PUB_YEAR:[2012 TO 2026]')

n <- epmc_hits(q); message("plos-like stratum: ", n, " hits")
res <- epmc_search(q, limit = min(n, 3000), synonym = FALSE, verbose = FALSE)
res$stratum <- "journal_policy"

old <- readRDS("data/records.rds")
extra <- res |> filter(!is.na(pmcid), pmcid != "", !pmcid %in% old$pmcid) |>
  distinct(pmcid, .keep_all = TRUE)
message("new records not already queued: ", nrow(extra))
saveRDS(extra, "data/records_extra.rds")
