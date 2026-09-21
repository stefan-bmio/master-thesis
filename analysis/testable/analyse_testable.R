#!/usr/bin/env Rscript
# Run from repository root: Rscript analysis/testable/analyse_testable.R
# Base R only. Raw exports are never changed. Contrast: Labeling - Matching.
options(stringsAsFactors = FALSE, digits = 10)
args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1]) else getwd()
src <- file.path(root, "cuelens_testable.org")
out <- file.path(root, "analysis/testable/output")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
read_csv <- function(...) read.csv(..., check.names = FALSE,
  colClasses = "character", na.strings = NULL, fileEncoding = "UTF-8")
num <- function(x) suppressWarnings(as.numeric(x))
trial <- read_csv(file.path(src, "trial_file.csv"))
trial$rowNo <- as.character(seq_len(nrow(trial)) + 1L)
block <- 0L; condition <- NA_character_
trial$block <- NA_integer_; trial$condition <- NA_character_
for (j in seq_len(nrow(trial))) {
  if (grepl("^Block [0-9]+/20:", trial$stim1[j])) {
    block <- block + 1L
    condition <- if (grepl("small image", trial$stim1[j])) "M" else "L"
  }
  trial$block[j] <- block; trial$condition[j] <- condition
}
map <- trial[trial$type == "form" & trial$responseType == "slider",
             c("rowNo", "block", "condition")]
stopifnot(nrow(map) == 20, identical(map$block, 1:20),
  identical(map$condition, rep(c("M", "L"), 10)))
stopifnot(sum(trial$type == "practice" & grepl("^cue_match_", trial$stim1)) == 50,
  sum(trial$type == "practice" & grepl("^cue_[0-9]", trial$stim1)) == 50)
write.csv(map, file.path(out, "trial_mapping.csv"), row.names = FALSE)
files <- sort(list.files(file.path(src, "996939_20260916_153409_all"),
                        pattern = "[.]csv$", full.names = TRUE))
stopifnot(length(files) > 0)
records <- lapply(files, function(f) {
  lines <- readLines(f, warn = FALSE, encoding = "UTF-8")
  h <- grep("^rowNo,", lines)
  stopifnot(length(h) == 1L)
  list(meta = read_csv(text = paste(lines[1:2], collapse = "\n")),
       rows = read_csv(text = paste(lines[h:length(lines)], collapse = "\n")))
})
field <- function(m, key) if (key %in% names(m)) m[[key]][1] else ""
ids <- vapply(records, function(z) field(z$meta, "participant"), "")
stopifnot(!anyDuplicated(ids[nzchar(ids)]))
summaries <- list(); outcomes <- list()
for (i in seq_along(records)) {
  z <- records[[i]]; r <- z$rows; m <- z$meta
  s <- r[r$type == "form" & r$responseType == "slider", ]
  pos <- match(s$rowNo, map$rowNo) # suffixes such as 16_2 remain unmapped
  y <- rep(NA_real_, 20); elapsed <- y
  for (k in seq_len(20)) {
    ix <- which(pos == k)
    if (length(ix) == 1L) {
      y[k] <- num(s$response[ix]); elapsed[k] <- num(s$timestamp[ix]) / 60000
    }
  }
  valid <- is.finite(y) & y >= 0 & y <= 100
  extra <- sum(is.na(pos)); complete <- all(valid) && extra == 0 && nrow(s) == 20
  age <- num(r$response[r$label == "Q1"])
  cigs <- num(r$response[r$label == "Q2"])
  stopifnot(length(age) == 1, length(cigs) == 1)
  eligible <- is.finite(age) && age >= 30 && is.finite(cigs) && cigs >= 10
  identified <- nzchar(ids[i]) && field(m, "trial_file_version") == "2026-09-15_17:52:16"
  pair_ok <- valid[seq(1, 19, 2)] & valid[seq(2, 20, 2)]
  ds <- y[seq(2, 20, 2)] - y[seq(1, 19, 2)]
  dt <- diff(elapsed) * 60
  good_time <- all(is.finite(elapsed)) && all(diff(elapsed) > 0)
  slope <- beta_block <- beta_time <- NA_real_
  if (complete && good_time) {
    x <- data.frame(y = y, L = as.integer(map$condition == "L"),
                    block = map$block, minutes = elapsed - elapsed[1])
    beta_block <- unname(coef(lm(y ~ L + block, x))["L"])
    fit_time <- lm(y ~ L + minutes, x)
    beta_time <- unname(coef(fit_time)["L"])
    slope <- unname(coef(fit_time)["minutes"])
  }
  summaries[[i]] <- data.frame(session = i, identified, complete, eligible,
    age, cigarettes = cigs, OS = field(m, "OS"),
    version = field(m, "trial_file_version"), duration_min = num(field(m, "duration_s"))/60,
    reports = nrow(s), valid_reports = sum(valid), unmapped_reports = extra,
    complete_pairs = sum(pair_ok), M = mean(y[map$condition == "M"], na.rm = TRUE),
    L = mean(y[map$condition == "L"], na.rm = TRUE),
    difference = if (any(pair_ok)) round(mean(ds[pair_ok]), 10) else NA_real_,
    below300 = sum(dt < 300, na.rm = TRUE), min_interval_s = min(dt, na.rm = TRUE),
    beta_block, beta_time, slope, first = y[1], last = y[20],
    good_time, constant = length(unique(y[valid])) == 1L)
  outcomes[[i]] <- data.frame(session = i, map, value = y, elapsed_min = elapsed)
}
p <- do.call(rbind, summaries); long <- do.call(rbind, outcomes)
p$primary <- with(p, identified & complete & eligible & good_time)
main <- p[p$primary, ]; d <- main$difference
stopifnot(nrow(main) >= 2, all(is.finite(d)))
# Participant means are the independent observations, not individual reports.
contrast <- function(x, name) {
  x <- x[is.finite(x)]; tt <- t.test(x, mu = 0, alternative = "two.sided")
  data.frame(analysis = name, n = length(x), mean = mean(x), sd = sd(x),
    lower = tt$conf.int[1], upper = tt$conf.int[2], t = unname(tt$statistic),
    df = unname(tt$parameter), p = tt$p.value, dz = mean(x)/sd(x))
}
analyses <- rbind(contrast(d, "primary_complete_identified"),
  contrast(p$difference[p$complete & p$eligible & p$good_time], "include_unidentified_older_session"),
  contrast(p$difference[p$identified & p$eligible & p$complete_pairs > 0], "available_pairs_identified"),
  contrast(main$difference[main$age <= 65], "app_age_limit_65"),
  contrast(main$difference[main$below300 == 0], "all_report_intervals_at_least_300s"),
  contrast(main$beta_block, "person_specific_linear_block_adjustment"),
  contrast(main$beta_time, "person_specific_linear_time_adjustment"),
  contrast(main$last - main$first, "last_minus_first_descriptive"))
