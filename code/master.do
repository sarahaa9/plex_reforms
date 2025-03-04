/*==============================================================================
Project: Missing Middle or Missing Impact? Evidence from City-Wide Plex Reforms
Author: Sarah R Aaronson
Date Created: February 25, 2025
Last Modified: February 25, 2025
==============================================================================*/

/* This master script runs the entire analysis pipeline for the "Missing Middle or
Missing Impact?" project that studies the effects of plex reforms on housing supply
across multiple US cities.

The script is organized into the following sections:
1. Setup - Establishes project directory structure and settings
2. Data Cleaning - Cleans and processes raw data
3. Descriptive Analysis - Generates summary statistics and data visualization
4. Main Analysis - Runs the main difference-in-differences models
5. Event Studies - Implements event study analyses
6. City-Specific Analysis - Calculates zoning reform intensity by city
7. Robustness Checks - Additional analyses for robustness

To run only specific sections, modify the switches below.
*/

********************************************************************************
** CONFIGURATION SECTION
********************************************************************************

* Project directory - MODIFY THIS LINE to point to your project root folder
global projdir "/Users/sarah/Desktop/Research/Land Use Regulation"

* Section switches (set to 1 to run, 0 to skip)
global run_setup = 1
global run_clean = 1 
global run_describe = 1
global run_main_analysis = 1
global run_event_studies = 1
global run_city_analysis = 1
global run_robustness = 1

* Output format preferences
global export_graph = 1           // Export graphs (1 = Yes, 0 = No)
global export_tables = 1          // Export tables (1 = Yes, 0 = No)
global table_format = "tex"       // Table format: "tex", "csv", "xlsx"
global graph_format = "png"       // Graph format: "png", "pdf", "eps"

* Settings
set more off
set seed 12345                    // Set random seed for reproducibility

********************************************************************************
** 1. SETUP - Create directory structure
********************************************************************************
if $run_setup == 1 {
    di "Setting up project directory structure..."
    
    * Define subdirectories
    global raw "$projdir/data/raw"
    global processed "$projdir/data/processed"
    global shapefiles "$projdir/data/shapefiles"
    global tables "$projdir/output/tables"
    global figures "$projdir/output/figures"
    global results "$projdir/output/results"
    global documentation "$projdir/documentation"

    * Create logs directory first
    capture mkdir "$projdir/logs"
    
    * Optional: Log file setup - MOVED AFTER DIRECTORY CREATION
    local datetime: display %td_CY-N-D date("`c(current_date)'", "DMY")
    local time: display %tcHH-MM-SS clock("`c(current_time)'", "hms")
    global logfile "$projdir/logs/log_${datetime}_${time}.log"
    
    * Start log
    capture log close
    log using "$projdir/logs/master_log_`c(current_date)'.log", replace
    
    * Create directories if they don't exist
    capture mkdir "$projdir/code/scripts_plex_reforms/1_data_cleaning"
    capture mkdir "$projdir/code/scripts_plex_reforms/2_descriptive"
    capture mkdir "$projdir/code/scripts_plex_reforms/3_analysis"
    capture mkdir "$projdir/code/scripts_plex_reforms/4_event_studies"
    capture mkdir "$projdir/code/scripts_plex_reforms/5_city_specific"
    capture mkdir "$projdir/code/scripts_plex_reforms/6_robustness"
    
    capture mkdir "$processed"
    capture mkdir "$processed/permits"
    capture mkdir "$processed/area"
    
    capture mkdir "$tables"
    capture mkdir "$figures"
    capture mkdir "$results"
    capture mkdir "$documentation"
    
    di "Directory structure created successfully."
}

********************************************************************************
** 2. DATA CLEANING 
********************************************************************************
if $run_clean == 1 {
    di "Starting data cleaning process..."
    
    * 2a. Clean monthly permit data from text files
    di "Cleaning permit data from text files..."
    do "$projdir/code/scripts_plex_reforms/1_data_cleaning/1a_permit_data_cleaning.do"
    
    * 2b. Clean monthly permit data from Excel files
    di "Cleaning permit data from Excel files..."
    do "$projdir/code/scripts_plex_reforms/1_data_cleaning/1b_permit_data_cleaning_excel.do"
    
    * 2c. Harmonize text files
    di "Harmonizing text files..."
    do "$projdir/code/scripts_plex_reforms/1_data_cleaning/1c_text_file_harmonizing.do"
    
    * 2d. Process population data
    di "Processing population data..."
    do "$projdir/code/scripts_plex_reforms/1_data_cleaning/1d_population_data.do"
    
    * 2e. Process WRLURI data
    di "Processing WRLURI data..."
    do "$projdir/code/scripts_plex_reforms/1_data_cleaning/1e_wrluri_data.do"
    
    di "Data cleaning completed."
}

