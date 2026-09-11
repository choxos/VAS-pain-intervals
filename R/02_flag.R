# Download PMC full text XML and flag data sharing with rtransparency.
suppressMessages({library(europepmc); library(rtransparency); library(dplyr)
                  library(future); library(furrr)})
plan(multisession, workers = 4)

args <- commandArgs(trailingOnly = TRUE)
n_max <- if (length(args)) as.integer(args[1]) else Inf

recs <- readRDS("data/records.rds")
# Highest yield strata first.
recs <- recs |> arrange(match(stratum, c("shared", "suppl", "broad")))
if (is.finite(n_max)) recs <- head(recs, n_max)

dir.create("data/xml", showWarnings = FALSE, recursive = TRUE)

get_xml <- function(pmcid) {
  f <- file.path("data/xml", paste0(pmcid, ".xml"))
  if (file.exists(f) && file.size(f) > 1000) return(f)
  ok <- tryCatch({
    doc <- europepmc::epmc_ftxt(pmcid)
    xml2::write_xml(doc, f)
    TRUE
  }, error = function(e) FALSE)
  Sys.sleep(0.5)
  if (ok) f else NA_character_
}

flag_one <- function(pmcid) {
  f <- get_xml(pmcid)
  if (is.na(f)) return(NULL)
  tryCatch({
    r <- rt_data_code_pmc(f, remove_ns = TRUE)
    r$pmcid_q <- pmcid
    r
  }, error = function(e) NULL)
}

# Chunked so a killed run resumes from the last saved chunk.
dir.create("data/chunks", showWarnings = FALSE, recursive = TRUE)
chunks <- split(recs$pmcid, ceiling(seq_len(nrow(recs)) / 100))
for (k in names(chunks)) {
  cf <- file.path("data/chunks", paste0("flags_", k, ".rds"))
  if (file.exists(cf)) next
  res <- future_map(chunks[[k]], flag_one, .options = furrr_options(seed = TRUE))
  saveRDS(bind_rows(res), cf)
  message("chunk ", k, "/", length(chunks), " saved")
}

flags <- bind_rows(lapply(list.files("data/chunks", full.names = TRUE), readRDS))
message("processed: ", nrow(flags), "  open data: ", sum(flags$is_open_data, na.rm = TRUE))
saveRDS(flags, "data/flags.rds")
