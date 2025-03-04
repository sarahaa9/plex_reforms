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

import excel using "$processed}/area/minneapolis_pre_parcels.xlsx", clear firstrow

destring APN, generate(apn_clean2)
drop APN
format apn_clean2 %13.0f

ren apn_clean2 pin

ren * *_2018
ren pin_2018 pin

tempfile pre
sa `pre'

import delimited using "${processed}/area/minneapolis_post_parcels.csv", clear

generate pin_clean = subinstr(pin, "p", "", 1)
order pin_clean, after(pin)
destring pin_clean, generate(pin_clean2)
drop pin_clean pin

rename pin_clean2 pin

merge 1:1 pin using `pre'

format pin %13.0f

replace ST_NAME_2018 = "" if ST_NAME_2018 == street_nam

order ANUMBER_2018, after(house_no)
replace ANUMBER_2018 = "" if ANUMBER_2018 == house_no

count if missing(ANUMBER_2018)                                       // 130,943
count if missing(ST_NAME_2018)                                       // 130,924
count if _merge == 3                                                 // 130,376
count if missing(ANUMBER_2018) & missing(ST_NAME_2018) & _merge == 3 // 130,290

gen looks_good = (missing(ANUMBER_2018) & missing(ST_NAME_2018) & _merge == 3) 
sum looks_good // mean = 0.9890385

order zoning ZONING_2018, after(pin)

count if zoning != ZONING_2018 // 3,154

gen pre_res = inlist(ZONING_2018, "R1", "R1A", "R2", "R2B", "R3", "R4", "R5", "R6")
gen post_res = inlist(zoning, "R1", "R1A", "R2", "R2B", "R3", "R4", "R5", "R6")

ren ZONING_2018 zoning_pre
ren zoning zoning_post
gen both_res = (pre_res == 1 & post_res == 1)

destring PARCEL_ARE_2018, replace

gen start_density = .
replace start_density = 1 if inlist(zoning_pre, "R1", "R1A")
replace start_density = 2 if inlist(zoning_pre, "R2", "R2B")
replace start_density = floor(PARCEL_ARE_2018 / 1500) if zoning_pre == "R3"
replace start_density = floor(PARCEL_ARE_2018 / 1250) if zoning_pre == "R4"
replace start_density = floor(PARCEL_ARE_2018 * 2 * 0.8 / 220) if zoning_pre == "R5" // FAR of 2, 20% of floor area for circulation/common spaces, 220 sq ft for 2-person dwelling unit
replace start_density = floor(PARCEL_ARE_2018 * 3 * 0.8 / 220) if zoning_pre == "R6" // FAR of 3, 20% of floor area for circulation/common spaces, 220 sq ft for 2-person dwelling unit



gen end_density = .
replace end_density = 3 if inlist(zoning_post, "R1", "R1A", "R2", "R2B")
replace end_density = floor(parcel_are / 1500) if zoning_post == "R3"
replace end_density = floor(parcel_are / 1250) if zoning_post == "R4"
replace end_density = floor(parcel_are * 2 * 0.8 / 220) if zoning_post == "R5" // FAR of 2, 20% of floor area for circulation/common spaces, 220 sq ft for 2-person dwelling unit
replace end_density = floor(parcel_are * 3 * 0.8 / 220) if zoning_post == "R6" // FAR of 3, 20% of floor area for circulation/common spaces, 220 sq ft for 2-person dwelling unit


gen weight = end_density / start_density

replace both_res = 0 if landuse == "VACANT LAND" & LANDUSE_2018 == "VACANT LAND" & (start_density == 0 | end_density == 0)
replace both_res = 0 if landuse == "GARAGE OR MISC RESID STRU" & LANDUSE_2018 == "GARAGE OR MISC RESID STRU" & start_density == 0 & end_density == 0
replace both_res = 0 if missing(parcel_are) | missing(PARCEL_ARE_2018)

* edge cases
replace both_res = 0 if start_density == 0 & end_density == 0 & landuse == "GROUP RESIDENCE" & LANDUSE_2018 == "GROUP RESIDENCE"
replace both_res = 0 if start_density == 0 & end_density == 0 & landuse == "COMMON AREA" & LANDUSE_2018 == "COMMON AREA"
replace both_res = 0 if start_density == 0 & end_density == 0 & landuse == "SPORT OR RECREATION FAC" & LANDUSE_2018 == "SPORT OR RECREATION FAC"
replace both_res = 0 if start_density == 0 & landuse == "SINGLE-FAMILY ATTACHED DW" & LANDUSE_2018 == "MULTI-FAMILY RESIDENTIAL"

replace start_density = 1 if LANDUSE_2018 == "SINGLE-FAMILY ATTACHED DW" & start_density == 0 & inlist(zoning_pre, "R3", "R4")
replace end_density = 1 if landuse == "SINGLE-FAMILY ATTACHED DW" & end_density == 0 & inlist(zoning_post, "R3", "R4")

replace weight = -1 if both_res == 0

** percent of residential land
egen tot_res_area = total(PARCEL_ARE_2018) if both_res == 1

gen res_percent = PARCEL_ARE_2018 / tot_res_area if both_res == 1
gen percent_x_weight = res_percent * weight if weight != -1

egen intensity = total(percent_x_weight)
sum intensity

save "${processed}/area/mpls_parcels_zoning_pre_post", replace


