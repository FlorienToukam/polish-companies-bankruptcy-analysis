# Shared data preparation, validation and evaluation functions
SEED <- 5442026L
MODEL_NAMES <- c("Ridge logistic", "Balanced random forest")
FEATURES <- paste0("Attr", c(1, 2, 3, 4, 6, 9, 13, 20, 21, 25, 26, 29, 40, 44, 60, 61))
LABELS <- c("Net profit / assets", "Liabilities / assets", "Working capital / assets",
            "Current assets / short-term liabilities", "Retained earnings / assets",
            "Sales / assets", "Gross profit plus depreciation / sales", "Inventory days",
            "Sales growth ratio", "Equity less share capital / assets",
            "Net profit plus depreciation / liabilities", "Log total assets",
            "Cash-like current assets / short-term liabilities", "Receivables days",
            "Sales / inventory", "Sales / receivables")
names(LABELS) <- FEATURES
save_table <- function(x, name) write.csv(x, file.path("outputs/tables", paste0(name, ".csv")), row.names = FALSE, na = "")
clip <- function(p) pmin(pmax(p, 1e-6), 1 - 1e-6)
read_credit <- function(i) {
  path <- file.path("polish+companies+bankruptcy+data", paste0(i, "year.arff"))
  lines <- readLines(path, warn = FALSE)
  start <- grep("^@data", lines, ignore.case = TRUE)
  stopifnot(length(start) == 1)
  d <- read.csv(text = paste(lines[(start + 1):length(lines)], collapse = "\n"),
                header = FALSE, na.strings = "?", col.names = c(paste0("Attr", 1:64), "class"))
  stopifnot(ncol(d) == 65, all(d$class %in% 0:1), !anyNA(d$class))
  d
}
group_keys <- function(d) {
  # Keep identical financial statements together even when their labels disagree.
  key <- apply(d[paste0("Attr", 1:64)], 1, function(x) paste(sprintf("%.17g", x), collapse = "|"))
  match(key, unique(key))
}
group_folds <- function(y, group, k, seed) {
  set.seed(seed)
  ids <- unique(group)
  strata <- vapply(ids, function(g) max(y[group == g]), numeric(1))
  assigned <- setNames(integer(length(ids)), ids)
  for (s in 0:1) {
    v <- sample(ids[strata == s])
    assigned[as.character(v)] <- rep(seq_len(k), length.out = length(v))
  }
  as.integer(assigned[as.character(group)])
}
holdout_ids <- function(y, group, seed) {
  set.seed(seed)
  ids <- unique(group)
  strata <- vapply(ids, function(g) max(y[group == g]), numeric(1))
  selected <- unlist(lapply(0:1, function(s) sample(ids[strata == s], round(sum(strata == s) * .2))))
  which(group %in% selected)
}
fit_preprocess <- function(d) {
  x <- as.matrix(d[FEATURES]); x[!is.finite(x)] <- NA
  med <- apply(x, 2, median, na.rm = TRUE)
  bounds <- apply(x, 2, quantile, c(.01, .99), na.rm = TRUE, names = FALSE)
  stopifnot(all(is.finite(med)), all(is.finite(bounds)))
  list(median = med, lower = bounds[1, ], upper = bounds[2, ])
}
apply_preprocess <- function(d, prep) {
  x <- as.matrix(d[FEATURES]); x[!is.finite(x)] <- NA
  flags <- 1L * is.na(x)
  for (j in seq_len(ncol(x))) {
    x[is.na(x[, j]), j] <- prep$median[j]
    x[, j] <- pmin(pmax(x[, j], prep$lower[j]), prep$upper[j])
  }
  colnames(flags) <- paste0(FEATURES, "_missing")
  cbind(x, flags)
}
fit_models <- function(d, seed) {
  prep <- fit_preprocess(d); x <- apply_preprocess(d, prep)
  # Fixed specifications avoid selecting hyperparameters on evaluation data.
  # A decreasing penalty path provides stable warm starts; evaluation uses lambda 0.01.
  lr <- glmnet::glmnet(x, d$class, family = "binomial", alpha = 0,
                       lambda = exp(seq(log(1), log(.01), length.out = 50)),
                       standardize = TRUE, thresh = 1e-7, maxit = 1000000)
  stopifnot(lr$jerr == 0, min(lr$lambda) <= .01000001)
  y <- factor(d$class, levels = 0:1)
  set.seed(seed)
  rf <- randomForest::randomForest(x, y, ntree = 500, mtry = floor(sqrt(ncol(x))),
                                  nodesize = 5, strata = y, sampsize = rep(min(table(y)), 2))
  list(prep = prep, lr = lr, rf = rf)
}
raw_predict <- function(fit, d) {
  x <- apply_preprocess(d, fit$prep)
  p <- cbind(as.numeric(predict(fit$lr, x, type = "response", s = .01)),
             predict(fit$rf, x, type = "prob")[, "1"])
  colnames(p) <- MODEL_NAMES
  p
}
fit_calibrators <- function(y, p) {
  # Platt calibration uses out-of-fold predictions at the natural event prevalence.
  lapply(seq_len(ncol(p)), function(j) {
    z <- qlogis(clip(p[, j]))
    fit <- glm(y ~ z, family = binomial())
    stopifnot(fit$converged, all(is.finite(coef(fit))), coef(fit)[2] > 0)
    fit
  })
}
calibrate <- function(fits, p) {
  out <- vapply(seq_len(ncol(p)), function(j) {
    predict(fits[[j]], newdata = data.frame(z = qlogis(clip(p[, j]))), type = "response")
  }, numeric(nrow(p)))
  colnames(out) <- MODEL_NAMES
  # Preserve genuine score ties and reproducible metrics after CSV round-tripping.
  round(out, 12)
}
inner_calibration <- function(d, group, seed) {
  folds <- group_folds(d$class, group, 3, seed)
  p <- matrix(NA_real_, nrow(d), 2)
  for (f in 1:3) {
    fit <- fit_models(d[folds != f, ], seed + f)
    p[folds == f, ] <- raw_predict(fit, d[folds == f, ])
  }
  fit_calibrators(d$class, p)
}
average_precision <- function(y, p) {
  # Integrate a step precision-recall curve, combining equal scores before scoring.
  o <- order(p, decreasing = TRUE); yy <- y[o]; pp <- p[o]
  end <- c(which(diff(pp) != 0), length(pp))
  tp <- cumsum(yy)[end]; recall <- tp / sum(yy)
  sum(diff(c(0, recall)) * tp / end)
}
metrics <- function(y, p, threshold) {
  pred <- p >= threshold
  tp <- sum(pred & y == 1); fp <- sum(pred & y == 0)
  fn <- sum(!pred & y == 1); tn <- sum(!pred & y == 0)
  precision <- if ((tp + fp) > 0) tp / (tp + fp) else 0
  recall <- tp / (tp + fn); specificity <- tn / (tn + fp)
  data.frame(n = length(y), bankruptcies = sum(y), threshold = threshold,
    roc_auc = as.numeric(pROC::auc(pROC::roc(y, p, levels = 0:1, direction = "<", quiet = TRUE))),
    average_precision = average_precision(y, p), recall = recall, specificity = specificity,
    precision = precision, accuracy = (tp + tn) / length(y),
    balanced_accuracy = (recall + specificity) / 2,
    f1 = if ((precision + recall) > 0) 2 * precision * recall / (precision + recall) else 0,
    brier = mean((p - y)^2), review_rate = mean(pred), tp = tp, fp = fp, fn = fn, tn = tn)
}
capacity_threshold <- function(p, capacity) {
  # Choose a boundary between scores that does not exceed the development review budget.
  unique_scores <- sort(unique(p))
  candidates <- c(0, head(unique_scores, -1) + diff(unique_scores) / 2, 1)
  rate <- vapply(candidates, function(t) mean(p >= t), numeric(1))
  candidates[which(rate <= capacity + 1e-12)[1]]
}
risk_bands <- function(p, edges) cut(p, c(-Inf, edges, Inf), labels = c("Low", "Moderate", "High"), right = FALSE)
band_summary <- function(y, p, edges) {
  b <- risk_bands(p, edges)
  do.call(rbind, lapply(levels(b), function(s) data.frame(band = s, n = sum(b == s),
    average_predicted_risk = mean(p[b == s]), observed_bankruptcy_rate = mean(y[b == s]))))
}
curve_points <- function(y, p) {
  o <- order(p, decreasing = TRUE); yy <- y[o]; pp <- p[o]
  end <- c(which(diff(pp) != 0), length(pp))
  tp <- cumsum(yy)[end]; fp <- end - tp
  data.frame(review_fraction = end / length(y), recall = tp / sum(y),
             precision = tp / end, false_positive_rate = fp / sum(y == 0))
}
bootstrap_metrics <- function(y, group, probabilities, thresholds, seed, B = 500) {
  set.seed(seed)
  ids <- unique(group); stratum <- vapply(ids, function(g) max(y[group == g]), numeric(1))
  rows <- split(seq_along(y), group)
  ans <- vector("list", B)
  for (b in seq_len(B)) {
    selected <- unlist(lapply(0:1, function(s) sample(ids[stratum == s], sum(stratum == s), replace = TRUE)))
    idx <- unlist(rows[as.character(selected)], use.names = FALSE)
    ans[[b]] <- do.call(rbind, lapply(1:2, function(j) cbind(iteration = b, model = MODEL_NAMES[j],
      metrics(y[idx], probabilities[idx, j], thresholds[j]))))
  }
  do.call(rbind, ans)
}
