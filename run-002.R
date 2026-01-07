library(rmarkdown)


path <- "/data/Donahue-Lab/scRNAseq/MeganL/sequencing-data/VB_003_%s/outs/per_sample_outs/VB_003_%s/count/sample_filtered_feature_bc_matrix"
html_suffix <- "_SCTransform.html"


# sprintf - looks for %s in your path to replace with the provided text arguments below
# paste0 - simple concatenation of strings
# e.g. paste0("V05", html_suffix) would print "V05_SCTransform.html"


## edit runs list
runs <- list(
  list(input = sprintf(path, 'P5', 'P5'), html_out = paste0("V05", html_suffix), rds_out = "V05.rds"),
  list(input = sprintf(path, 'P6', 'P6'), html_out = paste0("V06", html_suffix), rds_out = "V06.rds" ),
  list(input = sprintf(path, 'P7', 'P7'), html_out = paste0("V07", html_suffix), rds_out = "V07.rds")
)



## loop provides the following arguments expected by 002_SCTransform_automate.qmd:
## [name of script], [output filename], [params list]
## params list format is list([input directory], [output rds])

for (r in runs) {
  message("=== running: ", paste0(r$html_out, " ", r$rds_out), " ===")
  rmarkdown::render(
    "002_SCTransform_automate.qmd",
    output_file = r$html_out,
    params = list(
      input_dir = r$input,
      output_rds = r$rds_out
    )
  )
  message("=== run: ", paste0(r$html_out, " ", r$rds_out), " complete ===")
}

# Note: --no-highlight warning can safely be ignored - version mismatch between Pandoc and RMarkdown