wt <- wilcox.test(d, exact = FALSE, correct = TRUE)
set.seed(20260921)
boot <- replicate(10000, mean(sample(d, length(d), replace = TRUE)))
bci <- quantile(boot, c(.025, .975), names = FALSE)
write.csv(analyses, file.path(out, "contrasts.csv"), row.names = FALSE)
write.csv(data.frame(wilcoxon_V = unname(wt$statistic), wilcoxon_p = wt$p.value,
  bootstrap_lower = bci[1], bootstrap_upper = bci[2], replications = 10000),
  file.path(out, "robustness.csv"), row.names = FALSE)
# Only aggregate outputs are published; no free text, links or participant IDs.
describe <- function(x) c(n = length(x), mean = mean(x), sd = sd(x),
  median = median(x), q1 = unname(quantile(x, .25)), q3 = unname(quantile(x, .75)),
  min = min(x), max = max(x))
vars <- c("age", "cigarettes", "duration_min", "M", "L", "difference", "slope")
desc <- do.call(rbind, lapply(vars, function(v)
  data.frame(variable = v, as.list(describe(main[[v]])))))
write.csv(desc, file.path(out, "descriptives.csv"), row.names = FALSE)
ml <- long[long$session %in% main$session, ]
blocks <- do.call(rbind, lapply(split(ml, ml$block), function(a) {
  ci <- t.test(a$value)$conf.int
  data.frame(block = a$block[1], condition = a$condition[1],
             mean = mean(a$value), sd = sd(a$value), lower = ci[1], upper = ci[2])
}))
blocks <- blocks[order(blocks$block), ]
write.csv(blocks, file.path(out, "block_summary.csv"), row.names = FALSE)
flow <- data.frame(metric = c("files", "identified", "primary", "primary_reports",
  "unidentified", "identified_incomplete", "below300_sessions", "below300_intervals",
  "intervals_total", "constant_sessions", "age_over65", "negative_differences",
  "zero_differences", "positive_differences"), value = c(length(files), sum(p$identified),
  nrow(main), nrow(ml), sum(!p$identified), sum(p$identified & !p$complete),
  sum(main$below300 > 0), sum(main$below300), nrow(main)*19,
  sum(main$constant), sum(main$age > 65), sum(d < 0), sum(d == 0), sum(d > 0)))
write.csv(flow, file.path(out, "data_flow.csv"), row.names = FALSE)
write.csv(as.data.frame(table(main$OS)), file.path(out, "operating_systems.csv"), row.names = FALSE)
input_files <- c(file.path(src, "trial_file.csv"), files)
write.csv(data.frame(path = substring(input_files, nchar(root)+2),
  md5 = unname(tools::md5sum(input_files))), file.path(out, "input_checksums.csv"), row.names = FALSE)
