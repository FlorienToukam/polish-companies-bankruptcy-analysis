# Bankruptcy risk methodology

## Data and scope

The five ARFF files contain the Polish Companies Bankruptcy data as distributed by UCI. Each contains 64 financial predictors and an outcome coded 1 for bankruptcy and 0 for non-bankruptcy. Missing values are marked `?`.

The source mapping is important: `1year.arff` predicts bankruptcy after five years, and `5year.arff` predicts bankruptcy after one year. The primary evaluation uses `5year.arff`; the other four files are modeled separately with the same protocol. These are separate classification samples, not a joined longitudinal panel. Company identifiers and calendar dates are unavailable. Exact duplicate predictor rows can be kept together, but repeated firms with different statements cannot be identified.

## Data quality and sample inclusion

The data inventory records sample size, bankruptcy prevalence, missing values and exact duplicate predictor groups for each forecasting horizon. A complete-case diagnostic compares the fraction of bankrupt and non-bankrupt development records that would be excluded when requiring finite values in all 64 ratios or in the selected 16 model ratios. This quantifies the effect of sample exclusion without applying that exclusion to model fitting. Imputation and missing indicators retain every observation.

For the one-year development sample, a Pearson correlation matrix and variance inflation factors describe dependence among the 16 model ratios after development-median imputation and percentile clipping. Each VIF is 1/(1-R-squared), where that ratio is regressed on the other 15 ratios. These diagnostics do not rank predictors against bankruptcy labels or select a different feature set. Ridge regularization addresses correlated inputs, while individual coefficients remain conditional associations. The correlation and VIF diagnostics exclude the holdout and do not change the model specifications.

## Development and holdout separation

Within each file, exact matches on all 64 raw predictors form a group, irrespective of outcome. Groups are stratified by whether they contain a bankruptcy. Approximately 20% of each group stratum is held out; the remaining observations form the development sample. This preserves every raw observation and prevents exact duplicate statements from crossing a split. Because groups can contain multiple records, observation-level proportions need not be exactly 80/20.

All preprocessing, calibration, thresholds and risk-band boundaries are estimated using development data. The holdout is used for final evaluation and descriptive sensitivity analysis only. There is no holdout-based feature or hyperparameter search. This is a randomly partitioned, duplicate-grouped record-level evaluation, not a time-based or fully firm-grouped validation.

## Predictor design and preprocessing

Both models use the same 16 finance-defined ratios: Attr1, Attr2, Attr3, Attr4, Attr6, Attr9, Attr13, Attr20, Attr21, Attr25, Attr26, Attr29, Attr40, Attr44, Attr60 and Attr61. They cover profitability, leverage, liquidity, capital accumulation, scale, growth and working-capital efficiency. This fixed set was defined before model evaluation, without outcome-based feature selection. The feature dictionary provides the financial descriptions.

Within each model-training sample, non-finite inputs are treated as missing. Each ratio receives a missing-value indicator and training-median imputation. Ratios are clipped at their training 1st and 99th percentiles. The resulting 32-column design is passed to both models. Constant columns are handled by the fitting routines. No rows are discarded. The same fitted transformations are applied to validation or holdout observations. Clipping limits numerical influence; it does not establish that tail observations are data errors.

## Model specifications

Ridge logistic regression uses `glmnet`, a binomial outcome, alpha 0, standardized inputs and a fixed lambda of 0.01. A decreasing 50-value penalty path from 1 to 0.01 provides warm starts; this is a numerical fitting path, not a hyperparameter selection exercise. The convergence tolerance is 1e-7 and the maximum iteration count is 1,000,000. The code checks convergence before predictions are accepted.

The challenger uses `randomForest`, 500 trees, mtry 5 and minimum terminal-node size 5. Each tree draws equally sized bootstrap samples from the two outcome classes, with the sample size per class set by the minority count in its training sample. The choice provides a nonlinear comparison without a large tuning search. The comparison uses the same inputs and splits as logistic regression.

## Cross-validation and probability calibration

Development uses two repeats of grouped, stratified five-fold cross-validation. In each outer fold, an inner grouped three-fold procedure produces out-of-fold predictions from the outer training observations. Separate Platt calibrators are fitted to each model's logit score using those inner predictions at the natural training event prevalence. The base models are then fitted to the full outer training sample, and their scores for the outer validation fold are transformed by those calibrators. Thus neither the base model nor its calibrator sees the outer validation outcomes while being fitted.

