# Sample inclusion and predictor dependence within development data.
message("Checking data quality and predictor dependence")
selection <- list()
for (i in 1:5) {
  d <- read_credit(i)
  groups <- group_keys(d)
  holdout <- holdout_ids(d$class, groups, SEED + i)
  development <- d[-holdout, ]
  feature_sets <- list("All 64 ratios" = paste0("Attr", 1:64), "Model 16 ratios" = FEATURES)
  for (specification in names(feature_sets)) {
    x <- as.matrix(development[feature_sets[[specification]]])
    complete <- rowSums(!is.finite(x)) == 0
    for (outcome in 0:1) {
      rows <- development$class == outcome
      selection[[length(selection) + 1]] <- data.frame(
        file = paste0(i, "year.arff"), horizon_years = 6 - i, sample = "Development",
        feature_set = specification, outcome = c("Non-bankrupt", "Bankrupt")[outcome + 1],
        n = sum(rows), retained_n = sum(rows & complete), removed_n = sum(rows & !complete),
        removed_fraction = mean(!complete[rows]))
    }
  }
}
save_table(do.call(rbind, selection), "complete-case-selection-diagnostic")

# Examine the same imputed, clipped ratios supplied to the one-year models.
d <- read_credit(5)
groups <- group_keys(d)
development <- d[-holdout_ids(d$class, groups, SEED + 5), ]
x <- as.data.frame(apply_preprocess(development, fit_preprocess(development))[, FEATURES])
correlations <- cor(x)
save_table(cbind(feature = rownames(correlations), as.data.frame(correlations)),
           "development-predictor-correlations")
vif <- vapply(FEATURES, function(v) {
  r_squared <- summary(lm(reformulate(setdiff(FEATURES, v), v), data = x))$r.squared
  1 / (1 - r_squared)
}, numeric(1))
save_table(data.frame(feature = FEATURES, description = unname(LABELS),
                     sample = "One-year development", n = nrow(x), vif = vif),
           "development-collinearity-diagnostics")
