# Development-only preprocessing and calibration, followed by a fixed holdout evaluation.
data_inventory <- list(); missing_inventory <- list(); horizon_results <- list(); cv_results <- list()
split_inventory <- list(); policies <- list(); all_predictions <- list(); model_objects <- list()
for (i in 1:5) {
  message("Validating ", 6 - i, "-year horizon (", i, "year.arff)")
  d <- read_credit(i); groups <- group_keys(d)
  data_inventory[[i]] <- data.frame(file = paste0(i, "year.arff"), horizon_years = 6 - i,
    observations = nrow(d), predictors = 64, bankruptcies = sum(d$class),
    bankruptcy_rate = mean(d$class), exact_predictor_groups = length(unique(groups)),
    duplicate_excess = nrow(d) - length(unique(groups)),
    missing_values = sum(is.na(d)), missing_outcomes = sum(is.na(d$class)))
  missing_inventory[[i]] <- data.frame(file = paste0(i, "year.arff"), feature = names(d)[1:64],
    missing_n = colSums(is.na(d[1:64])), missing_rate = colMeans(is.na(d[1:64])))
  test_idx <- holdout_ids(d$class, groups, SEED + i)
  dev_idx <- setdiff(seq_len(nrow(d)), test_idx)
  dev <- d[dev_idx, ]; test <- d[test_idx, ]; dg <- groups[dev_idx]
  stopifnot(!length(intersect(dg, groups[test_idx])))
  split_inventory[[i]] <- rbind(
    data.frame(file = paste0(i, "year.arff"), sample = "Development", n = nrow(dev), bankruptcies = sum(dev$class)),
    data.frame(file = paste0(i, "year.arff"), sample = "Holdout", n = nrow(test), bankruptcies = sum(test$class)))
  cv_p <- raw_p <- array(NA_real_, c(nrow(dev), 2, 2))
  fold_tables <- list(); cv_coefficients <- list()
  for (r in 1:2) {
    folds <- group_folds(dev$class, dg, 5, SEED + i * 100 + r)
    for (f in 1:5) {
      seed <- SEED + i * 1000 + r * 100 + f * 10
      tr <- which(folds != f); va <- which(folds == f)
      stopifnot(!length(intersect(dg[tr], dg[va])))
      cal <- inner_calibration(dev[tr, ], dg[tr], seed)
      fit <- fit_models(dev[tr, ], seed + 7)
      raw_p[va, , r] <- raw_predict(fit, dev[va, ])
      cv_p[va, , r] <- calibrate(cal, raw_p[va, , r])
      fold_tables[[length(fold_tables) + 1]] <- do.call(rbind, lapply(1:2, function(j) {
        cbind(horizon_years = 6 - i, repetition = r, fold = f, model = MODEL_NAMES[j],
              metrics(dev$class[va], cv_p[va, j, r], .5))
      }))
      cv_coefficients[[length(cv_coefficients) + 1]] <- as.numeric(coef(fit$lr, s = .01))[-1]
      message("  repeat ", r, ", fold ", f, " complete")
    }
  }
  stopifnot(all(is.finite(cv_p)))
  # One mean cross-fitted score per development observation; no holdout outcomes enter policies.
  dev_p <- apply(cv_p, c(1, 2), mean)
  dev_raw <- apply(raw_p, c(1, 2), mean)
  thresholds <- vapply(1:2, function(j) capacity_threshold(dev_p[, j], .2), numeric(1))
  edges <- c(capacity_threshold(dev_p[, 1], .5), thresholds[1])
  cal_final <- fit_calibrators(dev$class, dev_raw)
  fit_final <- fit_models(dev, SEED + i * 10000)
  test_raw <- raw_predict(fit_final, test)
  test_p <- calibrate(cal_final, test_raw)
  colnames(dev_p) <- colnames(dev_raw) <- MODEL_NAMES
  policies[[i]] <- do.call(rbind, lapply(1:2, function(j) data.frame(horizon_years = 6 - i,
    model = MODEL_NAMES[j], development_capacity = .2, threshold = thresholds[j],
    development_review_rate = mean(dev_p[, j] >= thresholds[j]),
    platt_intercept = coef(cal_final[[j]])[1], platt_slope = coef(cal_final[[j]])[2])))
  horizon_results[[i]] <- do.call(rbind, lapply(1:2, function(j)
    cbind(horizon_years = 6 - i, file = paste0(i, "year.arff"), model = MODEL_NAMES[j],
           metrics(test$class, test_p[, j], thresholds[j]))))
  cv_results[[i]] <- do.call(rbind, fold_tables)
  all_predictions[[i]] <- rbind(
    data.frame(file = paste0(i, "year.arff"), row_id = dev_idx, predictor_group = dg, sample = "Development cross-fitted", outcome = dev$class,
                logistic_risk = dev_p[, 1], forest_risk = dev_p[, 2]),
    data.frame(file = paste0(i, "year.arff"), row_id = test_idx, predictor_group = groups[test_idx], sample = "Holdout", outcome = test$class,
                logistic_risk = test_p[, 1], forest_risk = test_p[, 2]))
  model_objects[[i]] <- list(fit = fit_final, calibrators = cal_final, thresholds = thresholds)
  if (i == 5) {
    primary <- list(dev = dev, test = test, dev_groups = dg, test_groups = groups[test_idx],
      dev_p = dev_p, test_p = test_p, test_raw = test_raw, thresholds = thresholds, edges = edges,
      fit = fit_final, calibrators = cal_final, coefficients = do.call(cbind, cv_coefficients))
  }
}
save_table(do.call(rbind, data_inventory), "data-inventory")
save_table(do.call(rbind, missing_inventory), "missing-data-profile")
save_table(do.call(rbind, split_inventory), "development-holdout-samples")
save_table(do.call(rbind, policies), "development-screening-policies")
save_table(do.call(rbind, horizon_results), "horizon-holdout-performance")
save_table(do.call(rbind, cv_results), "cross-validation-fold-results")
save_table(do.call(rbind, all_predictions), "out-of-sample-predictions")
save_table(data.frame(feature = FEATURES, description = unname(LABELS)), "model-feature-dictionary")

