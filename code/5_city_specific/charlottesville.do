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

import delimited using "${processed}/area/charlottesville_intersection.csv", clear

ren zoning zoning_post
ren zoning_code zoning_pre

order zoning_post zoning_pre area_intersection

drop zone

gen pre_res = (strpos(zoning_pre, "R-1") | strpos(zoning_pre, "R-2") | strpos(zoning_pre, "R-3") | inlist(zoning_pre, "MR", "UHD", "UMD"))
gen post_res = (inlist(zoning_post, "R-A", "R-B", "R-C", "RN-A"))

gen both_res = (pre_res & post_res)

gen start_density = .
replace start_density = 1 if strpos(zoning_pre, "R-1")
replace start_density = 2 if strpos(zoning_pre, "R-2")
gen acres = area_intersection * 0.000247105
replace start_density = 21 * acres if strpos(zoning_pre, "R-3") | zoning_pre == "MR"
replace start_density = 64 * acres if zoning_pre == "UHD"
replace start_density = 43 * acres if zoning_pre == "UMD"

replace start_density = 1 if start_density < 1

gen end_density = .
replace end_density = 3 if zoning_post == "R-A"
replace end_density = 6 if zoning_post == "R-B"
replace end_density = 8 if zoning_post == "R-C"
replace end_density = 1 if zoning_post == "RN-A"

gen weight = end_density / start_density

order *_res weight, after(area_intersection)

sum weight

replace weight = -1 if both_res == 0

** percent of residential land
egen tot_res_area = total(area_intersection) if both_res == 1

gen res_percent = area_intersection / tot_res_area if both_res == 1
gen percent_x_weight = res_percent * weight if weight != -1

egen intensity = total(percent_x_weight)
sum intensity

count if missing(weight)