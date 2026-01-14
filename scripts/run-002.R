library(rmarkdown)

# change the below path to where data is located
path <- "/path/to/sequencing-data/data_%s/outs/per_sample_outs/data_%s/count/sample"
# You can modify the suffix you want for your html
html_suffix <- "_SCTransform.html"
# Adjust to personal output directory
output_dir <- "/path/to/output/dir/" 

# sprintf - looks for %s in your path to replace with the provided text arguments below
# paste0 - simple concatenation of strings
# e.g. paste0("V05", html_suffix) would print "V05_SCTransform.html"

## edit runs list - arguments should be:
  # [1. input data location] 
  # [2. output html including path]
  # [3. output rds including path]
  # [4. location for new script] --- Question: should I make this step optional? 

  
runs <- list(
  list(input = sprintf(path, 'P5', 'P5'), 
       html_out = paste0(output_dir, "V05", html_suffix), 
       rds_out = paste0(output_dir, "V05.rds"), 
       new_script = paste0(output_dir, "002_CIO_pipeline_SCTransform_V05.qmd")),
  list(input = sprintf(path, 'P6', 'P6'), 
       html_out = paste0(output_dir, "V06", html_suffix), 
       rds_out = paste0(output_dir, "V06.rds"),  
       new_script = paste0(output_dir, "002_CIO_pipeline_SCTransform_V06.qmd")),
  list(input = sprintf(path, 'P7', 'P7'), 
       html_out = paste0(output_dir, "V07", html_suffix), 
       rds_out = paste0(output_dir, "V07.rds"), 
       new_script = paste0(output_dir, "002_CIO_pipeline_SCTransform_V07.qmd"))
  )



## loop provides the following arguments expected by 002_SCTransform_automate.qmd:
## [name of script], [output filename], [params list]
## params list format is list([input directory], [output rds])

for (r in runs) {
  message("=== running: ", paste0(r$html_out, " ", r$rds_out), " ===")
  rmarkdown::render(
    "scripts/002_CIO_pipeline_SCTransform_automate.qmd", # path to script
    output_file = r$html_out,
    params = list(
      input_dir = r$input,
      output_rds = r$rds_out
    )
  )
  message("=== copying new script: ", paste0(r$new_script), " ===")
  # copy using command line syntax - update with location of script to copy
  system2("cp", args = c("scripts/002_CIO_pipeline_SCTransform.qmd ", r$new_script)) 
  message("=== run: ", paste0(r$html_out, " ", r$rds_out), " complete ===")
}

# Note: --no-highlight warning can safely be ignored - version mismatch between Pandoc and RMarkdown





