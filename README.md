# Atlantic Hurricane Data Analysis in R

An exploratory and statistical analysis of Atlantic hurricane activity from **1975 to 2022**, using a historical `storms` dataset with **19,537 time-stamped observations and 13 variables**.

This project was **adapted and extended from DATASCI 306 Homework 5**. The revised analysis emphasizes reproducible CSV import, missing-data auditing, reusable R functions, storm-level aggregation, statistical testing, and visualization.

## Questions explored

1. How many **distinct hurricanes** occur in each year, and how often do storms reach Category 5?
2. What is the relationship between a storm's peak wind speed and its central pressure?

## Example visualizations

**Annual number of distinct hurricanes and Category 5 storms**

![Annual hurricane activity](figures/annual_hurricane_counts.png)

**Peak wind speed versus central pressure**

![Wind speed and pressure at storm peak](figures/storm_peak_wind_pressure.png)

## Approach

- **Import and validate CSV data:** Read the versioned local dataset using `readr::read_csv()`.
- **Audit missing data:** Report missingness by variable. The wind and pressure fields used in the main analysis are complete; no imputation is applied to them.
- **Write a custom counting function:** `annual_hurricane_counts()` counts each named storm once per year rather than counting every time-stamped observation.
- **Build a storm-level dataset:** Retain one peak-wind observation for each `(year, name)` pair (**655 storm-year groups**).
- **Write a custom transformation function:** `to_tercile()` assigns continuous wind and pressure measurements to three quantile-based groups.
- **Assess association:** Use a Pearson correlation and a chi-squared test of the wind-by-pressure contingency table; visualize the relationship using `ggplot2`.

## Selected results

The storm-level analysis found a strong negative relationship between peak wind speed and central pressure:

| Metric | Result |
| --- | ---: |
| Storm-year groups analyzed | 655 |
| Pearson correlation | -0.9633 |
| Chi-squared statistic | 694.09 |
| Degrees of freedom | 4 |
| p-value | < 2.2 × 10⁻¹⁶ |
| Minimum expected cell count | 62.30 |

Higher wind speeds are associated with lower central pressures. These results show **association, not causation**. The chi-squared test uses discretized versions of the two continuous variables, and repeated time-point records are not treated as independent storms.

## Files

```text
Atlantic-Hurricane-Data-Analysis/
├── README.md
├── hurricane_analysis.R       # Complete reproducible R script
├── hurricane_analysis.Rmd     # Annotated report with visual output
├── Atlantic-Hurricane-Data-Analysis.Rproj
├── data/
│   └── storms.csv             # Versioned source data
└── figures/
    ├── annual_hurricane_counts.png
    └── storm_peak_wind_pressure.png
```

## Reproduce the analysis

**Requirements:** R (4.1 or later recommended) and the packages `readr`, `dplyr`, `tidyr`, `ggplot2`. To render the report, also install `rmarkdown` and `knitr`.

1. Download or clone this repository.
2. In RStudio, open `Atlantic-Hurricane-Data-Analysis.Rproj` to use the repository as the working directory.
3. If needed, install the required packages:

   ```r
   install.packages(c("readr", "dplyr", "tidyr", "ggplot2", "rmarkdown", "knitr"))
   ```

4. Open `hurricane_analysis.R` and select **Source**, or run:

   ```r
   source("hurricane_analysis.R")
   ```

5. The script prints the data audit and statistics, displays two charts, and saves both PNG files under `figures/`. Alternatively, open `hurricane_analysis.Rmd` and click **Knit** to generate an HTML report.

## Data provenance and limitations

- **Data:** `storms.csv` from [`dplyr` v1.1.4](https://github.com/tidyverse/dplyr/blob/v1.1.4/data-raw/storms.csv), also available in the `dplyr`/`nycflights13` teaching ecosystem. The version is pinned to make results reproducible.
- **Coverage:** Atlantic storm records, 1975–2022. Individual named storms have repeated observations; frequencies and regression results depend on the unit of analysis.
- **Identifiers:** This sample identifies storms by `(year, name)` because this CSV does not contain a dedicated storm ID. A formal meteorological study should consider persistent storm identifiers and changes in historical observation coverage.
- **Purpose:** A course-based exploratory data analysis and programming demonstration, **not** a causal or climate-attribution study.

## Author

Jeana Song · University of Michigan · Data Science
