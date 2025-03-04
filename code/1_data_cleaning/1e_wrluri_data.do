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

use "/Users/sarah/Downloads/WRLURI_01_15_2020.dta", clear

* First, collapse WRLURI to CBSA level by taking average
collapse (mean) WRLURI18, by(cbsacode18)

* Save CBSA-level WRLURI scores
tempfile wrluri_cbsa
save `wrluri_cbsa'

* Merge back to your main dataset
use main_data, clear
merge m:1 cbsa using `wrluri_cbsa'

* Create WRLURI quartiles/groups
xtile wrluri_group = wrluri_score, nq(4)

* Only keep control CBSAs in same WRLURI quartile as treated CBSAs
bysort wrluri_group: egen any_treated = max(ever_treated)
keep if ever_treated == 1 | (ever_treated == 0 & any_treated == 1)

* Run your main specification on this subset
reghdfe permits100k treatment_intensity, absorb(cbsa_id year) cluster(cbsa_id)