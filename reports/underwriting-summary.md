# Bankruptcy Risk Executive Summary

Florien Siakoua Toukam

Objective and scope. Prioritize financial review using 5,910 one-year-ahead records, including 410 bankruptcies. Development and holdout are separated by exact predictor groups; model fitting and calibration use nested, repeated cross-validation within development.

| Holdout metric | Ridge logistic | Balanced forest |
| --- | --- | --- |
| ROC AUC | 0.847 | 0.868 |
| Average precision | 0.580 | 0.477 |
| Bankruptcy recall | 75.9% | 77.1% |
| Specificity | 83.8% | 85.6% |
| Precision | 26.1% | 28.8% |

Screening. At thresholds of 6.65% and 9.35%, logistic regression flags 241 records, misses 20 bankruptcies and generates 178 false positives. The forest flags 222, misses 19 and generates 158 false positives. Thresholds implement a development review budget of 20%, not automatic credit decisions.

Risk segmentation. Low / Moderate / High bands contain 586 / 357 / 241 records. Their observed bankruptcy rates are 1.9% / 2.5% / 26.1%.

Financial interpretation. Lower sales growth, weaker working capital, smaller asset scale and lower profitability are associated with higher estimated odds; higher liabilities relative to assets also increase estimated odds, conditional on the other inputs.

Model judgment. Keep logistic regression as the interpretable reference and the forest as challenger. The forest's AUC advantage has a 95% interval of -0.013 to 0.054; logistic regression has higher average precision and lower calibrated Brier error. Mean cross-validation AUCs are 0.864 / 0.877.

Limitations. Historical selected data and missing firm IDs, observation dates and loss information limit transfer to current credit decisions. Exact duplicate grouping cannot identify repeated firms with different statements. Risk scores and bands are relative to this dataset; current use would require dated external validation and measured review costs.
