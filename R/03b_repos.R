# Follow repository links found in flagged papers and pull any tabular files.
# Public research repositories expose the individual level data far more often
# than journal supplements do.
suppressMessages({library(dplyr); library(stringr); library(jsonlite); library(purrr)})

dir.create("data/repo", showWarnings = FALSE, recursive = TRUE)
DATA_EXT <- "\\.(csv|tsv|txt|xlsx?|sav|dta|por|zip)$"

api_get <- function(url) tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE),
                                  error = function(e) NULL)

# --- per repository file listing ----------------------------------------------
figshare_files <- function(link) {
  id <- str_match(link, "figshare[._/]*(?:com/)?(?:articles/)?(?:[a-z_]+/)*?([0-9]{6,})")[, 2]
  if (is.na(id)) return(NULL)
  j <- api_get(sprintf("https://api.figshare.com/v2/articles/%s/files", id))
  if (is.null(j)) return(NULL)
  tibble(name = map_chr(j, "name", .default = NA),
         url  = map_chr(j, "download_url", .default = NA))
}

zenodo_files <- function(link) {
  id <- str_match(link, "zenodo\\.(?:org/records?/|[0-9.]*)([0-9]{5,})")[, 2]
  if (is.na(id)) return(NULL)
  j <- api_get(sprintf("https://zenodo.org/api/records/%s", id))
  if (is.null(j$files)) return(NULL)
  tibble(name = map_chr(j$files, ~ .x$key %||% .x$filename %||% NA_character_),
         url  = map_chr(j$files, ~ .x$links$self %||% NA_character_))
}

osf_files <- function(link) {
  id <- str_match(link, "osf\\.io/([a-z0-9]{5})")[, 2]
  if (is.na(id)) return(NULL)
  j <- api_get(sprintf("https://api.osf.io/v2/nodes/%s/files/osfstorage/?page[size]=100", id))
  if (is.null(j$data)) return(NULL)
  tibble(name = map_chr(j$data, ~ .x$attributes$name %||% NA_character_),
         url  = map_chr(j$data, ~ .x$links$download %||% NA_character_))
}

dryad_files <- function(link) {
  doi <- str_match(link, "(10\\.5061/dryad\\.[a-z0-9._]+)")[, 2]
  if (is.na(doi)) return(NULL)
  enc <- utils::URLencode(paste0("doi:", doi), reserved = TRUE)
  j <- api_get(sprintf("https://datadryad.org/api/v2/datasets/%s", enc))
  v <- j$`_links`$`stash:version`$href
  if (is.null(v)) return(NULL)
  jf <- api_get(paste0("https://datadryad.org", v, "/files"))
  emb <- jf$`_embedded`$`stash:files`
  if (is.null(emb)) return(NULL)
  tibble(name = map_chr(emb, ~ .x$path %||% NA_character_),
         url  = map_chr(emb, ~ paste0("https://datadryad.org",
                                      .x$`_links`$`stash:download`$href %||% "")))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

list_repo_files <- function(link) {
  f <- NULL
  if (str_detect(link, "figshare"))      f <- figshare_files(link)
  else if (str_detect(link, "zenodo"))   f <- zenodo_files(link)
  else if (str_detect(link, "osf\\.io")) f <- osf_files(link)
  else if (str_detect(link, "dryad"))    f <- dryad_files(link)
  if (is.null(f) || !nrow(f)) return(NULL)
  f |> filter(!is.na(name), !is.na(url), nzchar(url),
              str_detect(tolower(name), DATA_EXT))
}

download_repo_file <- function(pmcid, name, url) {
  dd <- file.path("data/repo", pmcid)
  dir.create(dd, showWarnings = FALSE, recursive = TRUE)
  dest <- file.path(dd, basename(name))
  if (file.exists(dest) && file.size(dest) > 100) return(dest)
  ok <- tryCatch({download.file(url, dest, quiet = TRUE, mode = "wb"); TRUE},
                 error = function(e) FALSE)
  Sys.sleep(0.4)
  if (!ok) return(NA_character_)
  # Unpack zips so the screener sees the tables inside.
  if (grepl("\\.zip$", dest, ignore.case = TRUE)) {
    inner <- tryCatch(unzip(dest, exdir = dd), error = function(e) character())
    return(c(dest, inner))
  }
  dest
}

run_repos <- function(cand) {
  cand <- cand |> filter(nzchar(repo_links))
  message("papers with repository links: ", nrow(cand))
  out <- list()
  for (i in seq_len(nrow(cand))) {
    links <- strsplit(cand$repo_links[i], " ; ")[[1]]
    for (l in unique(links)) {
      fl <- list_repo_files(l)
      if (is.null(fl)) next
      paths <- unlist(Map(function(n, u) download_repo_file(cand$pmcid[i], n, u),
                          fl$name, fl$url))
      paths <- paths[!is.na(paths)]
      if (length(paths)) out[[length(out) + 1]] <-
        tibble(pmcid = cand$pmcid[i], link = l, file = paths)
    }
    if (i %% 20 == 0) message(i, "/", nrow(cand))
  }
  bind_rows(out)
}

if (sys.nframe() == 0L && !interactive()) {
  s <- readRDS("data/screen.rds")
  rf <- run_repos(s$cand)
  message("repository files downloaded: ", nrow(rf))
  saveRDS(rf, "data/repo_files.rds")
}
