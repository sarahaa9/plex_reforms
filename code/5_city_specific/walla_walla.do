/*==============================================================================
City-specific Analysis: Walla Walla, WA
Author: Sarah R Aaronson
Date: March 2025
Purpose: Calculate treatment intensity for Walla Walla based on the
         Residential Code Update that expanded middle housing options in
         residential zones, effective January 2, 2019
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
* Import Walla Walla zoning intersection data
import delimited using "${area_data}/walla_walla_intersection.csv", clear

* Review data structure and key variables
order zoneid zoneid_2 zone_code_ zone_code__2 area area_2 area_intersect

* Identify duplicate zone IDs
sort zoneid area_intersect
duplicates tag zoneid, generate(dup)
order dup

* Convert area to acres for density calculations
gen area_acres = area_intersect / 43560

/*------------------------------------------------------------------------------
                      2. IDENTIFY RESIDENTIAL ZONES
------------------------------------------------------------------------------*/
* Identify zone transitions
gen same_zone = (zone_code_ == zone_code__2)
gen upzoned = (inlist(zone_code_, "R-60", "R-72", "R-96")) & (inlist(zone_code__2, "RN", "RM"))
gen downzoned = (zone_code_ == "RM") & (zone_code__2 == "RN")
gen sketchy = (same_zone + upzoned + downzoned == 0)

/*------------------------------------------------------------------------------
                     3. CALCULATE DENSITY CHANGES
------------------------------------------------------------------------------*/
* Calculate pre-reform density based on zone type
gen start_density = .
replace start_density = 1 if inlist(zone_code_, "R-60", "R-72", "R-96")

* Calculate RM zone capacity (26 units per acre pre-reform)
gen rm_max_units_pre = floor(area_acres * 26)
replace start_density = rm_max_units_pre if zone_code_ == "RM"

* Calculate post-reform density based on zone type
gen end_density = .
replace end_density = 4 if zone_code__2 == "RN" // Neighborhood Residential

* Calculate RM zone capacity (75 units per acre post-reform)
gen rm_max_units_post = floor(area_acres * 75)
replace end_density = rm_max_units_post if zone_code__2 == "RM"

* Calculate weight (density change ratio)
gen weight = .
replace weight = 4 if inlist(zone_code_, "R-60", "R-72", "R-96") & zone_code__2 == "RN"
replace weight = rm_max_units_post / rm_max_units_pre if zone_code_ == "RM" & zone_code__2 == "RM"
replace weight = 4 / rm_max_units_pre if zone_code_ == "RM" & zone_code__2 == "RN"
replace weight = rm_max_units_post if inlist(zone_code_, "R-60", "R-72", "R-96") & zone_code__2 == "RM"

* Flag non-residential and problematic zones
replace weight = -1 if inlist(zone_code_, "CC", "CH", "IH", "IL", "PR", "UPC") | ///
                      inlist(zone_code__2, "CC", "CH", "IH", "IL", "MHC", "PR", "UPC")
replace weight = -1 if rm_max_units_pre == 0 & ((zone_code_ == "RM" & zone_code__2 == "RM") | ///
                                               (zone_code_ == "RM" & zone_code__2 == "RN"))

/*------------------------------------------------------------------------------
                     4. CALCULATE INTENSITY MEASURE
------------------------------------------------------------------------------*/
* Identify all residential zones
gen res = (inlist(zone_code_, "R-60", "R-72", "R-96", "RM") & inlist(zone_code__2, "RM", "RN"))

* Calculate total residential area
egen tot_res_area = total(area_intersect) if res == 1

* Calculate each parcel's percentage of total residential land
gen res_percent = area_intersect / tot_res_area if res == 1

* Calculate weighted percentage (key intensity metric)
gen percent_x_weight = res_percent * weight if weight != -1

* Calculate overall intensity measure
egen intensity = total(percent_x_weight)

* Calculate intensity without multi-family (as a robustness check)
gen res_no_rm = (inlist(zone_code_, "R-60", "R-72", "R-96") & inlist(zone_code__2, "RN"))
egen tot_res_area_no_rm = total(area_intersect) if res_no_rm == 1
gen res_percent_no_rm = area_intersect / tot_res_area_no_rm if res_no_rm == 1
gen percent_x_weight_no_rm = res_percent_no_rm * weight if weight != -1 & res_no_rm == 1
egen intensity_no_rm = total(percent_x_weight_no_rm)

* Get final intensity value
sum intensity
local intensity = r(mean)

/*------------------------------------------------------------------------------
                     5. RETURN TREATMENT DATA
------------------------------------------------------------------------------*/
* Return values for consolidation script
return scalar intensity = `intensity'
return scalar cbsa_code = 47460
return scalar reform_date = "1/2/2019"

* Save processed data for potential further analysis
save "${area_data}/walla_walla_parcels_zoning", replace