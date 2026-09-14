# Visual summaries of sample quality, validation and screening decisions
tab <- function(name) read.csv(file.path("outputs/tables", paste0(name, ".csv")), check.names = FALSE)
navy <- "#163A5F"; teal <- "#19847F"; amber <- "#C47B30"; muted <- "#63788B"
figure <- function(name, width = 1500, height = 950) {
  png(file.path("outputs/figures", paste0(name, ".png")), width, height, res = 160,
      type = if (capabilities("aqua")) "quartz" else "cairo")
  par(mar = c(6, 5, 4, 2), family = "sans", col.axis = navy, col.lab = navy,
      col.main = navy, las = 1, bty = "l", cex.main = 1.15)
}
pct <- function(x, digits = 1) paste0(formatC(100 * x, format = "f", digits = digits), "%")

impact <- subset(tab("complete-case-selection-diagnostic"), file == "5year.arff")
figure("complete-case-selection-impact")
rates <- matrix(100 * impact$removed_fraction, nrow = 2)
bp <- barplot(rates, beside = TRUE, names.arg = unique(impact$feature_set), col = c(muted, amber),
  ylim = c(0, max(rates) * 1.45), ylab = "Observations excluded (%)",
  main = "Complete-case exclusion changes the development sample")
text(bp, rates + max(rates) * .06, labels = sprintf("%.1f%%", rates), cex = .85)
legend("topleft", c("Non-bankrupt", "Bankrupt"), fill = c(muted, amber), bty = "n", cex = .85)
mtext("One-year development sample | diagnostic only; model fitting retains all records", side = 1, line = 4.8, cex = .75)
dev.off()

miss <- subset(tab("missing-data-profile"), file == "5year.arff")
miss <- head(miss[order(-miss$missing_rate), ], 12)
figure("one-year-sample-missingness")
par(mar = c(6, 7, 4, 3))
barplot(rev(100 * miss$missing_rate), names.arg = rev(miss$feature), horiz = TRUE,
  col = navy, xlab = "Missing observations (%)", main = "Missing values in the one-year-ahead sample")
mtext("Full raw sample | 12 ratios with the most missing values", side = 1, line = 4.8, cex = .8)
dev.off()

ratios <- tab("development-predictor-correlations")
correlation_matrix <- as.matrix(ratios[, -1])
figure("development-ratio-correlations", 1500, 1200)
par(mar = c(7, 7, 4, 2))
image(1:16, 1:16, correlation_matrix[, 16:1], zlim = c(-1, 1),
  col = colorRampPalette(c(amber, "white", navy))(101), axes = FALSE, xlab = "", ylab = "",
  main = "Financial ratio correlations in the development sample")
axis(1, 1:16, labels = ratios$feature, las = 2, cex.axis = .8)
axis(2, 1:16, labels = rev(ratios$feature), las = 1, cex.axis = .8)
for (a in 1:16) for (b in 1:16) {
  value <- correlation_matrix[a, 17 - b]
  text(a, b, sprintf("%.1f", value), cex = .58,
       col = if (abs(value) > .65) "white" else navy)
}
mtext("Pearson r: -1 (amber) to +1 (navy) | imputed and clipped one-year development ratios", side = 1, line = 5.2, cex = .75)
dev.off()

curves <- tab("holdout-ranking-curves")
performance <- subset(tab("horizon-holdout-performance"), horizon_years == 1)
figure("holdout-roc-and-precision-recall", 1800, 850)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
plot(0:1, 0:1, type = "n", xlab = "False-positive rate", ylab = "Bankruptcy recall",
  main = "Holdout credit-risk discrimination", xaxs = "i", yaxs = "i")
abline(0, 1, col = "#CCD4DC", lty = 2)
for (j in 1:2) {
  z <- subset(curves, model == MODEL_NAMES[j])
  lines(c(0, z$false_positive_rate), c(0, z$recall), col = c(navy, teal)[j], lwd = 2)
}
legend("bottomright", legend = paste0(c("Logistic", "Forest"), " AUC ", sprintf("%.3f", performance$roc_auc)),
  col = c(navy, teal), lwd = 2, bty = "n", cex = .85)
plot(0:1, 0:1, type = "n", xlab = "Bankruptcy recall", ylab = "Precision",
  main = "Holdout precision and recall", xaxs = "i", yaxs = "i")
for (j in 1:2) {
  z <- subset(curves, model == MODEL_NAMES[j])
  lines(z$recall, z$precision, col = c(navy, teal)[j], lwd = 2)
}
abline(h = performance$bankruptcies[1] / performance$n[1], col = muted, lty = 2)
legend("topright", legend = c(paste0(c("Logistic", "Forest"), " AP ", sprintf("%.3f", performance$average_precision)), "Event-rate baseline"),
  col = c(navy, teal, muted), lty = c(1, 1, 2), lwd = 2, bty = "n", cex = .85)
dev.off()

bands <- tab("holdout-risk-bands")
figure("holdout-bankruptcy-risk-bands")
heights <- rbind(bands$average_predicted_risk, bands$observed_bankruptcy_rate) * 100
bp <- barplot(heights, beside = TRUE, names.arg = paste0(bands$band, "\nn = ", bands$n),
  col = c(muted, teal), ylim = c(0, max(heights) * 1.32),
  ylab = "Bankruptcy risk (%)", main = "Observed bankruptcy rates across logistic risk bands")
