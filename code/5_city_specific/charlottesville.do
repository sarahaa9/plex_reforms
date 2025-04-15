/*==============================================================================
City-specific Analysis: Charlottesville, VA
Author: Sarah R Aaronson
Date: March 2025
Purpose: Calculate treatment intensity for Charlottesville based on the
         comprehensive zoning reform that expanded housing options citywide,
         effective February 19, 2024
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
* Import Charlottesville zoning intersection data
import delimited using "${area_data}/charlottesville_intersection.csv", clear

* Rename variables for consistency
ren zoning zoning_post
ren zoning_code zoning_pre

/*------------------------------------------------------------------------------
                      2. IDENTIFY RESIDENTIAL ZONES
------------------------------------------------------------------------------*/
* Identify pre-reform residential zones
gen pre_res = (strpos(zoning_pre, "R-1") | strpos(zoning_pre, "R-2") | ///
               strpos(zoning_pre, "R-3") | inlist(zoning_pre, "MR", "UHD", "UMD"))

* Identify post-reform residential zones
gen post_res = (inlist(zoning_post, "R-A", "R-B", "R-C", "RN-A"))

* Identify parcels that were residential in both periods
gen both_res = (pre_res & post_res)

/*------------------------------------------------------------------------------
                     3. CALCULATE DENSITY CHANGES
------------------------------------------------------------------------------*/
* Calculate starting density based on zone type
gen start_density = .
replace start_density = 1 if strpos(zoning_pre, "R-1")
replace start_density = 2 if strpos(zoning_pre, "R-2")

* Calculate density based on acreage for certain zones
gen acres = area_intersection * 0.000247105
replace start_density = 21 * acres if strpos(zoning_pre, "R-3") | zoning_pre == "MR"
replace start_density = 64 * acres if zoning_pre == "UHD"
replace start_density = 43 * acres if zoning_pre == "UMD"

* Ensure minimum density of 1 unit
replace start_density = 1 if start_density < 1

* Calculate ending density based on zone type
gen end_density = .
replace end_density = 3 if zoning_post == "R-A"  // Allow up to triplex
replace end_density = 6 if zoning_post == "R-B"  // Medium density
replace end_density = 8 if zoning_post == "R-C"  // Higher density
replace end_density = 1 if zoning_post == "RN-A" // Neighborhood residential

* Calculate weight (density change ratio)
gen weight = end_density / start_density

* Flag non-residential parcels
replace weight = -1 if both_res == 0

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

* Check for missing weights (should be 0)
count if missing(weight)

/*------------------------------------------------------------------------------
                     5. RETURN TREATMENT DATA
------------------------------------------------------------------------------*/
* Return values for consolidation script
global intensity = `intensity'
global cbsa = 16820
global reform_date "2/19/2024"

di in red "reform date is ${reform_date}"
pause

* Save processed data for potential further analysis
save "${area_data}/charlottesville_parcels_zoning", replace