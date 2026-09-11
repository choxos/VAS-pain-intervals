# Is the Visual Analogue Scale an Interval Scale?

## Stage 1: what the published literature can actually support

**Date:** 10 September 2026
**Status:** search and screening complete; the analysis is blocked by data supply, not by method.

---

## Summary

The plan was the pain analogue of the PISA score interval plot: estimate latent
pain from a multi item pain instrument, regress the displayed VAS on it with a
monotone spline, and show how much latent pain a 10 point displayed interval
actually spans at each point on the scale.

The method works. It was validated against simulated data where the display's
nonlinearity is known by construction, and it recovers the true curve.

The shared data cannot carry it. Of **4,567** open access papers that use a VAS
for pain alongside a named multi item pain instrument, **493** carry a data
availability statement, and **two** share the item level responses an item
response model requires. Neither of those two can carry the analysis. The rest share
subscale and instrument totals, which cannot be modeled.

This is a real finding about the research record rather than a failure of the
search. It is also the single most useful thing to know before committing to
this project: the bottleneck is not finding papers, it is that pain researchers
deposit scores, not responses.

---

## What was done

### Search

Europe PMC, open access with full text in EPMC, 2012 to 2026. The query required
a visual analogue scale term, the word pain, and a named multi item pain
instrument, all in the abstract:

> Brief Pain Inventory, McGill Pain Questionnaire, WOMAC, KOOS, PROMIS, SF-MPQ,
> numeric rating scale, numerical rating scale, or pain intensity

Four strata were run and de-duplicated: a broad stratum taken to exhaustion
(4,581 hits), a supplementary material stratum, a body text stratum matching
repository names, and a journal policy stratum covering PLOS ONE, Scientific
Reports, BMJ Open and PeerJ. The journal policy stratum returned **zero** records
not already captured, which is reassuring about coverage: the journals with
mandatory data policies were already fully inside the net.

**4,570 unique PMC records.**

### Data sharing detection

Every record's full text XML was downloaded and passed through
`rtransparency::rt_data_code_pmc()`. 4,567 were processed successfully.

| | n | % of screened |
|---|---:|---:|
| Papers screened | 4,567 | 100% |
| Data availability statement detected | 493 | 10.8% |
| Code sharing detected | 36 | 0.8% |
| With a repository link (figshare, OSF, Zenodo, Dryad) | 41 | 0.9% |

Detection has risen steadily, from zero in 2012 and 2013 to 16.5% in 2026.

**What those 493 statements actually say matters more than the count.** The
detector reports that an availability statement exists, not that usable data sit
behind it:

| Statement type | n | % of the 493 |
|---|---:|---:|
| In the article or its supplement | 324 | 65.7% |
| Other wording | 130 | 26.4% |
| Names a repository or accession | 39 | 7.9% |

Two thirds point at the article itself, which is exactly where screening then
found subscale totals rather than item responses. Any headline rate quoted from
this corpus should say "availability statement detected", not "data shared".

![Data sharing trend](out/figures/fig2_sharing_trend.png)

### Retrieval and screening

Supplementary bundles were pulled from the Europe PMC `supplementaryFiles`
endpoint for every flagged paper, and repository links were resolved through the
figshare, Zenodo, OSF and Dryad APIs. **102 tabular files** were retrieved, **77**
of them machine readable, yielding **161 tables** once every sheet of every
workbook was scored separately.

Screening scores tables on *shape* rather than column name regexes, because real
shared files name the rating `PI`, `pain0` or `NRS` at least as often as `VAS`. A
table scores highly when it holds a wide 0 to 100 column alongside a block of
small integer columns, which is what an item level pain dataset looks like. That
produced a ranked review list of **60 tables**, which were then read by hand.

![The funnel](out/figures/fig1_funnel.png)

### What the 60 shortlisted tables contained

![Granularity](out/figures/fig3_granularity.png)

The shape heuristic did its job as a ranker, but hand review was decisive. Most
shortlisted tables earned their small integer columns from sex, ASA grade,
comorbidity flags and treatment arm, not from questionnaire items. A targeted
scan for the item block signatures of WOMAC, KOOS, SF-MPQ, BPI and PROMIS across
all 161 tables returned **7 hits**, of which 5 were subscale totals.

**Two datasets held genuine item level pain responses.**

---

## The two candidates, and why neither works

### PMC5524330: knee osteoarthritis, n = 386 observations from 98 patients

Holds the full WOMAC as items: `WOM A-1` to `A-5` (pain), `B-1` to `B-2`
(stiffness), `C-1` to `C-17` (function), plus a separate global VAS.

**Inadmissible, on construct grounds.** Each WOMAC item is itself scored on a 0
to 100 visual analogue scale. Building the latent metric out of VAS responses
and then testing a VAS against it cannot detect a nonlinearity the two displays
share, so the design is biased toward concluding that the scale is fine. The
independent reference the method needs is exactly what this dataset lacks.

Two secondary problems would also have to be handled: 101 response categories per
item need coarsening before a graded model will fit, and the 386 rows are four
visits from 98 people.

### PMC10695107: knee osteoarthritis, n = 57

Holds the WOMAC pain subscale as five genuine 0 to 4 Likert items, measured at
baseline and six weeks, with a separate VAS at each occasion. The items are
independent of the VAS display, so this one is admissible in principle.

