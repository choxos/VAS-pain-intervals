# Is 10 points of pain always 10 points?

Testing whether the 0 to 100 visual analogue scale for pain behaves as an
interval scale, using shared individual participant data from the published
literature.

## Question

A displayed VAS interval is treated as a constant quantity: a 10 point drop is
a 10 point drop whether it runs from 80 to 70 or from 20 to 10. That is an
assumption, not a measurement property. This project estimates how much latent
pain a fixed displayed interval actually spans, the pain analogue of the PISA
score interval plot.

## Method

1. Fit a unidimensional IRT model to a multi item pain intensity instrument
   measured on the same people, excluding the VAS. EAP factor scores give an
   independently defined latent pain metric, theta.
2. Regress theta on the displayed VAS with a monotone increasing spline,
   giving f with VAS = f inverse of theta.
3. `D(v) = f(v + 10) - f(v)` is the latent distance spanned by a 10 point
   displayed interval starting at v. Under an interval scale D is flat.
4. Rescale so that the mean of D across the middle of the observed VAS
   distribution equals 10, so the curve reads directly as a ruler.

The multi item instrument must measure pain intensity or severity (BPI severity,
WOMAC pain, KOOS pain, SF-MPQ, PROMIS pain intensity), not disability or
catastrophizing, or theta is a different construct and the curve means nothing.

## Pipeline

| Script | Does |
| --- | --- |
| `R/01_search.R` | Europe PMC search, three strata, open access with full text in EPMC |
| `R/01b_search_plos.R` | Extra stratum for journals with mandatory data policies |
| `R/02_flag.R` | Download PMC XML, detect data sharing with `rtransparency::rt_data_code_pmc` |
| `R/03_screen.R` | Pull supplementary bundles, score every table and Excel sheet, emit a ranked review list |
| `R/03b_repos.R` | Follow figshare, Zenodo, OSF and Dryad links and download tabular files |
| `R/04_interval_curve.R` | IRT plus monotone spline estimator, with a synthetic data self check |
| `R/05_figure.R` | Figure helpers |
| `R/07_run.R` | Curated analysis of the admissible dataset |
| `R/08_repo_search.R` | Direct Zenodo, Dryad and OSF search by instrument |
| `R/09_figures.R` | Funnel, sharing trend and granularity figures |
| `R/10_figure_main.R` | The PISA style figure |

Run `Rscript R/04_interval_curve.R` on its own to execute the self check: it
simulates a display with known compression at the top and asserts the estimator
recovers an increasing interval curve.

Screening scores tables on shape rather than column name regexes, because real
shared files name the rating `PI`, `pain0` or `NRS` at least as often as `VAS`.
A table earns a high score when it holds a wide 0 to 100 column alongside a
block of small integer columns.

## Caveat

The curve measures VAS intervals relative to the IRT logit metric. That metric
is itself a modeling choice, the same assumption the PISA plot makes. It is the
comparison that is informative, not the absolute units.

## Results

Stage 1 is complete and written up in [REPORT.md](REPORT.md), with figures in
`out/figures/` and tables in `out/`. Headline: of 4,567 open access papers,
493 carry a data availability statement and two share the item level responses
the method needs. Neither of the two can carry the analysis.

## Data

`data/` is gitignored. Downloaded datasets stay local and keep their original
licenses and citations.
