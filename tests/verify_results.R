# Independently check saved predictions, screening counts and data handling.
source("R/00_functions.R")
read_table <- function(name) read.csv(file.path("outputs/tables", paste0(name, ".csv")))
predictions <- read_table("out-of-sample-predictions")
performance <- read_table("horizon-holdout-performance")
policies <- read_table("development-screening-policies")
inventory <- read_table("data-inventory")
for (i in 1:5) {
  d <- read_credit(i); key <- group_keys(d)
  p <- subset(predictions, file == paste0(i, "year.arff"))
  p <- p[order(p$row_id), ]
  stopifnot(identical(p$row_id, seq_len(nrow(d))), all(p$outcome == d$class),
    all(p$predictor_group == key), ncol(d) == 65, !anyNA(p),
    sum(d$class) == c(271, 400, 495, 515, 410)[i],
    nrow(d) == c(7027, 10173, 10503, 9792, 5910)[i])
  dev <- subset(p, sample == "Development cross-fitted")
  test <- subset(p, sample == "Holdout")
  stopifnot(!length(intersect(dev$predictor_group, test$predictor_group)),
            identical(test$row_id, sort(holdout_ids(d$class, key, SEED + i))))
  for (j in 1:2) {
    m <- subset(performance, horizon_years == 6 - i & model == MODEL_NAMES[j])
    policy <- subset(policies, horizon_years == 6 - i & model == MODEL_NAMES[j])
    score <- test[[c("logistic_risk", "forest_risk")[j]]]
    ds <- dev[[c("logistic_risk", "forest_risk")[j]]]
    y <- test$outcome; flag <- score >= m$threshold
    tp <- sum(flag & y == 1); fp <- sum(flag & y == 0)
    fn <- sum(!flag & y == 1); tn <- sum(!flag & y == 0)
    # Mann-Whitney rank statistic with average ranks gives the same tie-aware ROC AUC.
    auc <- (sum(rank(score)[y == 1]) - sum(y) * (sum(y) + 1) / 2) / (sum(y) * sum(y == 0))
    stopifnot(abs(auc - m$roc_auc) < 1e-12,
      m$tp == tp, m$fp == fp, m$fn == fn, m$tn == tn,
      abs(m$recall - tp / sum(y)) < 1e-12,
      abs(m$specificity - tn / sum(y == 0)) < 1e-12,
      abs(m$precision - tp / sum(flag)) < 1e-12,
      abs(m$accuracy - mean(flag == y)) < 1e-12,
      abs(m$brier - mean((score - y)^2)) < 1e-12,
      abs(m$threshold - policy$threshold) < 1e-12,
      mean(ds >= m$threshold) <= .2 + 1e-12,
      all(score > 0 & score < 1))
    distinct <- sort(unique(score), decreasing = TRUE)
    count <- vapply(distinct, function(s) sum(score == s), integer(1))
    events <- vapply(distinct, function(s) sum(y[score == s]), numeric(1))
    ap <- sum((events / sum(y)) * cumsum(events) / cumsum(count))
    stopifnot(abs(ap - m$average_precision) < 1e-12)
  }
}
selection <- read_table("complete-case-selection-diagnostic")
stopifnot(nrow(selection) == 20)
for (i in 1:5) {
  d <- read_credit(i)
  dev_idx <- subset(predictions, file == paste0(i, "year.arff") & sample == "Development cross-fitted")$row_id
  d <- d[dev_idx, ]
  for (specification in c("All 64 ratios", "Model 16 ratios")) {
    features <- if (specification == "All 64 ratios") paste0("Attr", 1:64) else FEATURES
    complete <- rowSums(!is.finite(as.matrix(d[features]))) == 0
    for (outcome_value in 0:1) {
      m <- subset(selection, file == paste0(i, "year.arff") & feature_set == specification &
                    outcome == c("Non-bankrupt", "Bankrupt")[outcome_value + 1])
      idx <- d$class == outcome_value
      stopifnot(nrow(m) == 1, m$n == sum(idx), m$retained_n == sum(idx & complete),
                m$removed_n == sum(idx & !complete),
                abs(m$removed_fraction - mean(!complete[idx])) < 1e-12)
    }
  }
}
d <- read_credit(5)
dev_idx <- subset(predictions, file == "5year.arff" & sample == "Development cross-fitted")$row_id
x <- apply_preprocess(d[dev_idx, ], fit_preprocess(d[dev_idx, ]))[, FEATURES]
correlations <- read_table("development-predictor-correlations")
stopifnot(identical(correlations$feature, FEATURES),
          max(abs(as.matrix(correlations[, -1]) - cor(x))) < 1e-12)
vif <- read_table("development-collinearity-diagnostics")
for (j in seq_along(FEATURES)) {
  fit <- lm(x[, j] ~ x[, -j])
  value <- 1 / (1 - summary(fit)$r.squared)
  stopifnot(vif$feature[j] == FEATURES[j], vif$n[j] == nrow(x),
            abs(vif$vif[j] - value) < 1e-10)
}
bands <- read_table("holdout-risk-bands")
boundaries <- read_table("development-risk-band-boundaries")$threshold
test <- subset(predictions, file == "5year.arff" & sample == "Holdout")
label <- cut(test$logistic_risk, c(-Inf, boundaries, Inf), right = FALSE, labels = c("Low", "Moderate", "High"))
for (b in 1:3) {
  idx <- label == bands$band[b]
  stopifnot(sum(idx) == bands$n[b],
    abs(mean(test$outcome[idx]) - bands$observed_bankruptcy_rate[b]) < 1e-12,
    abs(mean(test$logistic_risk[idx]) - bands$average_predicted_risk[b]) < 1e-12)
}
cv <- read_table("cross-validation-fold-results")
stopifnot(nrow(cv) == 100, all(table(cv$horizon_years, cv$model) == 10))
figures <- list.files("outputs/figures", pattern = "[.]png$", full.names = TRUE)
stopifnot(length(figures) == 11, all(file.info(figures)$size > 10000))
message("Passed: all five datasets, split isolation, data diagnostics, holdout metrics, policies, risk bands and figure presence.")
