# Medicaid Expansion and Health Insurance Coverage
# Faisal Mulla
# August 2026

# This script downloads health insurance data from the
# American Community Survey and creates a state-year dataset
# of uninsured rates for adults ages 18 to 64.


# Load packages
library(tidyverse)
library(jsonlite)


# Create folders for the project
dir.create("data", showWarnings = FALSE)
dir.create("data/processed", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)
dir.create("tables", showWarnings = FALSE)


# Census API key is stored on my computer
census_key <- Sys.getenv("CENSUS_API_KEY")


# ACS variables for adults ages 18 to 64

# Total population
total_vars <- c(
  "B27001_009E",
  "B27001_012E",
  "B27001_015E",
  "B27001_018E",
  "B27001_021E",
  "B27001_037E",
  "B27001_040E",
  "B27001_043E",
  "B27001_046E",
  "B27001_049E"
)

# Uninsured population
uninsured_vars <- c(
  "B27001_011E",
  "B27001_014E",
  "B27001_017E",
  "B27001_020E",
  "B27001_023E",
  "B27001_039E",
  "B27001_042E",
  "B27001_045E",
  "B27001_048E",
  "B27001_051E"
)


# Function to download one year of ACS data
get_insurance_data <- function(year) {
  
  variables <- paste(
    c("NAME", total_vars, uninsured_vars),
    collapse = ","
  )
  
  url <- paste0(
    "https://api.census.gov/data/", year, "/acs/acs1",
    "?get=", variables,
    "&for=state:*",
    "&key=", census_key
  )
  
  raw_data <- fromJSON(url)
  
  data <- as.data.frame(raw_data[-1, ])
  names(data) <- raw_data[1, ]
  
  # Census downloads these values as text,
  # so convert them to numbers
  data[, c(total_vars, uninsured_vars)] <-
    lapply(
      data[, c(total_vars, uninsured_vars)],
      as.numeric
    )
  
  # Add the age groups together
  data$total_18_64 <- rowSums(data[, total_vars])
  
  data$uninsured_18_64 <- rowSums(data[, uninsured_vars])
  
  # Calculate the uninsured rate
  data$uninsured_rate <-
    (data$uninsured_18_64 / data$total_18_64) * 100
  
  # Rename and keep the variables needed for the analysis
  data <- data %>%
    rename(
      state_name = NAME,
      state_fips = state
    ) %>%
    transmute(
      state = state_name,
      state_fips,
      year = year,
      total_18_64,
      uninsured_18_64,
      uninsured_rate
    ) %>%
    filter(state != "Puerto Rico")
  
  return(data)
}


# Download ACS data for each year
# 2020 is excluded because standard ACS 1-year
# estimates were not released for that year
years <- c(2009:2019, 2021:2023)

insurance_panel <- map_dfr(
  years,
  get_insurance_data
)


# Check the dataset
dim(insurance_panel)

table(insurance_panel$year)

summary(insurance_panel$uninsured_rate)


# Look at the average uninsured rate by year
year_summary <- insurance_panel %>%
  group_by(year) %>%
  summarise(
    average_uninsured_rate = mean(uninsured_rate)
  )

print(year_summary)


# Save the final dataset
write_csv(
  insurance_panel,
  "data/processed/insurance_panel.csv"
)