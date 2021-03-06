#' Save a **gt** table as a file
#'
#' The `gtsave()` function makes it easy to save a **gt** table to a file. The
#' function guesses the file type by the extension provided in the output
#' filename, producing either an HTML, PDF, PNG, LaTeX, or RTF file.
#'
#' Output filenames with either the `.html` or `.htm` extensions will produce an
#' HTML document. In this case, we can pass a `TRUE` or `FALSE` value to the
#' `inline_css` option to obtain an HTML document with inlined CSS styles (the
#' default is `FALSE`). More details on CSS inlining are available at
#' [as_raw_html()]. We can pass values to arguments in [htmltools::save_html()]
#' through the `...`. Those arguments are either `background` or `libdir`,
#' please refer to the **htmltools** documentation for more details on the use
#' of these arguments.
#'
#' We can create an image file based on the HTML version of the `gt` table. With
#' the filename extension `.png`, we get a PNG image file. A PDF document can be
#' generated by using the `.pdf` extension. This process is facilitated by the
#' **webshot** package, so, this package needs to be installed before
#' attempting to save any table as an image file. There is the option of passing
#' values to the underlying [webshot::webshot()] function though `...`. Some of
#' the more useful arguments for PNG saving are `zoom` (defaults to a scale
#' level of `2`) and `expand` (adds whitespace pixels around the cropped table
#' image, and has a default value of `5`). There are several more options
#' available so have a look at the **webshot** documentation for further
#' details.
#'
#' If the output filename extension is either of `.tex`, `.ltx`, or `.rnw`, a
#' LaTeX document is produced. An output filename of `.rtf` will generate an RTF
#' document. The LaTeX and RTF saving functions don't have any options to pass
#' to `...`.
#'
#' @param data A table object that is created using the [gt()] function.
#' @param filename The file name to create on disk. Ensure that an extension
#'   compatible with the output types is provided (`.html`, `.tex`, `.ltx`,
#'   `.rtf`). If a custom save function is provided then the file extension is
#'   disregarded.
#' @param path An optional path to which the file should be saved (combined with
#'   filename).
#' @param ... All other options passed to the appropriate internal saving
#'   function.
#'
#' @examples
#' \dontrun{
#' # Use `gtcars` to create a gt table; add
#' # a stubhead label to describe what is
#' # in the stub
#' tab_1 <-
#'   gtcars %>%
#'   dplyr::select(model, year, hp, trq) %>%
#'   dplyr::slice(1:5) %>%
#'   gt(rowname_col = "model") %>%
#'   tab_stubhead_label(label = "car")
#'
#' # Get an HTML file with inlined CSS
#' # (which is necessary for including the
#' # table as part of an HTML email)
#' tab_1 %>%
#'   gtsave("tab_1.html", inline_css = TRUE)
#'
#' # By leaving out the `inline_css` option,
#' # we get a more conventional HTML file
#' # with embedded CSS styles
#' tab_1 %>% gtsave("tab_1.html")
#'
#' # Save the HTML table as a PDF file; we
#' # can optionally add a separate `path`
#' tab_1 %>% gtsave("tab_1.pdf", path = "~")
#'
#' # Saving as PNG file results in a cropped
#' # image of an HTML table; the amount of
#' # whitespace can be set
#' tab_1 %>% gtsave("tab_1.png", expand = 10)
#'
#' # Any use of the `.tex`, `.ltx`, or `.rnw`
#' # will result in the output of a LaTeX
#' # document
#' tab_1 %>% gtsave("tab_1.tex")
#' }
#'
#' @family Export Functions
#' @section Function ID:
#' 13-1
#'
#' @export
gtsave <- function(data,
                   filename,
                   path = NULL,
                   ...) {

  # Perform input object validation
  stop_if_not_gt(data = data)

  # Get the lowercased file extension
  file_ext <- gtsave_file_ext(filename)

  ext_supported_text <-
    paste0(
      "We can use:\n",
      " * `.html`, `.htm` (HTML file)\n",
      " * `.png`          (PNG file)\n",
      " * `.pdf`          (PDF file)\n",
      " * `.tex`, `.rnw`  (LaTeX file)\n",
      " * `.rtf`          (RTF file)\n"
    )

  # Stop function if a file extension is not provided
  if (file_ext == "") {

    stop("A file extension is required in the provided filename. ",
         ext_supported_text,
         call. = FALSE)
  }

  # Use the appropriate save function based
  # on the filename extension
  switch(file_ext,
          "htm" = ,
         "html" = gt_save_html(data, filename, path, ...),
          "ltx" = , # We don't verbally support using `ltx`
          "rnw" = ,
          "tex" = gt_save_latex(data, filename, path, ...),
          "rtf" = gt_save_rtf(data, filename, path, ...),
          "png" = ,
          "pdf" = gt_save_webshot(data, filename, path, ...),
         {
           stop("The file extension used (`.", file_ext, "`) doesn't have an ",
                "associated saving function. ",
                ext_supported_text,
                call. = FALSE)
         }
  )
}

