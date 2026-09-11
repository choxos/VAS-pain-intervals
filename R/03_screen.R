# Screen flagged papers for a downloadable individual level dataset that holds
# a displayed pain rating plus several item level pain columns.
#
# Deliberately does not hard filter on column name regexes. Real files name the
# rating "PI", "pain0" or "NRS" as often as "VAS", so this emits a ranked review
# list scored on the shape of the data: a 0 to 100 column plus a block of small
# integer columns is what an item level pain dataset looks like.
suppressMessages({
  library(dplyr); library(purrr); library(stringr); library(xml2)
  library(readr); library(readxl); library(haven); library(tidyr)
  library(future); library(furrr)
})
plan(multisession, workers = 3)

flags <- bind_rows(lapply(
  Filter(function(f) file.exists(f) && file.size(f) > 5000,
         c("data/flags.rds", "data/flags_extra.rds")),
  readRDS))

dir.create("data/supp", showWarnings = FALSE, recursive = TRUE)
dir.create("out", showWarnings = FALSE)

REPO_RX <- "osf\\.io|figshare|zenodo|datadryad|dryad|data\\.mendeley|dataverse|openneuro|10\\.5281/|10\\.6084/|10\\.17605/|10\\.5061/"

# --- repository links, from every cached XML, not only flagged rows -----------
xml_links <- function(pmcid) {
  f <- file.path("data/xml", paste0(pmcid, ".xml"))
  if (!file.exists(f)) return(character())
  doc <- tryCatch(read_xml(f), error = function(e) NULL)
  if (is.null(doc)) return(character())
  xml_ns_strip(doc)
  el <- xml_find_all(doc, "//ext-link")
  l <- unique(c(xml_attr(el, "href"), xml_text(el)))
  l <- l[!is.na(l) & nzchar(l)]
  unique(grep(REPO_RX, l, value = TRUE, ignore.case = TRUE))
}

# --- supplementary bundle ------------------------------------------------------
DATA_EXT <- "\\.(csv|tsv|txt|xlsx?|sav|dta|por|rds|rda|json)$"

fetch_supp <- function(pmcid) {
  zf <- file.path("data/supp", paste0(pmcid, ".zip"))
  dd <- file.path("data/supp", pmcid)
  if (!file.exists(zf)) {
    url <- sprintf("https://www.ebi.ac.uk/europepmc/webservices/rest/%s/supplementaryFiles", pmcid)
    ok <- tryCatch({download.file(url, zf, quiet = TRUE, mode = "wb"); TRUE},
                   error = function(e) FALSE)
    Sys.sleep(0.4)
    if (!ok || !file.exists(zf) || file.size(zf) < 200) return(character())
  }
  inside <- tryCatch(unzip(zf, list = TRUE)$Name, error = function(e) character())
  keep <- grep(DATA_EXT, inside, ignore.case = TRUE, value = TRUE)
  if (!length(keep)) return(character())
  tryCatch(unzip(zf, files = keep, exdir = dd, overwrite = FALSE),
           error = function(e) character())
  file.path(dd, keep)[file.exists(file.path(dd, keep))]
}

# --- read every table in a file, including every Excel sheet -------------------
read_tables <- function(path) {
  ext <- tolower(tools::file_ext(path))
  g <- function(x) tryCatch(x, error = function(e) NULL)
  if (ext %in% c("xls", "xlsx")) {
    sh <- tryCatch(excel_sheets(path), error = function(e) character())
    out <- lapply(sh, function(s)
      tryCatch(read_excel(path, sheet = s, n_max = 500, .name_repair = "minimal"),
               error = function(e) NULL))
    names(out) <- sh
    return(out[!vapply(out, is.null, logical(1))])
  }
  d <- switch(ext,
    csv = g(read_csv(path, n_max = 500, show_col_types = FALSE, name_repair = "minimal")),
    tsv = g(read_tsv(path, n_max = 500, show_col_types = FALSE, name_repair = "minimal")),
    txt = g(read_delim(path, n_max = 500, show_col_types = FALSE, name_repair = "minimal")),
    sav = g(read_sav(path, n_max = 500)),
    dta = g(read_dta(path, n_max = 500)),
    NULL)
  if (is.null(d)) list() else setNames(list(d), "1")
}

