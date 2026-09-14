# Polish Companies Bankruptcy Analysis
# Run from the project directory with Rscript final_project.R.
options(stringsAsFactors = FALSE, warn = 1)
required <- c("glmnet", "randomForest", "pROC", "jsonlite")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages: ", paste(missing, collapse = ", "))
if (!file.exists("R/00_functions.R")) stop("Run from the project directory.")
dir.create(".cache", showWarnings = FALSE)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
source("R/00_functions.R")
source("R/01_data_preparation_and_diagnostics.R")
source("R/02_model_validation.R")
source("R/03_visual_summaries.R")
writeLines(capture.output(sessionInfo()), "docs/session-info.txt")
message("Analysis complete. Tables and figures are in outputs/.")
