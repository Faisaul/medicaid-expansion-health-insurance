# Medicaid Expansion and Health Insurance Coverage
# Faisal Mulla
# August 2026

# This script adds Medicaid expansion information
# to the ACS health insurance dataset.


# Load packages
library(tidyverse)
library(fixest)

# Load the insurance dataset
insurance_panel <- read_csv(
  "data/processed/insurance_panel.csv",
  show_col_types = FALSE
)


# Check the data
head(insurance_panel)

dim(insurance_panel)

# States that implemented Medicaid expansion in 2014
expansion_2014 <- c(
  "Arizona",
  "Arkansas",
  "California",
  "Colorado",
  "Connecticut",
  "Delaware",
  "District of Columbia",
  "Hawaii",
  "Illinois",
  "Iowa",
  "Kentucky",
  "Maryland",
  "Massachusetts",
  "Michigan",
  "Minnesota",
  "Nevada",
  "New Hampshire",
  "New Jersey",
  "New Mexico",
  "New York",
  "North Dakota",
  "Ohio",
  "Oregon",
  "Rhode Island",
  "Vermont",
  "Washington",
  "West Virginia"
)


# States that had not expanded Medicaid by the end of 2023
never_expanded <- c(
  "Alabama",
  "Florida",
  "Georgia",
  "Kansas",
  "Mississippi",
  "South Carolina",
  "Tennessee",
  "Texas",
  "Wisconsin",
  "Wyoming"
)

# Keep the 2014 expansion states and states that never expanded
did_data <- insurance_panel %>%
  filter(
    state %in% expansion_2014 |
      state %in% never_expanded
  )


# Create treatment variables
did_data <- did_data %>%
  mutate(
    expansion_state = if_else(
      state %in% expansion_2014,
      1,
      0
    ),
    
    post = if_else(
      year >= 2014,
      1,
      0
    ),
    
    treated_post = expansion_state * post
  )


# Check the treatment groups
did_data %>%
  distinct(state, expansion_state) %>%
  count(expansion_state)

# Calculate the average uninsured rate for each group by year
group_trends <- did_data %>%
  group_by(year, expansion_state) %>%
  summarise(
    average_uninsured_rate = mean(uninsured_rate),
    .groups = "drop"
  )

print(group_trends)

# Create labels for the two groups
group_trends <- group_trends %>%
  mutate(
    group = if_else(
      expansion_state == 1,
      "2014 expansion states",
      "Non-expansion states"
    )
  )


# Plot average uninsured rates over time
figure1 <- ggplot(
  group_trends,
  aes(
    x = year,
    y = average_uninsured_rate,
    linetype = group
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_vline(
    xintercept = 2014,
    linetype = "dotted"
  ) +
  labs(
    title = "Uninsured Rates Before and After Medicaid Expansion",
    subtitle = "Adults ages 18–64",
    x = "Year",
    y = "Average uninsured rate (%)",
    linetype = NULL
  ) +
  theme_minimal()

figure1

ggsave(
  "figures/uninsured_trends.png",
  figure1,
  width = 8,
  height = 5
)

# Estimate the difference-in-differences model
# State and year fixed effects are included
# Standard errors are clustered by state

did_model <- feols(
  uninsured_rate ~ treated_post | state + year,
  data = did_data,
  cluster = ~state
)

summary(did_model)

# Event-study model
# 2013 is the reference year

event_model <- feols(
  uninsured_rate ~ i(year, expansion_state, ref = 2013) |
    state + year,
  data = did_data,
  cluster = ~state
)

summary(event_model)
iplot(
  event_model,
  main = "Medicaid Expansion and Uninsured Rates",
  xlab = "Year",
  ylab = "Difference relative to 2013",
  ref.line = 0
)
