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

import delimited using "${processed}/area/raleigh.csv", clear


gen weight = .
replace weight = -1 if inlist(zone_type, "AP", "CM", "CMP", "CX-", "DX-", "IH", "IX-", "MH", "NX-") | inlist(zone_type, "OP-", "OX-", "PD", "RX-")
replace weight = 2 if inlist(zone_type, "R-2", "R-4", "R-6", "R-10")
replace weight = 1 if zone_type == "R-1"

gen res = (inlist(zone_type, "R-2", "R-4", "R-6", "R-10", "R-1"))

** percent of residential land
egen tot_res_area = total(area) if res == 1

gen res_percent = area / tot_res_area if res == 1
gen percent_x_weight = res_percent * weight if weight != -1

egen intensity = total(percent_x_weight)
sum intensity
local intensity = r(mean)

return scalar intensity = `intensity'
return scalar cbsa_code = 39580
return scalar reform_date = "8/5/2021"