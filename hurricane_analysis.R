# Atlantic Hurricane Data Analysis
# Author: Jeana Song
# Adapted and extended from DATASCI 306 Homework 5.
# Run from the repository root (open the .Rproj file in RStudio).

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)

# 1. Read and validate the raw CSV -----------------------------------------
storms <- read_csv("data/storms.csv", na = c("", "NA"), show_col_types = FALSE)
stopifnot(nrow(storms) == 19537L)

# 2. Audit missing values without changing the original data ---------------
missing_counts <- storms |>
  summarise(across(everything(), ~ sum(is.na(.x)))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") |>
  filter(n_missing > 0)
print(missing_counts)
# An NA hurricane category often means that the system is not a hurricane.
# Wind and pressure are complete in this dataset; no imputation is needed.

# 3. Custom function: count distinct hurricanes by year --------------------
# Repeated observations of the same storm must not count as separate storms.
annual_hurricane_counts <- function(df) {
  df |>
    group_by(year, name) |>
    summarise(
      is_hurricane = any(status == "hurricane", na.rm = TRUE),
      is_cat5 = any(category == 5, na.rm = TRUE),
      .groups = "drop"
    ) |>
    group_by(year) |>
    summarise(
      hurricanes = sum(is_hurricane),
      category5 = sum(is_cat5),
      .groups = "drop"
    )
}

yearly <- annual_hurricane_counts(storms)
print(head(yearly))

p1 <- yearly |>
  pivot_longer(c(hurricanes, category5),
               names_to = "type", values_to = "n") |>
  ggplot(aes(x = year, y = n)) +
  geom_line(color = "#1B6A84", linewidth = 0.7) +
  facet_wrap(~ type, ncol = 1, scales = "free_y") +
  labs(title = "Annual Hurricane Activity (1975-2022)",
       x = "Year", y = "Number of Distinct Storms") +
  theme_minimal()
print(p1)

# 4. Use one peak-wind observation per storm -------------------------------
# This avoids treating frequent measurements as independent storm samples.
# Here, a unique storm is identified by (year, name).
peak <- storms |>
  filter(!is.na(wind), !is.na(pressure)) |>
  group_by(year, name) |>
  slice_max(order_by = wind, n = 1, with_ties = FALSE) |>
  ungroup()
stopifnot(nrow(peak) == 655L)

# 5. Custom function: bin continuous measurements into terciles ------------
to_tercile <- function(x) {
  cuts <- quantile(x, probs = c(1/3, 2/3), na.rm = TRUE)
  if (cuts[1] >= cuts[2]) stop("Tercile breakpoints must differ")
  cut(x, breaks = c(-Inf, cuts, Inf),
      labels = c("Low", "Medium", "High"), include.lowest = TRUE)
}

# 6. Chi-squared test and Pearson correlation ------------------------------
peak <- peak |>
  mutate(wind_group = to_tercile(wind),
         pressure_group = to_tercile(pressure))
frequency <- with(peak, table(wind_group, pressure_group))
chi <- chisq.test(frequency)
print(frequency)
print(chi)
cat("Minimum expected count:", min(chi$expected), "\n")
cat("Pearson correlation:", cor(peak$wind, peak$pressure), "\n")

# 7. Plot and export results ------------------------------------------------
p2 <- ggplot(peak, aes(x = wind, y = pressure)) +
  geom_point(color = "#1B6A84", alpha = 0.30) +
  geom_smooth(method = "lm", se = FALSE, color = "#D4764E") +
  labs(title = "Wind Speed and Pressure at Storm Peak",
       x = "Peak Wind Speed (knots)", y = "Central Pressure (mb)") +
  theme_minimal()
print(p2)

dir.create("figures", showWarnings = FALSE)
ggsave("figures/annual_hurricane_counts.png", plot = p1,
       width = 7, height = 4.2, dpi = 300)
ggsave("figures/storm_peak_wind_pressure.png", plot = p2,
       width = 7, height = 4.2, dpi = 300)
