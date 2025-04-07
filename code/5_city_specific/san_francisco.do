/*==============================================================================
City-specific Analysis: San Francisco, CA
Author: Sarah R Aaronson
Date: March 2025
Purpose: Calculate treatment intensity for San Francisco based on Ordinance
         154-22 that allowed fourplexes citywide in residential districts,
         effective October 28, 2022
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
* Import San Francisco zoning data (excluding corner parcels for accuracy)
import delimited using "${area_data}/san_francisco_no_corners.csv", clear

/*------------------------------------------------------------------------------
                      2. IDENTIFY RESIDENTIAL ZONES
------------------------------------------------------------------------------*/
* Identify residential zones
gen res = (inlist(zoning_code, "RH-1(D)", "RH-1", "RH-1(S)", "RH-2", "RH-3", "RM-1", "RM-2", "RM-3", "RM-4") | ///
          inlist(zoning_code, "RTO", "RTO-M", "RH-DTR", "SB-DTR", "TB-DTR"))

/*------------------------------------------------------------------------------
                     3. CALCULATE DENSITY CHANGES
------------------------------------------------------------------------------*/
* Assign weights based on zone type
* Key reform: Allow up to 4 units (quadrupling density) in previously single-family zones
gen weight = 4 if inlist(zoning_code, "RH-1(D)", "RH-1", "RH-1(S)", "RH-2", "RH-3")

* Flag non-residential parcels
replace weight = -1 if res != 1

* Higher density zones already allowed multi-units, less impact from reform
replace weight = 1 if res == 1 & missing(weight)

/*------------------------------------------------------------------------------
                     4. CALCULATE INTENSITY MEASURE
------------------------------------------------------------------------------*/
* Calculate total residential area
egen tot_res_area = total(area) if res == 1

* Calculate each parcel's percentage of total residential land
gen res_percent = area / tot_res_area if res == 1

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
return scalar cbsa_code = 41860
return scalar reform_date = "10/28/2022"

* Save processed data for potential further analysis
save "${area_data}/san_francisco_parcels_zoning", replace