Each development observation receives two calibrated validation scores, averaged to one score for policy design. The final calibrators are fitted on the averaged raw outer out-of-fold scores across development. Final base models are fitted to all development observations. The resulting fitted models, transformations and calibrators are then applied to holdout observations. Calibration fit quality is assessed by Brier score and development-defined score bins on the holdout; no claim of perfect calibration is made. Balanced-forest votes are not treated directly as bankruptcy probabilities.

Cross-validation tables report each fold's discrimination, average precision, Brier score and metrics at 0.50. Policy-development tables instead use the selected model-specific thresholds. The threshold-dependent development results are policy-selection summaries, not an independent estimate of a newly selected policy. Holdout results provide that separate evaluation. Mean cross-validation AUCs summarize ten correlated folds; their dispersion is not a confidence interval.

## Screening threshold and risk bands

The primary screening design assumes capacity to review 20% of development observations. For each model, a threshold between adjacent cross-fitted scores admits the largest feasible group without exceeding this budget. Ties are kept together. These thresholds are fixed before holdout scoring. Actual holdout review volumes can differ from 20% because score distributions vary and final models use more training data. This is a review prioritization rule, not an automatic approval or rejection policy.

Logistic risk bands use analogous development boundaries: Low covers approximately the lower 50% of development scores, Moderate the next 30%, and High the upper 20%. Holdout band counts, mean calibrated scores and observed bankruptcy rates are reported without changing those boundaries. The categories are relative to this dataset; they are not rating-agency grades.

Capacity sensitivity considers development budgets from 5% to 30%. Illustrative cost sensitivity weights each missed bankruptcy by 5, 10 or 20 false-positive units. These are assumptions, not measured monetary losses, and do not change the primary 20% policy. True loss optimization would require exposure, recovery, intervention effectiveness and review-cost data.

## Performance metrics and uncertainty

Bankruptcy is the positive class throughout. Predictions at or above a threshold trigger review. Recall is TP/(TP+FN); specificity is TN/(TN+FP); precision is TP/(TP+FP); accuracy is (TP+TN)/N. Precision is defined as zero if no observations are flagged. Balanced accuracy averages recall and specificity, and F1 is the harmonic mean of recall and precision. Brier score is the mean squared probability error. ROC AUC measures discrimination. Average precision integrates a step precision-recall curve after combining equal scores. It is not trapezoidal PR AUC.

Primary holdout confidence intervals use 500 stratified bootstrap samples of exact-predictor groups with replacement, seed 5442125. Both models are evaluated on the same resampled groups. Percentile intervals are conditional on the fitted models and split; they do not include training uncertainty or unidentified within-firm dependence. The paired ROC-AUC difference is forest minus logistic.

Lift and capture summarize the top 10% and 20% of holdout scores by rank. Boundary ties are included, and actual review fractions are reported. These are descriptive ranking diagnostics, distinct from applying the fixed development screening threshold.

## Financial interpretation and sensitivity

Ridge coefficients are expressed as odds ratios for a one-interquartile-range increase in each ratio, using the imputed and clipped development distribution. The final Platt slope is included in the odds-ratio calculation. These conditional model associations are not causal effects or significance tests. The share of outer fits with positive coefficients is reported as a simple direction-stability check, not a probability or p-value.

Sensitivity analysis shifts one ratio by plus or minus half its development interquartile range while holding other inputs unchanged. Values remain within the training clipping bounds and missing inputs remain missing. It shows how fitted scores and review counts respond to isolated input changes. Because the data do not include underlying financial statements, these perturbations do not enforce accounting identities and are not a coherent balance-sheet or macroeconomic stress test.

## Reproducibility and sources

Base seed 5442026 is combined with the file number, repetition and fold as specified in the scripts. Calibrated scores are rounded to 12 decimal places so genuine score ties and metric calculations remain stable after CSV export. Data files are verified using SHA-256 checksums. Package versions and the R session are recorded. `final_project.R` runs the diagnostics, model validation and figures; `scripts/build_reports.py` regenerates the written outputs from the saved tables. The validation test checks metrics, split membership and diagnostics independently. All analysis inputs are included in this repository; the execution cache is generated by the pipeline and is not required to start a run.

- [UCI dataset and variable definitions](https://archive.ics.uci.edu/dataset/365/polish+companies+bankruptcy+data)
- [Dataset DOI](https://doi.org/10.24432/C5F600)
- [glmnet documentation](https://glmnet.stanford.edu/articles/glmnet.html)
- [randomForest documentation](https://search.r-project.org/CRAN/refmans/randomForest/html/randomForest.html)