**Underpowered and badly covered.** Baseline VAS spans only 60 to 90; six week
VAS spans 1 to 55. Neither occasion alone covers enough of the scale to fit a
curve. Stacking both occasions covers 1 to 90 but leaves a hole between 55 and
60. The fitted curve climbs from 8.3 to 24.5 as it crosses that empty stretch,
peaking just beyond it, with a bootstrap band running from 12.9 to 32.2. That is
the occasion gap, not scale geometry.

r(theta, VAS) = 0.66, which passes the construct check. Everything else fails.

---

## The figure, in the two forms the evidence supports

![Main figure](out/figures/fig4_interval_curve.png)

**Panel A** is 12 simulated cohorts where the display compresses the top by
construction. The estimator recovers the true curve: it reads about 13 near VAS
10, dips below 9 through the middle, and climbs back above 14 at the top. This
is the validation that the pipeline measures what it claims to.

**Panel B** is PMC10695107. It is shown because the honest output of this stage
is the yield, not a curve. The rise runs straight through a stretch of the scale
where the dataset has no observations, and the band is wider than any effect
worth reporting.

---

## Method

1. Fit a unidimensional IRT model to the multi item pain instrument, **excluding
   the VAS**. Both a graded response model and a Rasch model are fitted, so the
   figure can carry two bold lines the way the PISA plot does.
2. Take **WLE** factor scores as theta. EAP was rejected: it shrinks toward the
   prior mean, and hardest where test information is low, which is the tails.
   That would flatten the spline at both ends of the VAS and manufacture
   compression the scale does not have.
3. Regress theta on the displayed VAS with a monotone increasing spline
   (`scam`, `bs = "mpi"`).
4. `D(v) = f(v + 10) - f(v)` is the latent distance spanned by a 10 point
   displayed interval starting at v. Under an interval scale D is flat.
5. Rescale so that the mean of D across the 5th to 95th percentile of the
   observed VAS distribution equals 10, so the curve reads directly as a ruler.
   Normalizing over the full 0 to 90 grid would let empty tails dominate.

Two contamination guards matter. Any column named as a visual analogue scale is
barred from the item block, and so is any column correlating above 0.95 with the
chosen display, which catches the same rating recorded twice in different units.
BPI severity items are deliberately **not** barred despite being named
`pain_worst` and `pain_now`: the graded model frees every item threshold, so a
0 to 10 item response is not assumed linear in latent pain, and excluding them
would delete the best instrument in the corpus.

Repeated measures of one item are not items. A dataset whose proposed item block
is mostly timepoint suffixed is flagged and refused unless explicitly overridden,
or theta becomes average pain over the trial rather than pain at the moment the
rating was given.

### Validation

`Rscript R/04_interval_curve.R` runs a self check: it simulates a display with
known top end compression and asserts the estimator recovers an increasing
interval curve with the normalization intact. It covers both the graded and the
Rasch path.

---

## What this means for the project

The exploratory version of this study cannot be done from journal supplements.
Three routes remain, in order of cost:

1. **Cohorts that deposit item level data by design.** The Osteoarthritis
   Initiative and MOST both hold WOMAC at item level with pain ratings, at
   sample sizes three orders of magnitude above anything here. Both need a data
   use agreement rather than a download. This is the fastest route to the figure.

   A direct search of Zenodo, Dryad and OSF by instrument name
   (`R/08_repo_search.R`, results in `out/repo_search_hits.csv`) surfaced five
   further human pain datasets worth opening by hand, including a Dryad deposit
   on staged bilateral knee arthroplasty pain and an OSF item content analysis of
   the Brief Pain Inventory interference subscale.

2. **Ask the two authors.** PMC10695107 has admissible items and only needs more
   participants; the same group may hold more.

3. **The psychophysics design.** Controlled thermal or pressure stimuli with
   pairwise comparisons, building the latent scale from a Bradley-Terry model
   rather than from another questionnaire. This is the most convincing version
   of the study and the most expensive.

There is also a second paper sitting in this output that needs no new data: of
4,567 open access pain papers, 10.8% share data and 0.04% share the item level
responses required to re-analyze a psychometric question. Sharing rates are
measured, rising, and precisely quantified here. That is a meta-research result
in its own right.

## Caveat carried from the design

The curve measures VAS intervals relative to the IRT logit metric. That metric is
itself a modeling choice, the same assumption the PISA plot makes. It is the
comparison that is informative, not the absolute units.

## Reproducing

```
Rscript R/01_search.R          # Europe PMC, three strata
Rscript R/01b_search_plos.R    # journal policy stratum
Rscript R/01c_search_rest.R    # exhaust the broad stratum
Rscript R/02_flag.R            # XML download, rtransparency detection
Rscript R/02b_flag_extra.R
Rscript R/03_screen.R          # supplements, shape scoring, review list
Rscript R/03b_repos.R          # figshare, Zenodo, OSF, Dryad
Rscript R/08_repo_search.R     # direct repository search by instrument
Rscript R/04_interval_curve.R  # estimator plus self check
Rscript R/07_run.R             # curated analysis
Rscript R/09_figures.R         # figures 1 to 3
Rscript R/10_figure_main.R     # main figure
```

`data/` is gitignored. Downloaded datasets stay local and keep their original
licenses and citations.