#' Saving function for an HTML file
#'
#' @noRd
gt_save_html <- function(data,
                         filename,
                         path = NULL,
                         ...,
                         inline_css = FALSE) {

  filename <- gtsave_filename(path = path, filename = filename)

  if (inline_css) {

    data %>%
      as_raw_html(inline_css = inline_css) %>%
      htmltools::HTML() %>%
      htmltools::save_html(filename, ...)

  } else {

    data %>%
      htmltools::as.tags() %>%
      htmltools::save_html(filename, ...)
  }
}

#' Saving function for an image file via the webshot package
#'
#' @noRd
gt_save_webshot <- function(data,
                            filename,
                            path = NULL,
                            ...,
                            zoom = 2,
                            expand = 5) {

  filename <- gtsave_filename(path = path, filename = filename)

  # Create a temporary file with the `html` extension
  tempfile_ <- tempfile(fileext = ".html")

  # Reverse slashes on Windows filesystems
  tempfile_ <-
    tempfile_ %>%
    tidy_gsub("\\\\", "/")

  # Save gt table as HTML using the `gt_save_html()` function
  data %>% gt_save_html(filename = tempfile_, path = NULL)

  # Saving an image requires the webshot package; if it's
  # not present, stop with a message
  if (!requireNamespace("webshot", quietly = TRUE)) {

    stop("The `webshot` package is required for saving images of gt tables.",
         call. = FALSE)

  } else {

    # Save the image in the working directory
    webshot::webshot(
      url = paste0("file:///", tempfile_),
      file = filename,
      selector = "table",
      zoom = zoom,
      expand = expand,
      ...
    )
  }
}

#' Saving function for a LaTeX file
#'
#' @noRd
gt_save_latex <- function(data,
                          filename,
                          path = NULL,
                          ...) {

  filename <- gtsave_filename(path = path, filename = filename)

  data %>%
    as_latex() %>%
    writeLines(con = filename)
}

#' Saving function for an RTF file
#'
#' @noRd
gt_save_rtf <- function(data,
                        filename,
                        path = NULL,
                        ...) {

  filename <- gtsave_filename(path = path, filename = filename)

  data %>%
    as_rtf() %>%
    writeLines(con = filename)
}

#' Get the lowercase extension from a filename
#'
#' @noRd
gtsave_file_ext <- function(filename) {

  tools::file_ext(filename) %>% tolower()
}

#' Combine `path` with `filename` and normalize the path
#'
#' @noRd
gtsave_filename <- function(path, filename) {

  if (!is.null(path)) {
    filename <- file.path(path, filename)
  }

  filename %>% path_expand()
}

