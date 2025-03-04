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

import delimited using "${processed}/area/richfield_intersection.csv", clear

duplicates tag zoning zoning_2 area_intersection street house_numb, generate(dup)
duplicates drop zoning zoning_2 area_intersection street house_numb, force

drop zoning_pre
ren zoning zoning_pre
ren zoning_2 zoning_post

order zoning_pre zoning_post area_intersection


gen pre_res = (inlist(zoning_pre, "MR-1", "MR-2", "MR-2/CAC", "MR-3", "PMR", "R", "R-1"))
gen post_res = (inlist(zoning_post, "MR-2", "MR-3", "PMR", "R", "R-1"))

gen both_res = (pre_res & post_res)

gen start_density = .
replace start_density = 2 if inlist(zoning_pre, "MR-1")
replace start_density = 1 if inlist(zoning_pre, "R", "R-1")
replace start_density = 8 if inlist(zoning_pre, "MR-2/CAC", "MR-2")
replace start_density = 20 if inlist(zoning_pre, "MR-3", "PMR")

gen end_density = .
replace end_density = 8 if inlist(zoning_post, "MR-2")
replace end_density = 20 if inlist(zoning_post, "MR-3", "PMR")
replace end_density = 2 if inlist(zoning_post, "R")
replace end_density = 1 if zoning_post == "R-1"


gen weight = end_density / start_density
replace weight = -1 if both_res == 0
*eplace weight = -1 if area_intersection < 1 & missing(weight)

count if missing(weight)

** percent of residential land
egen tot_res_area = total(area_intersection) if both_res == 1

gen res_percent = area_intersection / tot_res_area if both_res == 1
gen percent_x_weight = res_percent * weight if weight != -1

egen intensity = total(percent_x_weight)
sum intensity