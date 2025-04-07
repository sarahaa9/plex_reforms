/*==============================================================================
City-specific Analysis: Portland, OR
Author: Sarah R Aaronson
Date: March 2025
Purpose: Calculate treatment intensity for Portland based on the Residential
         Infill Project (RIP) that expanded missing middle housing options,
         effective August 1, 2021
==============================================================================*/

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

* Define main subdirectories
global raw_data "$projdir/data/raw"
global processed "$projdir/data/processed"
global area_data "$processed/area"

* Set preferences
set more off

/*------------------------------------------------------------------------------
                           1. DATA PREPARATION
------------------------------------------------------------------------------*/
* Import Portland zoning intersection data with pre/post reform zones
import delimited using "${area_data}/portland_intersection.csv", clear

* Rename variables for consistency
rename zone zoning_pre
rename zone_2 zoning_post

/*------------------------------------------------------------------------------
                      2. IDENTIFY RESIDENTIAL ZONES
------------------------------------------------------------------------------*/
* Identify residential zones in pre and post reform periods
gen pre_res = (inlist(zoning_pre, "R10", "R2.5", "R20", "R5", "R7", "RF", "RM1", "RM2", "RM3") | ///
               inlist(zoning_pre, "RM4", "RMP", "RX"))
              
gen post_res = (inlist(zoning_post, "R10", "R2.5", "R20", "R5", "R7", "RF", "RM1", "RM2", "RM3") | ///
                inlist(zoning_post, "RM4", "RMP", "RX"))

* Identify parcels that were residential in both periods
gen both_res = (pre_res & post_res)

/*------------------------------------------------------------------------------
                     3. CALCULATE DENSITY CHANGES
------------------------------------------------------------------------------*/
* Calculate pre-reform density based on zone type and parcel area
gen start_density = .
replace start_density = 2 if inlist(zoning_pre, "R10", "R2.5", "R20", "R5", "R7")
replace start_density = 1 if zoning_pre == "RF"
replace start_density = area_intersection / 1500 if zoning_pre == "RMP"
* For multi-dwelling zones, calculate based on FAR and minimum unit size
replace start_density = (area_intersection * 1.5) / 231 if zoning_pre == "RM2" // 1.5 is FAR, 231 sq feet is minimum efficiency dwelling unit size
replace start_density = (area_intersection * 1) / 231 if zoning_pre == "RM1"
replace start_density = (area_intersection * 2) / 231 if zoning_pre == "RM3"
replace start_density = (area_intersection * 4) / 231 if zoning_pre == "RM4" // FAR of 3 in historic zones
replace start_density = (area_intersection * 4) / 231 if zoning_pre == "RX" 

* Calculate post-reform density based on zone type and parcel area
gen end_density = .
* Key reform: Allow up to 4 units in most single-dwelling zones
replace end_density = 4 if inlist(zoning_post, "R2.5", "R5", "R7")
replace end_density = 2 if inlist(zoning_post, "R10", "R20")
replace end_density = 1 if zoning_post == "RF"
replace end_density = area_intersection / 1500 if zoning_post == "RMP"
* For multi-dwelling zones, calculate based on FAR and minimum unit size
replace end_density = (area_intersection * 1.5) / 231 if zoning_post == "RM2" // 1.5 is FAR, 231 sq feet is minimum efficiency dwelling unit size
replace end_density = (area_intersection * 1) / 231 if zoning_post == "RM1"
replace end_density = (area_intersection * 2) / 231 if zoning_post == "RM3"
replace end_density = (area_intersection * 4) / 231 if zoning_post == "RM4" // FAR of 3 in historic zones
replace end_density = (area_intersection * 4) / 231 if zoning_post == "RX"

* Calculate weight (density change ratio)
gen weight = end_density / start_density

* Flag non-residential parcels
replace weight = -1 if both_res == 0

* Handle very small parcels (likely data errors)
replace weight = -1 if area_intersection < 1 & missing(weight)
replace weight = -1 if area_intersection < 1 // robustness check

* Check for any missing weights (should be 0)
count if missing(weight)

/*------------------------------------------------------------------------------
                     4. CALCULATE INTENSITY MEASURE
------------------------------------------------------------------------------*/
* Calculate total residential area
egen tot_res_area = total(area_intersection) if both_res == 1

* Calculate each parcel's percentage of total residential land
gen res_percent = area_intersection / tot_res_area if both_res == 1

* Calculate weighted percentage (key intensity metric)
gen percent_x_weight = res_percent * weight if weight != -1

* Calculate overall intensity measure
egen intensity = total(percent_x_weight)
sum intensity
local intensity = r(mean)

/*------------------------------------------------------------------------------
                     5. RETURN TREATMENT DATA
------------------------------------------------------------------------------*/
* Return values for consolidation script
return scalar intensity = `intensity'
return scalar cbsa_code = 38900
return scalar reform_date = "8/1/2021"

* Save processed data for potential further analysis
save "${area_data}/portland_parcels_zoning_pre_post", replace