#' Get the HTML content of a **gt** table
#'
#' Get the HTML content from a `gt_tbl` object as a single-element character
#' vector. By default, the generated HTML will have inlined styles, where CSS
#' styles (that were previously contained in CSS rule sets external to the
#' `<table> element`) are included as `style` attributes in the HTML table's
#' tags. This option is preferable when using the output HTML table in an
#' emailing context.
#'
#' @param data A table object that is created using the [gt()] function.
#' @param inline_css An option to supply styles to table elements as inlined CSS
#'   styles. This is useful when including the table HTML as part of an HTML
#'   email message body, since inlined styles are largely supported in email
#'   clients over using CSS in a `<style>` block.
#'
#' @examples
#' # Use `gtcars` to create a gt table;
#' # add a header and then export as
#' # HTML code with CSS inlined
#' tab_html <-
#'   gtcars %>%
#'   dplyr::select(mfr, model, msrp) %>%
#'   dplyr::slice(1:5) %>%
#'   gt() %>%
#'   tab_header(
#'     title = md("Data listing from **gtcars**"),
#'     subtitle = md("`gtcars` is an R dataset")
#'   ) %>%
#'   as_raw_html()
#'
#' # `tab_html` is a single-element vector
#' # containing inlined HTML for the table;
#' # it has only the `<table>...</table>` part
#' # so it's not a complete HTML document but
#' # rather an HTML fragment
#' tab_html %>%
#'   substr(1, 700) %>%
#'   cat()
#'
#' @family Export Functions
#' @section Function ID:
#' 13-2
#'
#' @export
as_raw_html <- function(data,
                        inline_css = TRUE) {

  # Perform input object validation
  stop_if_not_gt(data = data)

  # Generation of the HTML table
  html_table <- render_as_html(data = data)

  if (inline_css) {

    # Create inline styles
    html_table <-
      html_table %>%
      inline_html_styles(css_tbl = get_css_tbl(data))
  }

  htmltools::HTML(html_table)
}

#' Output a gt object as LaTeX
#'
#' Get the LaTeX content from a `gt_tbl` object as a `knit_asis` object. This
#' object contains the LaTeX code and attributes that serve as LaTeX
#' dependencies (i.e., the LaTeX packages required for the table). Using
#' `as.character()` on the created object will result in a single-element vector
#' containing the LaTeX code.
#'
#' @param data A table object that is created using the [gt()] function.
#'
#' @examples
#' # Use `gtcars` to create a gt table;
#' # add a header and then export as
#' # an object with LaTeX code
#' tab_latex <-
#'   gtcars %>%
#'   dplyr::select(mfr, model, msrp) %>%
#'   dplyr::slice(1:5) %>%
#'   gt() %>%
#'   tab_header(
#'     title = md("Data listing from **gtcars**"),
#'     subtitle = md("`gtcars` is an R dataset")
#'   ) %>%
#'   as_latex()
#'
#' # `tab_latex` is a `knit_asis` object,
#' # which makes it easy to include in
#' # R Markdown documents that are knit to
#' # PDF; we can use `as.character()` to
#' # get just the LaTeX code as a single-
#' # element vector
#' tab_latex %>%
#'   as.character() %>%
#'   cat()
#'
#' @family Export Functions
#' @section Function ID:
#' 13-3
#'
#' @export
as_latex <- function(data) {

  # Perform input object validation
  stop_if_not_gt(data = data)

  # Build all table data objects through a common pipeline
  data <- data %>% build_data(context = "latex")

  # Composition of LaTeX ----------------------------------------------------

  # Create a LaTeX fragment for the start of the table
  table_start <- create_table_start_l(data = data)

  # Create the heading component
  heading_component <- create_heading_component(data = data, context = "latex")

  # Create the columns component
  columns_component <- create_columns_component_l(data = data)

  # Create the body component
  body_component <- create_body_component_l(data = data)

  # Create the source notes component
  source_notes_component <- create_source_note_component_l(data = data)

  # Create the footnotes component
  footnotes_component <- create_footnotes_component_l(data = data)

  # Create a LaTeX fragment for the ending tabular statement
  table_end <- create_table_end_l()

  # If the `rmarkdown` package is available, use the
  # `latex_dependency()` function to load latex packages
  # without requiring the user to do so
  if (requireNamespace("rmarkdown", quietly = TRUE)) {

    latex_packages <-
      lapply(latex_packages(), rmarkdown::latex_dependency)

  } else {
    latex_packages <- NULL
  }

  # Compose the LaTeX table
  paste0(
    table_start,
    heading_component,
    columns_component,
    body_component,
    table_end,
    footnotes_component,
    source_notes_component,
    collapse = ""
  ) %>%
    knitr::asis_output(meta = latex_packages)
}

