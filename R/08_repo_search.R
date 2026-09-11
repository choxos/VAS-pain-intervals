# Search data repositories directly, rather than reaching them through papers.
# Going paper first found 4567 articles but almost no item level responses,
# because what gets deposited alongside a paper is nearly always subscale and
# instrument totals. Querying Zenodo, Dryad and OSF by instrument name targets
# the datasets themselves.
suppressMessages({library(jsonlite); library(dplyr); library(stringr); library(purrr)})

dir.create("data/reposearch", showWarnings = FALSE, recursive = TRUE)
`%||%` <- function(a, b) if (is.null(a)) b else a

QUERIES <- c("WOMAC pain", "Brief Pain Inventory", "McGill Pain Questionnaire",
             "KOOS knee", "PROMIS pain intensity", "visual analogue scale pain",
             "pain intensity item responses")

api <- function(url) tryCatch(fromJSON(url, simplifyVector = FALSE),
                              error = function(e) NULL)

zenodo <- function(q) {
  u <- sprintf("https://zenodo.org/api/records?q=%s&type=dataset&size=50",
               URLencode(q, reserved = TRUE))
  j <- api(u); if (is.null(j$hits$hits)) return(NULL)
  map_dfr(j$hits$hits, function(h) tibble(
    repo = "zenodo", query = q,
    title = h$metadata$title %||% NA_character_,
    id = as.character(h$id %||% NA),
    url = h$links$self %||% NA_character_))
}

dryad <- function(q) {
  u <- sprintf("https://datadryad.org/api/v2/search?q=%s&per_page=50",
               URLencode(q, reserved = TRUE))
  j <- api(u); e <- j$`_embedded`$`stash:datasets`
  if (is.null(e)) return(NULL)
  map_dfr(e, function(h) tibble(
    repo = "dryad", query = q,
    title = h$title %||% NA_character_,
    id = h$identifier %||% NA_character_,
    url = paste0("https://datadryad.org",
                 h$`_links`$`stash:version`$href %||% "")))
}

osf <- function(q) {
  u <- sprintf("https://api.osf.io/v2/nodes/?filter[title]=%s&page[size]=50",
               URLencode(q, reserved = TRUE))
  j <- api(u); if (is.null(j$data)) return(NULL)
  map_dfr(j$data, function(h) tibble(
    repo = "osf", query = q,
    title = h$attributes$title %||% NA_character_,
    id = h$id %||% NA_character_,
    url = sprintf("https://api.osf.io/v2/nodes/%s/files/osfstorage/", h$id %||% "")))
}

hits <- bind_rows(lapply(QUERIES, function(q) {
  message("query: ", q)
  r <- bind_rows(zenodo(q), dryad(q), osf(q))
  Sys.sleep(0.6)
  r
}))

hits <- hits |> filter(!is.na(title)) |> distinct(repo, id, .keep_all = TRUE)
message("repository records found: ", nrow(hits))

# Keep records whose title suggests human pain measurement, not bench work.
keep <- hits |>
  filter(str_detect(tolower(title),
    "pain|womac|koos|bpi|mpq|mcgill|promis|osteoarthritis|analgesi|arthritis|back")) |>
  filter(!str_detect(tolower(title),
    "mouse|mice|rat |rodent|zebrafish|in vitro|cell line|genom|transcriptom"))
message("plausible human pain datasets: ", nrow(keep))

saveRDS(keep, "data/reposearch/hits.rds")
write.csv(keep, "out/repo_search_hits.csv", row.names = FALSE)