dev <- primary$dev; test <- primary$test; dev_p <- primary$dev_p; test_p <- primary$test_p
thresholds <- primary$thresholds; edges <- primary$edges
save_table(band_summary(test$class, test_p[, 1], edges), "holdout-risk-bands")
save_table(data.frame(boundary = c("Low to moderate", "Moderate to high"), threshold = edges,
                     development_quantile = c(.5, .8)), "development-risk-band-boundaries")
threshold_analysis <- do.call(rbind, lapply(1:2, function(j) do.call(rbind, lapply(c(.05, .1, .15, .2, .25, .3), function(capacity) {
  t <- capacity_threshold(dev_p[, j], capacity)
  cbind(model = MODEL_NAMES[j], capacity = capacity,
        metrics(dev$class, dev_p[, j], t))
}))))
save_table(threshold_analysis, "development-capacity-analysis")
grid <- sort(unique(c(seq(.01, .5, .01), thresholds)))
cost_analysis <- do.call(rbind, lapply(1:2, function(j) do.call(rbind, lapply(grid, function(t) {
  m <- metrics(dev$class, dev_p[, j], t)
  do.call(rbind, lapply(c(5, 10, 20), function(cost) data.frame(model = MODEL_NAMES[j],
    threshold = t, missed_bankruptcy_cost_relative_to_false_positive = cost,
    illustrative_cost_per_observation = (m$fn * cost + m$fp) / nrow(dev), recall = m$recall, review_rate = m$review_rate)))
}))))
save_table(cost_analysis, "development-illustrative-cost-sensitivity")
lift_table <- do.call(rbind, lapply(1:2, function(j) do.call(rbind, lapply(c(.1, .2), function(fraction) {
  n <- ceiling(fraction * nrow(test)); sorted <- sort(test_p[, j], decreasing = TRUE)
  # Include boundary ties and report actual review volume rather than arbitrary tie-breaking.
  selected <- test_p[, j] >= sorted[n]
  data.frame(model = MODEL_NAMES[j], target_top_fraction = fraction, selected_n = sum(selected),
    actual_review_fraction = mean(selected), bankruptcies_captured = sum(test$class[selected]),
    capture_rate = sum(test$class[selected]) / sum(test$class),
    precision = mean(test$class[selected]), lift = mean(test$class[selected]) / mean(test$class))
}))))
save_table(lift_table, "holdout-lift-and-capture")
curve_table <- do.call(rbind, lapply(1:2, function(j) cbind(model = MODEL_NAMES[j], curve_points(test$class, test_p[, j]))))
save_table(curve_table, "holdout-ranking-curves")
cal_table <- do.call(rbind, lapply(1:2, function(j) {
  breaks <- unique(quantile(dev_p[, j], seq(0, 1, .2)))
  breaks[1] <- -Inf; breaks[length(breaks)] <- Inf
  bin <- cut(test_p[, j], breaks, include.lowest = TRUE)
  do.call(rbind, lapply(levels(bin), function(b) data.frame(model = MODEL_NAMES[j],
    development_score_interval = b, n = sum(bin == b),
    mean_predicted_risk = mean(test_p[bin == b, j]), observed_rate = mean(test$class[bin == b]))))
}))
save_table(cal_table, "holdout-calibration-bins")
cal_scores <- do.call(rbind, lapply(1:2, function(j) data.frame(model = MODEL_NAMES[j],
  raw_brier = mean((primary$test_raw[, j] - test$class)^2),
  calibrated_brier = mean((test_p[, j] - test$class)^2),
  development_prevalence_baseline_brier = mean((mean(dev$class) - test$class)^2))))
