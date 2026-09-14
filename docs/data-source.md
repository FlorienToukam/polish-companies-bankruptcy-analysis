# Polish Companies Bankruptcy data

Source: Tomczak, S. (2016). *Polish Companies Bankruptcy*. UCI Machine Learning Repository. DOI: [10.24432/C5F600](https://doi.org/10.24432/C5F600).

The five ARFF files are included unchanged in `polish+companies+bankruptcy+data/`, using UCI's filenames. The dataset is distributed by UCI under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Attribution applies to these data; it does not assign a license to other project content.

Each record contains 64 financial predictors and an outcome coded 1 for bankruptcy, 0 otherwise. `?` represents a missing value. Model transformations are generated in memory; raw files are not rewritten. The file checksums in `data-checksums.csv` identify the exact inputs.

| File | Prediction horizon | Records | Bankruptcies |
|---|---:|---:|---:|
| 1year.arff | 5 years | 7,027 | 271 |
| 2year.arff | 4 years | 10,173 | 400 |
| 3year.arff | 3 years | 10,503 | 495 |
| 4year.arff | 2 years | 9,792 | 515 |
| 5year.arff | 1 year | 5,910 | 410 |

The source describes bankrupt companies observed during 2000–2012 and operating companies during 2007–2013, using financial information from EMIS. The files do not provide firm identifiers or observation dates. They are analyzed separately; no pooled independent-firm or longitudinal interpretation is assumed. Some ARFF relation headers are inconsistent with the filenames, so the horizon mapping follows UCI's documented file descriptions.

The full 64-variable definitions are available on the [UCI dataset page](https://archive.ics.uci.edu/dataset/365/polish+companies+bankruptcy+data). The selected model inputs are listed in [the model feature dictionary](../outputs/tables/model-feature-dictionary.csv). Source labels for some unselected ratios, including the EBITDA descriptions, are ambiguous; those fields are not used to make accounting interpretations in this analysis.
