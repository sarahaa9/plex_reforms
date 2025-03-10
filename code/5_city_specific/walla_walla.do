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

/* import delimited using "/Users/sarah/Desktop/Research/Land Use Regulation/processed/area/walla_walla_pre_area.csv", clear

order area, after(zone_desc)

collapse (sum) area, by(zone_code_)

gen year = 2013

tempfile pre
sa `pre'

import delimited using "/Users/sarah/Desktop/Research/Land Use Regulation/processed/area/walla_walla_post_area.csv", clear

order area, after(zone_code_)

collapse (sum) area, by(zone_code_)

gen year = 2024

tempfile post
sa `post'


import delimited using "/Users/sarah/Desktop/Research/Land Use Regulation/processed/area/walla_walla_post_area_clipped.csv", clear

order area, after(zone_code_)

collapse (sum) area, by(zone_code_)

gen year = 2024
gen clipped = 1

append using `pre' `post'

gen residential = inlist(zone_code_, "R-60", "R-72", "R-96", "RM", "RN")

format area %12.2f

bys year clipped: egen total_res = total(area) if residential == 1


gen percent_res = area / total_res 


import delimited using "/Users/sarah/Desktop/Research/Land Use Regulation/processed/area/walla_walla_joined.csv", clear

gen same_zone = (zone_code_ == zone_code__2)
gen upzoned = (inlist(zone_code_, "R-60", "R-72", "R-96")) & (inlist(zone_code__2, "RN", "RM"))
gen downzoned = (zone_code_ == "RM") & (zone_code__2 == "RN")

gen sketchy = (same_zone + upzoned + downzoned == 0)
 */
/***************************************************************************************************************************************/

import delimited using "${processed}/area/walla_walla_intersection.csv", clear

order zoneid zoneid_2 zone_code_ zone_code__2 area area_2 area_intersect

sort zoneid area_intersect

duplicates tag zoneid, generate(dup)

order dup

count if dup == 1
count if dup == 1 & area_intersect < 1

gen area_acres = area_intersect / 43560

gen rm_max_units_pre = floor(area_acres * 26)
gen rm_max_units_post = floor(area_acres * 75)

gen start_density = .
replace start_density = 1 if inlist(zone_code_, "R-60", "R-72", "R-96")
replace start_density = rm_max_units_pre if zone_code_ == "RM"

gen end_density = .
replace end_density = 4 if zone_code__2 == "RN"
replace end_density = rm_max_units_post if zone_code__2 == "RM"

gen same_zone = (zone_code_ == zone_code__2)
gen upzoned = (inlist(zone_code_, "R-60", "R-72", "R-96")) & (inlist(zone_code__2, "RN", "RM"))
gen downzoned = (zone_code_ == "RM") & (zone_code__2 == "RN")

gen sketchy = (same_zone + upzoned + downzoned == 0)

count if dup == 1 & area_intersect < 1 & sketchy == 1
count if dup == 1 & area_intersect >= 1 & sketchy == 1
sum area_intersect if dup == 1 & area_intersect >= 1 & sketchy == 1

gen weight = .
replace weight = 4 if inlist(zone_code_, "R-60", "R-72", "R-96") & zone_code__2 == "RN"

count if !inlist(zone_code_, "R-60", "R-72", "R-96", "RM")


sum rm_max_units_pre if zone_code_ == "RM"

replace weight = rm_max_units_post / rm_max_units_pre if zone_code_ == "RM" & zone_code__2 == "RM"
replace weight = 4 / rm_max_units_pre if zone_code_ == "RM" & zone_code__2 == "RN"
replace weight = rm_max_units_post if inlist(zone_code_, "R-60", "R-72", "R-96") & zone_code__2 == "RM"

replace weight = -1 if inlist(zone_code_, "CC", "CH", "IH", "IL", "PR", "UPC") | inlist(zone_code__2, "CC", "CH", "IH", "IL", "MHC", "PR", "UPC")

replace weight = -1 if rm_max_units_pre == 0 & ((zone_code_ == "RM" & zone_code__2 == "RM") | (zone_code_ == "RM" & zone_code__2 == "RN"))

** percent of residential land
gen res = (inlist(zone_code_, "R-60", "R-72", "R-96", "RM") & inlist(zone_code__2, "RM", "RN"))
egen tot_res_area = total(area_intersect) if res == 1

gen res_percent = area_intersect / tot_res_area if res == 1
gen percent_x_weight = res_percent * weight if weight != -1

egen intensity = total(percent_x_weight)

** intensity without multi-family

gen res_no_rm = (inlist(zone_code_, "R-60", "R-72", "R-96") & inlist(zone_code__2, "RN"))
egen tot_res_area_no_rm = total(area_intersect) if res_no_rm == 1

gen res_percent_no_rm = area_intersect / tot_res_area_no_rm if res_no_rm == 1
gen percent_x_weight_no_rm = res_percent_no_rm * weight if weight != -1 & res_no_rm == 1

egen intensity_no_rm = total(percent_x_weight_no_rm)
sum intensity_no_rm

sum intensity
local intensity = r(mean)

return scalar intensity = `intensity'
return scalar cbsa_code = 47460
return scalar reform_date = "1/2/2019"
