* 0_consolidate_treatments.do

* Check if project directory global is already defined
if "$projdir" == "" {
    * Define project directory - modify this for your system
    if "`c(username)'" == "sarahaa" {
        global projdir "C:\Users\sarahaa\iCloudDrive\Desktop\Research\Land Use Regulation"
    }
    else if "`c(username)'" == "sarah" {
        global projdir "/Users/sarah/Desktop/Research/Land Use Regulation"
    }
    else {
        * Add more username conditions as needed
        display as error "Please define projdir in this script for your username"
        exit 198
    }
}

* Define main subdirectories based on your current structure
global raw_data "$projdir/data/raw"
global processed "$projdir/data/processed"
global graphs "$projdir/graphs"
global scripts "$projdir/scripts"
global scripts_plex_reforms "$projdir/scripts_plex_reforms"

* Define new subdirectories (these will be created)
global code "$projdir/code"
global data_cleaning "$code/scripts_plex_reforms/1_data_cleaning"
global descriptive "$code/scripts_plex_reforms/2_descriptive"
global analysis "$code/scripts_plex_reforms/3_analysis"
global event_studies "$code/scripts_plex_reforms/4_event_studies"
global city_specific "$code/scripts_plex_reforms/5_city_specific"
global robustness "$code/scripts_plex_reforms/6_robustness"

global output "$projdir/output"
global tables "$output/tables"
global figures "$output/figures"
global results "$output/results"

* Specific paths for data types
global permits_raw "$raw_data/permits" 
global permits_processed "$processed/permits"
global area_data "$processed/area"

* Optionally create directories if they don't exist
capture mkdir "$code"
capture mkdir "$data_cleaning"
capture mkdir "$descriptive" 
capture mkdir "$analysis"
capture mkdir "$event_studies"
capture mkdir "$city_specific"
capture mkdir "$robustness"
capture mkdir "$output"
capture mkdir "$tables"
capture mkdir "$figures"
capture mkdir "$results"

* Set preferences
set more off

* Create empty dataset to store treatment information
clear
set obs 0
gen cbsa = .
gen city_name = ""
gen treat_intens = .
gen reform_month = .
gen reform_year = .
gen reform_date = .
gen notes = ""
save "${processed}/treatment_intensities.dta", replace

* Loop through each city and calculate intensities
foreach city in "durham" "minneapolis" "portland" "raleigh" "san_francisco" "spokane" "walla_walla" {
    * Run city-specific calculation
    do "${code}/5_city_specific/`city'.do"
    
    * Capture the calculated intensity
    local intensity = r(intensity)
    local cbsa_code = r(cbsa_code)
    local reform_date = r(reform_date)
    
    * Add to the consolidated dataset
    preserve
        clear
        set obs 1
        gen cbsa = `cbsa_code'
        gen city_name = "`city'"
        gen treat_intens = `intensity'
        gen reform_month = month(date("`reform_date'", "MDY"))
        gen reform_year = year(date("`reform_date'", "MDY"))
        gen reform_date = date("`reform_date'", "MDY")
        format reform_date %td
        gen notes = "`city' intensity calculated on `c(current_date)'"
        
        append using "${processed}/treatment_intensities.dta"
        save "${processed}/treatment_intensities.dta", replace
    restore
}

* Add metadata
label var cbsa "CBSA Code"
label var city_name "City Name"
label var treat_intens "Treatment Intensity"
label var reform_month "Reform Month"
label var reform_year "Reform Year"
label var reform_date "Reform Date"
label var notes "Notes"

* Export to Excel for reference
export excel using "${output}/tables/treatment_intensities.xlsx", firstrow(variables) replace

* Return the dataset for immediate use
use "${processed}/treatment_intensities.dta", clear