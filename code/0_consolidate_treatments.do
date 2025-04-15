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
global code "$projdir/plex_reforms/code"
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
gen reform_date = ""
gen reform_date_num = .
gen notes = ""
save "${processed}/treatment_intensities.dta", replace

* Loop through each city and calculate intensities
foreach city in "charlottesville" "durham" "minneapolis" "portland" "raleigh" "san_francisco" "spokane" "walla_walla" {
    * Display progress
    display as text "Processing `city'..."
    
    * Run city-specific calculation
    noisily do "${code}/5_city_specific/`city'.do"

    * Capture the calculated intensity
    local intensity = ${intensity}
    local cbsa_code = ${cbsa}
    local reform_date ${reform_date}

    * Check if script executed successfully
    if _rc != 0 {
        display as error "Error running `city'.do: " _rc
        continue
    }
    
    * Check if values were returned properly
    if missing(`intensity') {
        display as error "Error: No intensity value returned from `city'.do"
        continue
    }
    
    if missing(`cbsa_code') {
        display as error "Error: No CBSA code returned from `city'.do"
        continue
    }
    
    if "`reform_date'" == "" {
        display as error "Error: No reform date returned from `city'.do"
        continue
    }
    
    * Add to the consolidated dataset
    preserve
        clear
        set obs 1
        gen cbsa = `cbsa_code'
        gen city_name = "`city'"
        gen treat_intens = `intensity'
        gen reform_date = "`reform_date'"

        di in red "reform date is `reform_date'"
        pause
        
        * Parse date components
        gen reform_month = month(date("`reform_date'", "MDY"))
        gen reform_year = year(date("`reform_date'", "MDY"))
        gen reform_date_num = date("`reform_date'", "MDY")
        format reform_date_num %td
        
        gen notes = "`city' intensity calculated on `c(current_date)'"
        
        * Display city information
        display as result "City: `city', CBSA: `cbsa_code', Intensity: `intensity', Reform date: `reform_date'"
        
        append using "${processed}/treatment_intensities.dta"
        save "${processed}/treatment_intensities.dta", replace
    restore
}

* Add metadata
use "${processed}/treatment_intensities.dta", clear

* Label variables
label var cbsa "CBSA Code"
label var city_name "City Name"
label var treat_intens "Treatment Intensity"
label var reform_month "Reform Month"
label var reform_year "Reform Year"
label var reform_date "Reform Date (String)"
label var reform_date_num "Reform Date (Stata Date)"
label var notes "Notes"

* Add a data note explaining the intensity measure
notes treat_intens: "Treatment intensity measures the weighted average increase in density allowed by zoning reform. A value of 2 means density doubled on average, 3 means tripled, etc."

* Export to Excel for reference
export excel using "${output}/tables/treatment_intensities.xlsx", firstrow(variables) replace

display as result "Treatment intensities consolidated successfully!"
display as result "Results saved to ${processed}/treatment_intensities.dta"

* Return the dataset for immediate use
use "${processed}/treatment_intensities.dta", clear