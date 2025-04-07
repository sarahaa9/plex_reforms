/*==============================================================================
City-specific Analysis: Spokane, WA
Author: Sarah R Aaronson
Date: March 2025
Purpose: Calculate treatment intensity for Spokane based on the comprehensive
         zoning reform that expanded middle housing options in residential
         zones, effective August 1, 2022
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
* Import Spokane parcel data
import delimited using "${area_data}/spokane_parcels.csv", clear

* Keep only city of Spokane parcels and exclude zero-acre parcels
keep if city == "Spokane"
drop if acreage == 0

* Drop unneeded variables
drop elementary middle high council commdist floodzone hazsoils hazgeology trashpickup

* Create simplified zone designation
generate zone_short = substr(zoning, 1, 3)
replace zone_short = subinstr(zone_short, ",", "", .)
replace zone_short = substr(zone_short, 1, length(zone_short)-1) if substr(zone_short, -1, 1) == "-"
drop if zone_short == "Out"

/*------------------------------------------------------------------------------
                      2. IDENTIFY RESIDENTIAL ZONES
------------------------------------------------------------------------------*/
* Identify residential zones
gen res = inlist(zone_short, "R1", "R2", "RA", "RMF", "RHD")

/*------------------------------------------------------------------------------
                     3. CALCULATE DENSITY CHANGES
------------------------------------------------------------------------------*/
* Calculate starting density based on zone type and lot size
gen start_density = .
replace start_density = 1 if inlist(zone_short, "R1", "RA")
replace start_density = 2 if zone_short == "R2"
replace start_density = floor(30 * acreage) if zone_short == "RMF"

* Calculate square footage for building area calculations
gen sq_footage = 43560 * acreage

* Calculate residential area for RHD zone
gen res_area_pre_rhd = 2 * 0.85 * 0.8 * sq_footage // 80% lot coverage, 15% circulation, FAR of 2
replace start_density = floor(res_area_pre_rhd / 410) if zone_short == "RHD" // 410 sq ft average unit size

* Import parcels near centers and corridors
tempfile main
save `main'

import delimited using "${area_data}/spokane_parcels_near_CC.csv", clear
keep objectid
gen near_cc = 1
tempfile near_cc
save `near_cc'

* Import parcels near transit
import delimited using "${area_data}/spokane_parcels_near_transit.csv", clear
keep objectid
gen near_transit = 1
tempfile near_transit
save `near_transit'

* Merge location data back to main dataset
use `main', clear
merge 1:1 objectid using `near_cc'
drop _merge
merge 1:1 objectid using `near_transit'

* Handle missing values for location variables
replace near_transit = 0 if missing(near_transit)
replace near_cc = 0 if missing(near_cc)

* Calculate ending density based on reform rules
gen end_density = .
* Key reform: Allow up to 4 units in residential zones near transit or centers/corridors
replace end_density = 4 if res == 1 & (near_transit == 1 | near_cc == 1)
replace end_density = 2 if res == 1 & missing(end_density) // Default to duplex elsewhere

* Calculate building footprint post-reform
gen bldg_footprint_post = sq_footage * 0.85 // 85% usable after circulation

* Calculate residential area post-reform for multi-family zones
gen res_area_post_rmf = 4 * bldg_footprint_post // 4 stories of residential space
gen res_area_post_rhd = 5 * bldg_footprint_post // 5 stories of residential space

* Calculate units based on average unit size
gen units_post_rmf = res_area_post_rmf / 410
gen units_post_rhd = res_area_post_rhd / 410

* Verify that parking requirements can be met
assert units_post_rmf < 3 * bldg_footprint_post / 300 if zone_short == "RMF"
assert units_post_rhd < 4 * bldg_footprint_post / 300 if zone_short == "RHD"

* Assign ending density for multi-family zones
replace end_density = units_post_rhd if zone_short == "RHD"
replace end_density = units_post_rmf if zone_short == "RMF"

* Ensure transit/centers-adjacent properties get at least 4 units
replace end_density = 4 if res == 1 & (near_transit == 1 | near_cc == 1) & end_density < 4 & ///
                         (zone_short == "RHD" | zone_short == "RMF")

* Rural area stays at 1 unit
replace end_density = 1 if zone_short == "RA"

* Calculate weight (density change ratio)
gen weight = end_density / start_density

* Flag non-residential parcels
replace weight = -1 if res == 0

/*------------------------------------------------------------------------------
                     4. CALCULATE INTENSITY MEASURE
------------------------------------------------------------------------------*/
* Calculate total residential area
egen tot_res_area = total(acreage) if res == 1

* Calculate each parcel's percentage of total residential land
gen res_percent = acreage / tot_res_area if res == 1

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
return scalar cbsa_code = 44060
return scalar reform_date = "8/1/2022"

* Save processed data for potential further analysis
save "${area_data}/spokane_parcels_zoning", replace