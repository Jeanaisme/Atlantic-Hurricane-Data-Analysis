# Atlantic Hurricane Data Analysis: Extended Edition
# Adapted from DATASCI 306 Homework 5 | Jeana Song
# Run in the project root after opening the .Rproj file in RStudio.

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)

# 01 | Data import, validation, and missingness audit ----------------------
storms <- read_csv("data/storms.csv", na = c("", "NA"), show_col_types = FALSE)
stopifnot(nrow(storms) == 19537L,
          all(c("year", "name", "month", "status", "category",
                "wind", "pressure", "lat", "long") %in% names(storms)))

missing_counts <- storms |>
  summarise(across(everything(), ~ sum(is.na(.x)))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") |>
  filter(n_missing > 0)
print(missing_counts)
# Wind and pressure are complete. Missing category often means non-hurricane;
# do not replace this meaningful NA with an invented hurricane category.

# 02 | Custom function: count distinct hurricanes -------------------------
# One storm has many time-stamped observations. Deduplicate by (year, name).
annual_hurricane_counts <- function(df) {
  df |>
    group_by(year, name) |>
    summarise(is_hurricane = any(status == "hurricane", na.rm = TRUE),
              is_cat5 = any(category == 5, na.rm = TRUE),
              .groups = "drop") |>
    group_by(year) |>
    summarise(hurricanes = sum(is_hurricane),
              category5 = sum(is_cat5), .groups = "drop")
}
yearly <- annual_hurricane_counts(storms)

p1 <- yearly |>
  pivot_longer(c(hurricanes, category5), names_to = "type", values_to = "n") |>
  ggplot(aes(year, n)) +
  geom_line(color = "#176786", linewidth = 0.8) +
  facet_wrap(~ type, ncol = 1, scales = "free_y") +
  labs(title = "Annual hurricane activity, 1975-2022", x = "Year",
       y = "Distinct hurricanes") +
  theme_minimal(base_size = 11)

# 03 | Storm-level samples for valid units of analysis --------------------
# One observation at maximum recorded wind per named storm-year group.
peak <- storms |>
  filter(!is.na(wind), !is.na(pressure)) |>
  group_by(year, name) |>
  slice_max(order_by = wind, n = 1, with_ties = FALSE) |>
  ungroup()
stopifnot(nrow(peak) == 655L)

# A second dataset keeps only storms that attained hurricane status;
# a hurricane's strongest hurricane-stage observation is its representative.
hurricane_peak <- storms |>
  filter(status == "hurricane", !is.na(category),
         !is.na(wind), !is.na(pressure)) |>
  group_by(year, name) |>
  slice_max(order_by = wind, n = 1, with_ties = FALSE) |>
  ungroup()
stopifnot(nrow(hurricane_peak) == 319L)

# 04 | Seasonal distribution: FIRST hurricane-stage month -----------------
# Count each hurricane once, in the month it first reached hurricane status.
# This is not a count of all observations, nor the storm's formation month.
first_hurricane <- storms |>
  filter(status == "hurricane") |>
  arrange(year, name, month, day, hour) |>
  group_by(year, name) |>
  slice_head(n = 1) |>
  ungroup()

monthly_hurricanes <- first_hurricane |>
  count(month, name = "hurricanes") |>
  complete(month = 1:12, fill = list(hurricanes = 0)) |>
  arrange(month)

p3 <- ggplot(monthly_hurricanes, aes(x = factor(month, levels = 1:12),
                                     y = hurricanes)) +
  geom_col(fill = "#176786", width = 0.76) +
  labs(title = "When storms first reach hurricane status", x = "Month",
       y = "Number of distinct hurricanes") +
  theme_minimal(base_size = 11)

# 05 | Annual changes in hurricane peak intensity -------------------------
# Use one peak wind speed per hurricane; summarize with the annual median.
annual_intensity <- hurricane_peak |>
  group_by(year) |>
  summarise(median_peak_wind = median(wind),
            hurricane_count = n(),
            major_hurricanes = sum(category >= 3, na.rm = TRUE),
            .groups = "drop")

intensity_trend <- lm(median_peak_wind ~ year, data = annual_intensity)
print(summary(intensity_trend))

p4 <- ggplot(annual_intensity, aes(year, median_peak_wind)) +
  geom_point(color = "#176786", alpha = 0.9, size = 1.7) +
  geom_smooth(method = "lm", se = TRUE, color = "#D4774B", fill = "#F2D9CD") +
  labs(title = "Annual median peak hurricane wind speed", x = "Year",
       y = "Median peak wind (knots)") +
  theme_minimal(base_size = 11)

# 06 | Correlation, regression, and a chi-squared test ---------------------
# A storm-level dataset limits repeated-measure pseudo-replication.
pearson_result <- cor.test(peak$wind, peak$pressure, method = "pearson")
spearman_result <- cor.test(peak$wind, peak$pressure,
                            method = "spearman", exact = FALSE)
pressure_model <- lm(pressure ~ wind, data = peak)

# Custom function: discretize numeric measurements into 3 quantile groups.
to_tercile <- function(x) {
  cuts <- quantile(x, probs = c(1/3, 2/3), na.rm = TRUE)
  if (cuts[1] >= cuts[2]) stop("Tercile breakpoints must differ")
  cut(x, breaks = c(-Inf, cuts, Inf),
      labels = c("Low", "Medium", "High"), include.lowest = TRUE)
}
peak <- peak |>
  mutate(wind_group = to_tercile(wind),
         pressure_group = to_tercile(pressure))
frequency <- with(peak, table(wind_group, pressure_group))
chi <- chisq.test(frequency)

print(pearson_result)
print(spearman_result)
print(summary(pressure_model))
print(frequency)
print(chi)
cat("Minimum expected chi-square cell count:", min(chi$expected), "\n")

p2 <- ggplot(peak, aes(wind, pressure)) +
  geom_point(color = "#176786", alpha = 0.36, size = 1.5) +
  geom_smooth(method = "lm", se = FALSE, color = "#D4774B") +
  labs(title = "Peak wind speed and central pressure", x = "Wind (knots)",
       y = "Pressure (mb)") +
  theme_minimal(base_size = 11)

# 07 | Category boxplots: pressure differs across wind-based classes ------
# Comparing pressure, not wind, avoids merely re-plotting the wind thresholds
# that define hurricane categories.
p5 <- hurricane_peak |>
  mutate(category_label = factor(category, levels = 1:5)) |>
  ggplot(aes(category_label, pressure)) +
  geom_boxplot(fill = "#B5D9E4", color = "#176786", outlier.alpha = 0.45) +
  labs(title = "Pressure at peak intensity by hurricane category",
       x = "Hurricane category at peak wind", y = "Pressure (mb)") +
  theme_minimal(base_size = 11)

# 08 | Spatial distribution of peak hurricane locations ------------------
# Plot one peak-intensity location per hurricane to avoid longer-lasting
# storms dominating the geographic map; not a map of storm genesis/landfall.
p6 <- ggplot(hurricane_peak, aes(long, lat)) +
  geom_bin_2d(bins = 28) +
  scale_fill_viridis_c(name = "Hurricanes", option = "C") +
  coord_quickmap() +
  labs(title = "Locations of recorded peak hurricane intensity",
       x = "Longitude", y = "Latitude") +
  theme_minimal(base_size = 11)

# 09 | Export reproducible figures ----------------------------------------
plots <- list(
  annual_hurricane_counts = p1,
  storm_peak_wind_pressure = p2,
  hurricane_first_month = p3,
  annual_peak_wind_trend = p4,
  pressure_by_hurricane_category = p5,
  peak_hurricane_locations = p6
)
dir.create("figures", showWarnings = FALSE)
for (nm in names(plots)) {
  ggsave(file.path("figures", paste0(nm, ".png")), plot = plots[[nm]],
         width = 7.5, height = 4.4, dpi = 220)
}

# Results are descriptive/associational, not evidence of causation.
# Annual trends may also depend on historical detection and reporting practices.
