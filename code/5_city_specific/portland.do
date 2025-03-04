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

import delimited using "${processed}/area/portland_intersection.csv", clear

ren zone zoning_pre
ren zone_2 zoning_post

order zoning_pre zoning_post area_intersection
order zoning_post zoning_pre area_intersection


gen pre_res = (inlist(zoning_pre, "R10", "R2.5", "R20", "R5", "R7", "RF", "RM1", "RM2", "RM3") | inlist(zoning_pre, "RM4", "RMP", "RX"))
gen post_res = (inlist(zoning_post, "R10", "R2.5", "R20", "R5", "R7", "RF", "RM1", "RM2", "RM3") | inlist(zoning_post, "RM4", "RMP", "RX"))

gen both_res = (pre_res & post_res)

gen start_density = .
replace start_density = 2 if inlist(zoning_pre, "R10", "R2.5", "R20", "R5", "R7")
replace start_density = 1 if zoning_pre == "RF"
replace start_density = area_intersection / 1500 if zoning_pre == "RMP"
replace start_density = (area_intersection * 1.5) / 231 if zoning_pre == "RM2" // 1.5 is FAR, 231 sq feet is minimum efficiency dwelling unit size: 190 for habitable area, 6 for closet, 35 for bathroom (based on Claude)
replace start_density = (area_intersection * 1) / 231 if zoning_pre == "RM1"
replace start_density = (area_intersection * 2) / 231 if zoning_pre == "RM3"
replace start_density = (area_intersection * 4) / 231 if zoning_pre == "RM4" // FAR of 3 in historic zones
replace start_density = (area_intersection * 4) / 231 if zoning_pre == "RX" 


gen end_density = .
replace end_density = 4 if inlist(zoning_post, "R2.5", "R5", "R7")
replace end_density = 2 if inlist(zoning_post, "R10", "R20")
replace end_density = 1 if zoning_post == "RF"
replace end_density = area_intersection / 1500 if zoning_post == "RMP"
replace end_density = (area_intersection * 1.5) / 231 if zoning_post == "RM2" // 1.5 is FAR, 231 sq feet is minimum efficiency dwelling unit size: 190 for habitable area, 6 for closet, 35 for bathroom (based on Claude)
replace end_density = (area_intersection * 1) / 231 if zoning_post == "RM1"
replace end_density = (area_intersection * 2) / 231 if zoning_post == "RM3"
replace end_density = (area_intersection * 4) / 231 if zoning_post == "RM4" // FAR of 3 in historic zones
replace end_density = (area_intersection * 4) / 231 if zoning_post == "RX"

gen weight = end_density / start_density
replace weight = -1 if both_res == 0
replace weight = -1 if area_intersection < 1 & missing(weight)
replace weight = -1 if area_intersection < 1 // robustness

count if missing(weight)

** percent of residential land
egen tot_res_area = total(area_intersection) if both_res == 1

gen res_percent = area_intersection / tot_res_area if both_res == 1
gen percent_x_weight = res_percent * weight if weight != -1

egen intensity = total(percent_x_weight)
sum intensity