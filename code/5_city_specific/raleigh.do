/*==============================================================================
City-specific Analysis: Raleigh, NC
Author: Sarah R Aaronson
Date: March 2025
Purpose: Calculate treatment intensity for Raleigh based on the Text Change
         TC-5-20 that allowed duplexes in most residential zones,
         effective August 5, 2021
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
* Import Raleigh zoning data
import delimited using "${area_data}/raleigh.csv", clear

/*------------------------------------------------------------------------------
                      2. IDENTIFY RESIDENTIAL ZONES
------------------------------------------------------------------------------*/
* Identify residential zones
gen res = (inlist(zone_type, "R-1", "R-2", "R-4", "R-6", "R-10"))

/*------------------------------------------------------------------------------
                     3. CALCULATE DENSITY CHANGES
------------------------------------------------------------------------------*/
* Initialize weight variable
gen weight = .

* Assign weights based on zone type
* Non-residential zones
replace weight = -1 if inlist(zone_type, "AP", "CM", "CMP", "CX-", "DX-", "IH", "IX-", "MH", "NX-") | ///
                      inlist(zone_type, "OP-", "OX-", "PD", "RX-")

* Residential zones - doubling density in most zones
replace weight = 2 if inlist(zone_type, "R-2", "R-4", "R-6", "R-10") // Allow duplexes
replace weight = 1 if zone_type == "R-1" // No change in R-1

* Verify all zones have been assigned a weight
count if missing(weight)

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

* Check for missing weights (should be 0)
count if missing(weight)

/*------------------------------------------------------------------------------
                     5. RETURN TREATMENT DATA
------------------------------------------------------------------------------*/
* Return values for consolidation script
global intensity = `intensity'
global cbsa = 39580
global reform_date "8/5/2021"

* Save processed data for potential further analysis
save "${area_data}/raleigh_parcels_zoning", replace