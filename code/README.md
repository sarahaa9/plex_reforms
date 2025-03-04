# # Missing Middle or Missing Impact? Evidence from City-Wide Plex Reforms

## Project Overview

This research project investigates the impact of "missing middle" zoning reforms (also known as "plex reforms") on housing supply across multiple U.S. cities. The analysis uses building permit data and detailed zoning maps to measure the intensity of upzoning reforms and their effects on housing construction.

## Key Research Questions

1. How do plex reforms vary in intensity across cities?
2. Do plex reforms increase the total supply of housing permits?
3. How do plex reforms affect the distribution of housing types (single-family, duplex, etc.)?
4. Do plex reforms cause substitution effects across different housing types?
5. Do plex reforms lead to substitution of building across different areas within a city?

## Data Sources

- **Building Permits Survey**: Monthly data on residential building permits from the Census Bureau (1995-2023)
- **Zoning Maps**: GIS data on zoning districts before and after reforms for each treated city
- **Population Data**: 2010 Census population data for MSAs
- **WRLURI**: Wharton Residential Land Use Regulatory Index to control for pre-existing regulatory restrictiveness

## Treated Cities

The analysis includes eight cities that implemented plex reforms:
1. Walla Walla, WA (Jan 2019)
2. Grand Rapids, MI (Apr 2019)
3. Durham, NC (Oct 2019)
4. Minneapolis, MN (Jan 2020)
5. Portland, OR (Aug 2021)
6. Raleigh, NC (Aug 2021)
7. San Francisco, CA (Oct 2022)
8. Spokane, WA (Aug 2022)

## Project Structure

```
Land Use Regulation/
├── code/                # All Stata code files
│   ├── 1_data_cleaning/ # Data cleaning and processing
│   ├── 2_descriptive/   # Descriptive statistics and visualization
│   ├── 3_analysis/      # Main analytical models
│   ├── 4_event_studies/ # Event studies analysis
│   ├── 5_city_specific/ # City-specific calculations
│   └── 6_robustness/    # Robustness checks
├── data/
│   ├── raw/             # Original unprocessed data
│   ├── processed/       # Cleaned and processed datasets
│   └── shapefiles/      # GIS shapefiles for spatial analysis
├── output/
│   ├── tables/          # Statistical tables
│   ├── figures/         # Graphs and visualizations
│   └── results/         # Other results
└── documentation/       # Project documentation
```

## Running the Analysis

The entire analysis can be run using the master script:

```
do master.do
```

To run specific sections, modify the configuration switches at the top of the master script.

## Key Variables

- `treat_intens`: A measure of reform intensity based on what percentage of residential land was affected and what the change in density was
- `total_n`: Total residential permits issued per 100,000 population
- `one_unit_n`: Single-family permits issued per 100,000 population
- `two_unit_n`: Duplex permits issued per 100,000 population
- `three_four_unit_n`: Triplex/fourplex permits issued per 100,000 population
- `five_plus_unit_n`: Five-plus unit permits issued per 100,000 population

## Main Findings

1. Plex reforms vary dramatically in their intensity across cities
2. Reforms lead to minimal effects on total housing supply
3. Reforms decrease single-family permits and increase duplex permits, suggesting substitution between housing types
4. Within-city analysis shows substitution between zoning districts (e.g., in Minneapolis)

## Contact

For questions or additional information, please contact Sarah R Aaronson.

## Last Updated

February 25, 2025