text(bp, heights + max(heights) * .05, sprintf("%.1f%%", heights), cex = .85)
legend("topleft", c("Average predicted risk", "Observed bankruptcy rate"), fill = c(muted, teal), bty = "n", cex = .9)
mtext("Band boundaries fixed using development predictions; results shown on holdout", side = 1, line = 4.8, cex = .75)
dev.off()

capacity <- tab("development-capacity-analysis")
figure("development-screening-capacity")
plot(c(0, .32), c(0, 1), type = "n", xlab = "Development review capacity", ylab = "Bankruptcy recall",
  main = "Screening recall depends on available review capacity")
for (j in 1:2) {
  z <- subset(capacity, model == MODEL_NAMES[j])
  lines(z$review_rate, z$recall, type = "b", pch = 19, col = c(navy, teal)[j], lwd = 2)
}
abline(v = .2, col = amber, lty = 2)
legend("bottomright", c("Ridge logistic", "Balanced random forest", "Selected 20% review budget"),
  col = c(navy, teal, amber), lty = c(1, 1, 2), lwd = 2, bty = "n", cex = .85)
mtext("Cross-fitted development estimates; policy selection is evaluated separately on holdout", side = 1, line = 4.8, cex = .75)
dev.off()

figure("holdout-cumulative-bankruptcy-capture")
plot(0:1, 0:1, type = "n", xlab = "Fraction of holdout observations reviewed", ylab = "Fraction of bankruptcies captured",
  main = "Bankruptcy capture from reviewing the highest scores", xaxs = "i", yaxs = "i")
abline(0, 1, col = muted, lty = 2)
for (j in 1:2) {
  z <- subset(curves, model == MODEL_NAMES[j])
  lines(c(0, z$review_fraction), c(0, z$recall), col = c(navy, teal)[j], lwd = 2)
}
legend("bottomright", c("Ridge logistic", "Balanced random forest", "Random ordering"),
       col = c(navy, teal, muted), lty = c(1, 1, 2), lwd = 2, bty = "n")
dev.off()

cal <- tab("holdout-calibration-bins")
limit <- max(cal$mean_predicted_risk, cal$observed_rate) * 1.15
figure("holdout-risk-calibration")
plot(c(0, limit), c(0, limit), type = "n", xlab = "Average predicted bankruptcy risk",
  ylab = "Observed bankruptcy rate", main = "Holdout calibration using development-defined score bins")
abline(0, 1, col = muted, lty = 2)
for (j in 1:2) {
  z <- subset(cal, model == MODEL_NAMES[j])
  lines(z$mean_predicted_risk, z$observed_rate, type = "b", pch = 19, col = c(navy, teal)[j], lwd = 2)
}
legend("topleft", c("Ridge logistic", "Balanced random forest", "Perfect calibration"),
  col = c(navy, teal, muted), lty = c(1, 1, 2), lwd = 2, bty = "n", cex = .85)
dev.off()

drivers <- head(tab("logistic-risk-drivers"), 8)
figure("logistic-financial-risk-drivers", 1750, 1050)
par(mar = c(6, 19, 4, 2))
or <- rev(drivers$calibrated_odds_ratio_per_iqr)
plot(or, seq_along(or), log = "x", yaxt = "n", pch = 19, col = navy, cex = 1.3,
  xlim = range(c(.8, 1.2, or)) * c(.9, 1.1), xlab = "Calibrated odds ratio per development interquartile increase",
  ylab = "", main = "Conditional associations in the regularized logistic model")
axis(2, at = seq_along(or), labels = rev(drivers$description), las = 1, cex.axis = .85)
abline(v = 1, col = muted, lty = 2)
mtext("Associations conditional on the other model inputs; no causal interpretation", side = 1, line = 4.8, cex = .8)
dev.off()

horizons <- tab("horizon-holdout-performance")
figure("multi-horizon-model-discrimination")
plot(c(1, 5), c(.5, 1), type = "n", xlab = "Prediction horizon (years)", ylab = "Holdout ROC AUC",
  main = "Separate model evaluations across forecasting horizons", xaxt = "n")
axis(1, 1:5)
for (j in 1:2) {
  z <- subset(horizons, model == MODEL_NAMES[j]); z <- z[order(z$horizon_years), ]
  lines(z$horizon_years, z$roc_auc, type = "b", pch = 19, col = c(navy, teal)[j], lwd = 2)
}
legend("bottomleft", MODEL_NAMES, col = c(navy, teal), lwd = 2, pch = 19, bty = "n")
mtext("Files are modeled separately; this is not a longitudinal or calendar-time backtest", side = 1, line = 4.8, cex = .8)
dev.off()

sens <- subset(tab("financial-ratio-sensitivity"), iqr_shift > 0)
figure("financial-ratio-model-sensitivity", 1650, 950)
par(mar = c(8, 18, 4, 2))
mat <- t(sapply(unique(sens$feature), function(v) sens$mean_risk_change[sens$feature == v])) * 100
barplot(t(mat), beside = TRUE, horiz = TRUE, names.arg = unname(LABELS[unique(sens$feature)]),
        col = c(navy, teal), xlab = "Change in average predicted risk (percentage points)",
        main = "Model sensitivity to a half-IQR increase in one financial ratio")
abline(v = 0, col = muted)
legend("bottom", MODEL_NAMES, fill = c(navy, teal), bty = "n", cex = .8,
       horiz = TRUE, inset = c(0, -.38), xpd = NA)
mtext("One-at-a-time changes within development support; not an accounting-consistent stress scenario", side = 1, line = 6.4, cex = .7)
dev.off()