********************************************************************************
** 3. DESCRIPTIVE ANALYSIS
********************************************************************************
if $run_describe == 1 {
    di "Starting descriptive analysis..."
    
    * 3a. Basic permit statistics
    di "Generating permit statistics..."
    do "$projdir/code/scripts_plex_reforms/2_descriptive/2_permit_desc.do"
    
    * 3b. Aggregate to yearly level
    di "Aggregating to yearly level..."
    do "$projdir/code/scripts_plex_reforms/2_descriptive/2b_yearly_data.do"
    
    * 3c. Descriptive statistics for yearly data
    di "Generating yearly statistics..."
    do "$projdir/code/scripts_plex_reforms/2_descriptive/2c_yearly_desc.do"
    
    * 3d. Test parallel trends assumption
    di "Testing parallel trends..."
    do "$projdir/code/scripts_plex_reforms/2_descriptive/2d_parallel_trends.do"
    
    di "Descriptive analysis completed."
}

********************************************************************************
** 4. MAIN ANALYSIS
********************************************************************************
if $run_main_analysis == 1 {
    di "Starting main analysis..."
    
    * 4a. Simple difference-in-differences models
    di "Running simple DiD models..."
    do "$projdir/code/scripts_plex_reforms/3_analysis/3_simple_did.do"
    
    * 4b. DiD models with treatment intensity
    di "Running DiD models with intensity..."
    do "$projdir/code/scripts_plex_reforms/3_analysis/4_did_intensity.do"
    
    * 4c. Yearly regression specifications
    di "Running yearly regressions..."
    do "$projdir/code/scripts_plex_reforms/3_analysis/5_yearly_regressions.do"
    
    di "Main analysis completed."
}

********************************************************************************
** 5. EVENT STUDIES
********************************************************************************
if $run_event_studies == 1 {
    di "Starting event studies..."
    
    * 5a. Analyze changes in permit activity
    di "Analyzing delta permits..."
    do "$projdir/code/scripts_plex_reforms/4_event_studies/7_delta_permits.do"
    
    * 5b. Run event study specifications
    di "Running event studies..."
    do "$projdir/code/scripts_plex_reforms/4_event_studies/8_event_studies.do"
    
    di "Event studies completed."
}

********************************************************************************
** 6. CITY-SPECIFIC ANALYSIS
********************************************************************************
if $run_city_analysis == 1 {
    di "Starting city-specific analysis..."
    
    * Minneapolis
    di "Analyzing Minneapolis..."
    do "$projdir/code/scripts_plex_reforms/5_city_specific/minneapolis.do"
    do "$projdir/code/scripts_plex_reforms/5_city_specific/minneapolis_bldg_permits.do"
    
    * Other cities
    di "Analyzing other cities..."
    do "$projdir/code/scripts_plex_reforms/5_city_specific/charlottesville.do"
    do "$projdir/code/scripts_plex_reforms/5_city_specific/durham.do"
    do "$projdir/code/scripts_plex_reforms/5_city_specific/portland.do"
    do "$projdir/code/scripts_plex_reforms/5_city_specific/raleigh.do"
    do "$projdir/code/scripts_plex_reforms/5_city_specific/san_francisco.do"
    do "$projdir/code/scripts_plex_reforms/5_city_specific/spokane.do"
    do "$projdir/code/scripts_plex_reforms/5_city_specific/walla_walla.do"
    
    di "City-specific analysis completed."
}

********************************************************************************
** 7. ROBUSTNESS CHECKS
********************************************************************************
if $run_robustness == 1 {
    di "Starting robustness checks..."
    
    * 7a. Create visualizations of treated cities
    di "Creating treated city graphs..."
    do "$projdir/code/scripts_plex_reforms/6_robustness/6_treated_city_graphs.do"
    
    * 7b. Monthly visualizations
    di "Creating monthly visualizations..."
    do "$projdir/code/scripts_plex_reforms/6_robustness/6b_treated_city_graphs_monthly.do"
    
    di "Robustness checks completed."
}

********************************************************************************
** WRAP UP
********************************************************************************
di "Analysis pipeline completed successfully."
di "Runtime: $S_TIME"
di "Date: $S_DATE"

* Close log
log close