/*==============================================================================
City-specific Analysis: Durham, NC
Author: Sarah R Aaronson
Date: March 2025
Purpose: Calculate treatment intensity for Durham based on the Expanding Housing
         Choices initiative that expanded middle housing options in residential
         zones, effective October 15, 2019
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
* Import Durham zoning intersection data with tier information
import delimited using "${area_data}/durham_intersection_w_tiers.csv", clear

* Rename tier variable for clarity
rename type tier

/*------------------------------------------------------------------------------
                      2. IDENTIFY RESIDENTIAL ZONES
------------------------------------------------------------------------------*/
* Identify residential zones in pre and post reform periods
gen pre_res = (inlist(udo, "PDR", "PDR 3.969", "RC", "RR", "RS-10", "RS-20", "RS-8", "RS-M", "RU-5") | ///
               inlist(udo, "RU-5(2)", "RU-M"))
               
gen post_res = (inlist(udo_2, "PDR", "PDR 3.969", "RC", "RR", "RS-10", "RS-20", "RS-8", "RS-M", "RU-5") | ///
                inlist(udo_2, "RU-5(2)", "RU-M")) | (strpos(udo_2, "PDR") > 0)

* Identify parcels that were residential in both periods
gen both_res = (pre_res == 1 & post_res == 1)

/*------------------------------------------------------------------------------
                     3. CALCULATE DENSITY CHANGES
------------------------------------------------------------------------------*/
* Initialize weight variable
gen weight = .

* Identify parcels affected by the reform based on zone and tier
gen pre_affected = ((inlist(udo, "RS-10", "RS-20", "RS-8", "RU-5") & (tier == "URBAN")) | ///
                   (udo == "RU-5" & tier == "SUBURBAN"))
                   
gen post_affected = ((inlist(udo_2, "RS-10", "RS-20", "RS-8", "RU-5") & (tier == "URBAN")) | ///
                    (udo_2 == "RU-5" & tier == "SUBURBAN"))

* Assign weights based on reform impact
* Key reform: Allow duplexes (doubling density) in affected zones
replace weight = 2 if both_res == 1 & post_affected == 1

* Flag non-residential parcels
replace weight = -1 if both_res == 0

* Assign weight of 1 to residential parcels not affected by reform
replace weight = 1 if both_res == 1 & ((pre_affected == 0 & post_affected == 0) | ///
                                       (pre_affected == 1 & post_affected == 0))

/*------------------------------------------------------------------------------
                     4. CALCULATE INTENSITY MEASURE
------------------------------------------------------------------------------*/
* Calculate total residential area
egen tot_res_area = total(area_inter) if both_res == 1

* Calculate each parcel's percentage of total residential land
gen res_percent = area_inter / tot_res_area if both_res == 1

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
global intensity = `intensity'
global cbsa = 20500
global reform_date "10/15/2019"

* Save processed data for potential further analysis
save "${area_data}/durham_parcels_zoning_pre_post", replace