# Shape based scoring. An item level pain dataset has a wide rating column
# (0 to 100 or 0 to 10) and a block of narrow integer columns.
score_table <- function(d) {
  num <- d[, vapply(d, function(x) is.numeric(x) || inherits(x, "haven_labelled"),
                    logical(1)), drop = FALSE]
  if (!ncol(num)) return(NULL)
  num[] <- lapply(num, as.numeric)
  rng <- vapply(num, function(x) {
    x <- x[is.finite(x)]
    if (!length(x)) return(c(NA, NA, NA))
    c(min(x), max(x), length(unique(x)))
  }, numeric(3))
  lo <- rng[1, ]; hi <- rng[2, ]; nu <- rng[3, ]
  is_int <- vapply(num, function(x) {x <- x[is.finite(x)]; length(x) > 0 && all(x == round(x))}, logical(1))
  tibble(
    ncol = ncol(d), nrow_head = nrow(d), n_numeric = ncol(num),
    # a displayed pain rating: spans much of 0 to 100, many distinct values
    n_cols_0to100 = sum(lo >= 0 & hi > 20 & hi <= 100 & nu >= 8, na.rm = TRUE),
    n_cols_0to10  = sum(lo >= 0 & hi >= 4 & hi <= 11 & nu >= 4, na.rm = TRUE),
    # item like: small integer range, few categories
    n_item_like   = sum(is_int & lo >= 0 & hi <= 10 & nu >= 2 & nu <= 11, na.rm = TRUE),
    cols = paste(head(tolower(trimws(names(d))), 60), collapse = " | ")
  )
}

NAME_RX <- "vas|visual[ _.-]*analog|bpi|womac|koos|hoos|mpq|mcgill|promis|nrs|nprs|pain|^q[0-9]|item"

# ------------------------------------------------------------------------------
cand <- flags |>
  transmute(pmcid = pmcid_q, is_open_data, open_data_statements, open_data_links)

message("papers processed: ", nrow(cand),
        "   flagged open data: ", sum(cand$is_open_data, na.rm = TRUE))

# Repository links from all cached XML, regardless of detector verdict.
cand$repo_links <- future_map_chr(cand$pmcid, function(p) {
  l <- c(xml_links(p), strsplit(cand$open_data_links[cand$pmcid == p][1], " ; ")[[1]])
  paste(unique(l[!is.na(l) & nzchar(l) &
                 grepl(REPO_RX, l, ignore.case = TRUE)]), collapse = " ; ")
}, .options = furrr_options(seed = TRUE))
message("papers with repository links: ", sum(nzchar(cand$repo_links)))

# Supplementary bundles: only worth pulling for flagged papers or ones with suppl.
pull <- cand$pmcid[cand$is_open_data %in% TRUE | nzchar(cand$repo_links)]
message("pulling supplementary bundles for ", length(pull), " papers")
supp <- future_map(pull, fetch_supp, .progress = TRUE,
                   .options = furrr_options(seed = TRUE))
names(supp) <- pull
files <- tibble(pmcid = rep(names(supp), lengths(supp)), file = unlist(supp))

# Repository files, if 03b has run.
rf <- if (file.exists("data/repo_files.rds")) readRDS("data/repo_files.rds") else NULL
if (!is.null(rf) && nrow(rf) && all(c("pmcid", "file") %in% names(rf))) {
  files <- bind_rows(files, rf |> select(pmcid, file))
}
files <- distinct(files, file, .keep_all = TRUE)
message("tabular files to score: ", nrow(files))

score_file <- function(pmcid, path) {
  tabs <- read_tables(path)
  if (!length(tabs)) return(NULL)
  imap_dfr(tabs, function(d, nm) {
    if (is.null(d) || !ncol(d) || !nrow(d)) return(NULL)
    s <- score_table(d)
    if (is.null(s)) return(NULL)
    s$pmcid <- pmcid; s$file <- path; s$sheet <- nm
    s$name_hits <- sum(str_detect(tolower(names(d)), NAME_RX))
    s
  })
}

scored <- future_map2_dfr(files$pmcid, files$file, score_file,
                          .progress = TRUE, .options = furrr_options(seed = TRUE))

review <- scored |>
  mutate(rating_col = n_cols_0to100 > 0 | n_cols_0to10 > 0,
         score = 3 * n_cols_0to100 + 2 * n_cols_0to10 +
                 pmin(n_item_like, 20) + pmin(name_hits, 10)) |>
  filter(nrow_head >= 20, n_numeric >= 3, rating_col, n_item_like >= 3) |>
  arrange(desc(score)) |>
  select(pmcid, file, sheet, score, nrow_head, ncol, n_numeric,
         n_cols_0to100, n_cols_0to10, n_item_like, name_hits, cols)

message("files on the review list: ", nrow(review))
saveRDS(list(cand = cand, scored = scored, review = review), "data/screen.rds")
write_csv(review, "out/review_list.csv")
write_csv(cand |> filter(nzchar(repo_links)) |> select(pmcid, repo_links),
          "out/repo_links.csv")