#' Output a **gt** object as RTF
#'
#' Get the RTF content from a `gt_tbl` object as as a single-element character
#' vector. This object can be used with `writeLines()` to generate a valid .rtf
#' file that can be opened by RTF readers.
#'
#' @param data a table object that is created using the `gt()` function.
#'
#' @examples
#' # Use `gtcars` to create a gt table;
#' # add a header and then export as
#' # RTF code
#' tab_rtf <-
#'   gtcars %>%
#'   dplyr::select(mfr, model) %>%
#'   dplyr::slice(1:2) %>%
#'   gt() %>%
#'   tab_header(
#'     title = md("Data listing from **gtcars**"),
#'     subtitle = md("`gtcars` is an R dataset")
#'   ) %>%
#'   as_rtf()
#'
#' @family Export Functions
#' @section Function ID:
#' 13-4
#'
#' @export
as_rtf <- function(data) {

  # Perform input object validation
  stop_if_not_gt(data = data)

  # Build all table data objects through a common pipeline
  data <- data %>% build_data(context = "rtf")

  # Composition of RTF ------------------------------------------------------

  # Create a RTF fragment for the start of the table
  table_start <- rtf_head()

  # Create the heading component
  heading_component <- create_heading_component(data = data, context = "rtf")

  # Create the columns component
  columns_component <- create_columns_component_r(data = data)

  # Create the body component
  body_component <- create_body_component_r(data = data)

  # Create the footnotes component
  footnotes_component <- create_footnotes_component_r(data = data)

  # Create the source notes component
  source_notes_component <- create_source_notes_component_r(data = data)

  # Create a fragment for the ending tabular statement
  table_end <- "}\n"

  # Compose the RTF table
  rtf_table <-
    paste0(
      table_start,
      heading_component,
      columns_component,
      body_component,
      footnotes_component,
      source_notes_component,
      table_end,
      collapse = ""
    )

  if (isTRUE(getOption('knitr.in.progress'))) {
    rtf_table <- rtf_table %>% knitr::raw_output()
  }

  rtf_table
}

#' Extract a summary list from a **gt** object
#'
#' Get a list of summary row data frames from a `gt_tbl` object where summary
#' rows were added via the [summary_rows()] function. The output data frames
#' contain the `groupname` and `rowname` columns, whereby `rowname` contains
#' descriptive stub labels for the summary rows.
#'
#' @param data A table object that is created using the [gt()] function.
#'
#' @return A list of data frames containing summary data.
#'
#' @examples
#' # Use `sp500` to create a gt table with
#' # row groups; create summary rows by row
#' # group (`min`, `max`, `avg`) and then
#' # extract the summary rows as a list
#' # object
#' summary_extracted <-
#'   sp500 %>%
#'   dplyr::filter(
#'     date >= "2015-01-05" &
#'       date <="2015-01-30"
#'   ) %>%
#'   dplyr::arrange(date) %>%
#'   dplyr::mutate(
#'     week = paste0(
#'       "W", strftime(date, format = "%V"))
#'   ) %>%
#'   dplyr::select(-adj_close, -volume) %>%
#'   gt(
#'     rowname_col = "date",
#'     groupname_col = "week"
#'   ) %>%
#'   summary_rows(
#'     groups = TRUE,
#'     columns = vars(open, high, low, close),
#'     fns = list(
#'       min = ~min(.),
#'       max = ~max(.),
#'       avg = ~mean(.)),
#'     formatter = fmt_number,
#'     use_seps = FALSE
#'   ) %>%
#'   extract_summary()
#'
#' # Use the summary list to make a new
#' # gt table; the key thing is to use
#' # `dplyr::bind_rows()` and then pass the
#' # tibble to `gt()` (the `groupname` and
#' # `rowname` magic column names create
#' # row groups and a stub)
#' tab_1 <-
#'   summary_extracted %>%
#'   unlist(recursive = FALSE) %>%
#'   dplyr::bind_rows() %>%
#'   gt()
#'
#' @section Figures:
#' \if{html}{\figure{man_extract_summary_1.svg}{options: width=100\%}}
#'
#' @family Export Functions
#' @section Function ID:
#' 13-5
#'
#' @export
extract_summary <- function(data) {

  # Perform input object validation
  stop_if_not_gt(data = data)

  # Stop function if there are no
  # directives to create summary rows
  if (!dt_summary_exists(data = data)) {
    stop("There is no summary list to extract.\n",
         "Use the `summary_rows()` function to generate summaries.",
         call. = FALSE)
  }

  # Build the `data` using the standard
  # pipeline with the `html` context
  built_data <- build_data(data = data, context = "html")

  # Extract the list of summary data frames
  # that contains tidy, unformatted data
  dt_summary_df_data_get(data = built_data) %>% as.list()
}