save_table(cal_scores, "holdout-calibration-scores")
boot <- bootstrap_metrics(test$class, primary$test_groups, test_p, thresholds, SEED + 99)
intervals <- do.call(rbind, lapply(MODEL_NAMES, function(model) do.call(rbind, lapply(
  c("roc_auc", "average_precision", "recall", "specificity", "precision", "accuracy", "brier"), function(metric) {
    v <- boot[boot$model == model, metric]
    data.frame(model = model, metric = metric, lower_95 = quantile(v, .025), upper_95 = quantile(v, .975))
  })) ))
save_table(intervals, "holdout-metric-confidence-intervals")
delta <- boot$roc_auc[boot$model == MODEL_NAMES[2]] - boot$roc_auc[boot$model == MODEL_NAMES[1]]
save_table(data.frame(comparison = "Forest minus logistic ROC AUC", estimate = horizon_results[[5]]$roc_auc[2] - horizon_results[[5]]$roc_auc[1],
                     lower_95 = quantile(delta, .025), upper_95 = quantile(delta, .975)), "paired-holdout-auc-difference")

# Coefficients describe conditional model associations, not causal effects.
beta <- as.numeric(coef(primary$fit$lr, s = .01))[-1]
features <- colnames(apply_preprocess(dev, primary$fit$prep))
iqr <- apply(apply_preprocess(dev, primary$fit$prep), 2, IQR)
drivers <- data.frame(feature = features[1:16], description = unname(LABELS),
  coefficient = beta[1:16], development_iqr = iqr[1:16],
  calibrated_odds_ratio_per_iqr = exp(beta[1:16] * iqr[1:16] * coef(primary$calibrators[[1]])[2]),
  cv_positive_fraction = rowMeans(primary$coefficients[1:16, ] > 0))
drivers <- drivers[order(-abs(log(drivers$calibrated_odds_ratio_per_iqr))), ]
save_table(drivers, "logistic-risk-drivers")
save_table(data.frame(feature = features, coefficient = beta), "regularized-logistic-coefficients")

# Change one reported ratio at a time to measure model sensitivity within development support.
scenario_features <- c("Attr1", "Attr2", "Attr4", "Attr21")
scenarios <- do.call(rbind, lapply(scenario_features, function(v) do.call(rbind, lapply(c(-.5, .5), function(change) {
  altered <- test; shift <- IQR(dev[[v]], na.rm = TRUE) * change
  altered[[v]] <- pmin(pmax(altered[[v]] + shift, primary$fit$prep$lower[v]), primary$fit$prep$upper[v])
  pp <- calibrate(primary$calibrators, raw_predict(primary$fit, altered))
  do.call(rbind, lapply(1:2, function(j) data.frame(feature = v, description = LABELS[v],
    iqr_shift = change, raw_ratio_shift = shift, model = MODEL_NAMES[j],
    baseline_mean_risk = mean(test_p[, j]), scenario_mean_risk = mean(pp[, j]),
    mean_risk_change = mean(pp[, j] - test_p[, j]),
    baseline_review_n = sum(test_p[, j] >= thresholds[j]), scenario_review_n = sum(pp[, j] >= thresholds[j]))))
}))))
save_table(scenarios, "financial-ratio-sensitivity")
saveRDS(list(primary = primary, models = model_objects, results = horizon_results),
        ".cache/analysis-results.rds")
save_table(data.frame(package = c("R", "glmnet", "randomForest", "pROC", "jsonlite"),
  version = c(as.character(getRversion()), vapply(c("glmnet", "randomForest", "pROC", "jsonlite"), function(p) as.character(packageVersion(p)), character(1)))), "software-versions")
