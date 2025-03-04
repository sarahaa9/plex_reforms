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

import delimited using "$processed}/area/durham_intersection_w_tiers.csv", clear

ren type tier

gen weight = .

gen pre_res = (inlist(udo, "PDR", "PDR 3.969", "RC", "RR", "RS-10", "RS-20", "RS-8", "RS-M", "RU-5") | inlist(udo, "RU-5(2)", "RU-M"))
gen post_res = (inlist(udo_2, "PDR", "PDR 3.969", "RC", "RR", "RS-10", "RS-20", "RS-8", "RS-M", "RU-5") | inlist(udo_2, "RU-5(2)", "RU-M")) | (strpos(udo_2, "PDR") > 0)

gen both_res = (pre_res == 1 & post_res == 1)

gen pre_affected = ((inlist(udo, "RS-10", "RS-20", "RS-8", "RU-5") & (tier == "URBAN")) | (udo == "RU-5" & tier == "SUBURBAN"))
gen post_affected = ((inlist(udo_2, "RS-10", "RS-20", "RS-8", "RU-5") & (tier == "URBAN")) | (udo_2 == "RU-5" & tier == "SUBURBAN"))

replace weight = 2 if (both_res == 1 & (pre_affected == 1 & post_affected == 1)) | (both_res == 1 & post_affected == 1)

order udo udo_2 weight tier

replace weight = -1 if both_res == 0
replace weight = 1 if both_res == 1 & ((pre_affected == 0 & post_affected == 0) | (pre_affected == 1 & post_affected == 0))

** percent of residential land
egen tot_res_area = total(area_inter) if both_res == 1

gen res_percent = area_inter / tot_res_area if both_res == 1
gen percent_x_weight = res_percent * weight if weight != -1

egen intensity = total(percent_x_weight)