writeLines(trimws(capture.output(sessionInfo()), "right"), file.path(out, "sessionInfo.txt"))
# LaTeX numbers and tables are generated from the same calculated results.
fmt <- function(x, digits = 2) formatC(x, format = "f", digits = digits, decimal.mark = ",")
tex <- c("% Generated by analyse_testable.R; do not edit numbers manually.")
macro <- function(name, x, digits = 2) {
  tex <<- c(tex, paste0("\\newcommand{\\", name, "}{", fmt(x, digits), "}"))
}
macro("TestableN", nrow(main), 0)
macro("TestableM", mean(main$M)); macro("TestableL", mean(main$L))
macro("TestableSDM", sd(main$M)); macro("TestableSDL", sd(main$L))
macro("TestableDiff", mean(d)); macro("TestableSDDiff", sd(d))
macro("TestableLower", analyses$lower[1]); macro("TestableUpper", analyses$upper[1])
macro("TestableT", analyses$t[1], 3); macro("TestableP", analyses$p[1], 3)
macro("TestableDz", analyses$dz[1], 3)
macro("TestableWilcoxonP", wt$p.value, 3); macro("TestableWilcoxonV", unname(wt$statistic), 1)
macro("TestableBootLo", bci[1]); macro("TestableBootHi", bci[2])
macro("TestableAge", mean(main$age)); macro("TestableSDAge", sd(main$age))
macro("TestableCigs", mean(main$cigarettes)); macro("TestableSDCigs", sd(main$cigarettes))
macro("TestableDuration", median(main$duration_min))
macro("TestableDurationQone", unname(quantile(main$duration_min, .25)))
macro("TestableDurationQthree", unname(quantile(main$duration_min, .75)))
writeLines(tex, file.path(out, "numbers.tex"))
labels <- c("Hauptanalyse", "Mit älterer Sitzung ohne Kennung", "Verfügbare Blockpaare",
  "Altersgrenze 65 Jahre", "Alle Berichtsabstände mindestens 5 min",
  "Linearer Blocktrend je Person", "Linearer Zeittrend je Person")
eol <- paste0(intToUtf8(92), intToUtf8(92))
tab <- c("\\begin{tabular}{p{.38\\linewidth}rrrr}", "\\toprule",
         paste0("Analyse & $n$ & Differenz & 95\\,\\%-KI & $p$ ", eol), "\\midrule")
for (j in 1:7) tab <- c(tab, paste0(labels[j], " & ", analyses$n[j], " & ",
  fmt(analyses$mean[j]), " & [", fmt(analyses$lower[j]), "; ",
  fmt(analyses$upper[j]), "] & ", fmt(analyses$p[j], 3), " ", eol))
writeLines(c(tab, "\\bottomrule", "\\end{tabular}"), file.path(out, "sensitivity_table.tex"))
# Reproducible vector figures (base graphics, no external packages).
cairo_pdf(file.path(out, "testable_results.pdf"), width = 9, height = 4.2,
          family = "DejaVu Sans")
par(mfrow = c(1, 2), mar = c(4.4, 4.1, 2, .7), las = 1)
matplot(t(as.matrix(main[c("M", "L")])), type = "l", lty = 1,
  col = adjustcolor("grey40", .25), xaxt = "n", xlim = c(.8, 2.2), ylim = c(0,100),
  xlab = "Bedingung", ylab = "Mittleres Rauchverlangen (0-100)", main = "A  Personenmittelwerte")
axis(1, 1:2, c("Matching", "Labeling"))
lines(1:2, c(mean(main$M), mean(main$L)), lwd = 3, col = "#006269", type = "b", pch = 19)
hist(d, breaks = "FD", col = "#B5DCD4", border = "white",
  xlab = "Labeling minus Matching (Punkte)", ylab = "Personen", main = "B  Individuelle Differenzen")
abline(v = 0, lty = 2); abline(v = mean(d), col = "#006269", lwd = 2)
dev.off()
cairo_pdf(file.path(out, "testable_timecourse.pdf"), width = 8, height = 3.8,
          family = "DejaVu Sans")
par(mar = c(4.2, 4.2, 1.2, .7), las = 1)
plot(blocks$block, blocks$mean, type = "l", ylim = range(blocks[c("lower", "upper")]),
  xlab = "Block (ungerade: Matching; gerade: Labeling)",
  ylab = "Rauchverlangen (0-100)", xaxt = "n")
axis(1, 1:20); arrows(blocks$block, blocks$lower, blocks$block, blocks$upper,
  angle = 90, code = 3, length = .025, col = "grey50")
points(blocks$block, blocks$mean, pch = ifelse(blocks$condition == "M", 16, 17),
       col = ifelse(blocks$condition == "M", "#006269", "#B76036"), cex = 1.2)
legend("topleft", c("Matching", "Labeling"), pch = c(16,17),
       col = c("#006269", "#B76036"), bty = "n")
dev.off()
print(flow, row.names = FALSE); print(desc, row.names = FALSE)
print(analyses, row.names = FALSE); print(wt); print(bci)
