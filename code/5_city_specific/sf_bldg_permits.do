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

import delimited using "${permits_raw}/sf/Building Permits Since Jan 1 2013.csv", clear

* First, ensure existingoccupancy is a string variable
tostring existingoccupancy, replace force

* Split the variable by commas
split existingoccupancy, parse(,) gen(occupancy_)


* Clean up spaces in the resulting variables
foreach var of varlist occupancy_* {
    replace `var' = trim(`var')
}

* Standardize lot numbers for numeric lots with alphabetic suffixes
gen std_block = block
gen std_lot = lot

* Extract the numeric part for lots that start with numbers but have letters
replace std_lot = regexs(1) if regexm(lot, "^([0-9]+)[A-Za-z]*$")

* Create a flag for condominium lots with CM prefix
gen condo_lot = regexm(lot, "^CM[A-Z]+$")

* Create a property identifier that handles both types appropriately
gen property_id = block + "-" + lot  // Original full identifier
gen std_property_id = block + "-" + std_lot // Standardized identifier

* First, ensure the location variable is a string
tostring location, replace force

* Extract the content inside the parentheses
gen coords = regexs(1) if regexm(location, "POINT \((.+)\)")

* Instead of using word(), which might lose precision, let's use regexm again
* to extract the exact string values for longitude and latitude
gen str15 lon_str = regexs(1) if regexm(coords, "^([-0-9.]+) ")
gen str15 lat_str = regexs(1) if regexm(coords, " ([-0-9.]+)$")

* Convert string coordinates to double precision
gen double longitude = real(lon_str)
gen double latitude = real(lat_str)

* Format to show full precision
format longitude latitude %16.9f

* Drop temporary variables
drop coords lon_str lat_str

* Label the new variables
label variable longitude "Longitude coordinate"
label variable latitude "Latitude coordinate"

* Check the first few observations with full precision displayed
list location longitude latitude in 1/5, nolabel

* Save building permits data with these new fields
save `sf_bldg_permits_prepped', replace

import delimited using "${area_data}/san_francisco_no_corners.csv", clear

ren block_num block
ren lot_num lot 

* Standardize lot numbers for numeric lots with alphabetic suffixes
gen std_block = block
gen std_lot = lot

* Extract the numeric part for lots that start with numbers but have letters
replace std_lot = regexs(1) if regexm(lot, "^([0-9]+)[A-Za-z]*$")

* Create a flag for condominium lots with CM prefix
gen condo_lot = regexm(lot, "^CM[A-Z]+$")

* Create a property identifier that handles both types appropriately
gen property_id = block + "-" + lot  // Original full identifier
gen std_property_id = block + "-" + std_lot // Standardized identifier

* First, examine the lot types in both datasets
tab lot if regexm(lot, "^CM[A-Z]+$")

* Create specific flags for common areas vs. unit designations if needed
gen common_area = inlist(lot, "CML", "CMM") // Limited common and master common areas

* Save zoning data with these same standardization fields
save `sf_zoning_prepped', replace

* Perform two merges and combine results
* First merge: Try exact matches on block and lot
merge m:1 block lot using `sf_zoning_prepped', generate(_merge_exact)

* Second merge: For non-matched records with numeric lots, try standardized lots
merge m:1 block std_lot using `sf_zoning_prepped' if _merge_exact==1, generate(_merge_std) update

* Create a final merge indicator
gen merge_status = "Exact match" if _merge_exact==3
replace merge_status = "Standardized match" if _merge_exact==1 & _merge_std==3
replace merge_status = "Not matched" if _merge_exact==1 & _merge_std!=3

* Clean up
drop _merge_exact _merge_std