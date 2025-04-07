/*==============================================================================
City-specific Analysis: Minneapolis, MN
Author: Sarah R Aaronson
Date: March 2025
Purpose: Calculate treatment intensity for Minneapolis based on zoning changes
         from the 2040 Comprehensive Plan that allowed triplexes in all
         residential zones, effective January 1, 2020
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
* Import pre-reform parcel data (2018)
import excel using "${area_data}/minneapolis_pre_parcels.xlsx", clear firstrow

* Clean PIN identifier
destring APN, generate(pin_clean)
drop APN
format pin_clean %13.0f
rename pin_clean pin

* Save pre-reform data
tempfile pre
save `pre'

* Import post-reform parcel data (2020)
import delimited using "${area_data}/minneapolis_post_parcels.csv", clear

* Clean PIN identifier to match pre-reform data
generate pin_clean = subinstr(pin, "p", "", 1)
destring pin_clean, generate(pin_clean2)
drop pin_clean pin
rename pin_clean2 pin

* Merge pre and post reform data
merge 1:1 pin using `pre'

* Format PIN and check merge quality
format pin %13.0f

* Verify address matches to confirm correct parcel matching
replace ST_NAME_2018 = "" if ST_NAME_2018 == street_nam
replace ANUMBER_2018 = "" if ANUMBER_2018 == house_no

* Check merge quality
gen looks_good = (missing(ANUMBER_2018) & missing(ST_NAME_2018) & _merge == 3) 
sum looks_good // Should be close to 1.0 for good merge quality

/*------------------------------------------------------------------------------
                      2. IDENTIFY RESIDENTIAL ZONES
------------------------------------------------------------------------------*/
* Rename zoning variables for clarity
rename ZONING_2018 zoning_pre
rename zoning zoning_post

* Identify residential zones pre and post reform
gen pre_res = inlist(zoning_pre, "R1", "R1A", "R2", "R2B", "R3", "R4", "R5", "R6")
gen post_res = inlist(zoning_post, "R1", "R1A", "R2", "R2B", "R3", "R4", "R5", "R6")
gen both_res = (pre_res == 1 & post_res == 1)

/*------------------------------------------------------------------------------
                     3. CALCULATE DENSITY CHANGES
------------------------------------------------------------------------------*/
* Clean area variable
destring PARCEL_ARE_2018, replace

* Calculate starting density (pre-reform) based on zoning and lot size
gen start_density = .
replace start_density = 1 if inlist(zoning_pre, "R1", "R1A")
replace start_density = 2 if inlist(zoning_pre, "R2", "R2B")
replace start_density = floor(PARCEL_ARE_2018 / 1500) if zoning_pre == "R3"
replace start_density = floor(PARCEL_ARE_2018 / 1250) if zoning_pre == "R4"
replace start_density = floor(PARCEL_ARE_2018 * 2 * 0.8 / 220) if zoning_pre == "R5" // FAR of 2, 20% circulation, 220 sq ft per unit
replace start_density = floor(PARCEL_ARE_2018 * 3 * 0.8 / 220) if zoning_pre == "R6" // FAR of 3, 20% circulation, 220 sq ft per unit

* Calculate ending density (post-reform) based on zoning and lot size
gen end_density = .
replace end_density = 3 if inlist(zoning_post, "R1", "R1A", "R2", "R2B") // Main policy change: allow up to 3 units
replace end_density = floor(parcel_are / 1500) if zoning_post == "R3"
replace end_density = floor(parcel_are / 1250) if zoning_post == "R4"
replace end_density = floor(parcel_are * 2 * 0.8 / 220) if zoning_post == "R5" // FAR of 2, 20% circulation, 220 sq ft per unit
replace end_density = floor(parcel_are * 3 * 0.8 / 220) if zoning_post == "R6" // FAR of 3, 20% circulation, 220 sq ft per unit

* Calculate weight (density change ratio)
gen weight = end_density / start_density

* Handle special cases and non-residential properties
replace both_res = 0 if landuse == "VACANT LAND" & LANDUSE_2018 == "VACANT LAND" & (start_density == 0 | end_density == 0)
replace both_res = 0 if landuse == "GARAGE OR MISC RESID STRU" & LANDUSE_2018 == "GARAGE OR MISC RESID STRU" & start_density == 0 & end_density == 0
replace both_res = 0 if missing(parcel_are) | missing(PARCEL_ARE_2018)

* Handle edge cases in land use classification
replace both_res = 0 if start_density == 0 & end_density == 0 & landuse == "GROUP RESIDENCE" & LANDUSE_2018 == "GROUP RESIDENCE"
replace both_res = 0 if start_density == 0 & end_density == 0 & landuse == "COMMON AREA" & LANDUSE_2018 == "COMMON AREA"
replace both_res = 0 if start_density == 0 & end_density == 0 & landuse == "SPORT OR RECREATION FAC" & LANDUSE_2018 == "SPORT OR RECREATION FAC"
replace both_res = 0 if start_density == 0 & landuse == "SINGLE-FAMILY ATTACHED DW" & LANDUSE_2018 == "MULTI-FAMILY RESIDENTIAL"

* Fix single-family attached dwellings with missing density
replace start_density = 1 if LANDUSE_2018 == "SINGLE-FAMILY ATTACHED DW" & start_density == 0 & inlist(zoning_pre, "R3", "R4")
replace end_density = 1 if landuse == "SINGLE-FAMILY ATTACHED DW" & end_density == 0 & inlist(zoning_post, "R3", "R4")

* Flag non-residential zones
replace weight = -1 if both_res == 0

/*------------------------------------------------------------------------------
                     4. CALCULATE INTENSITY MEASURE
------------------------------------------------------------------------------*/
* Calculate total residential area
egen tot_res_area = total(PARCEL_ARE_2018) if both_res == 1

* Calculate each parcel's percentage of total residential land
gen res_percent = PARCEL_ARE_2018 / tot_res_area if both_res == 1

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
return scalar cbsa_code = 33460
return scalar reform_date = "1/1/2020"

* Save processed data for potential further analysis
save "${area_data}/mpls_parcels_zoning_pre_post", replace