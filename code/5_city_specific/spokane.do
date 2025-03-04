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

import delimited using "${processed}/area/spokane_parcels.csv", clear

keep if city == "Spokane"
drop if acreage == 0

drop elementary middle high council commdist floodzone hazsoils hazgeology trashpickup

generate zone_short = substr(zoning, 1, 3)
replace zone_short = subinstr(zone_short, ",", "", .)

replace zone_short = substr(zone_short, 1, length(zone_short)-1) if substr(zone_short, -1, 1) == "-"

drop if zone_short == "Out"


gen res = inlist(zone_short, "R1", "R2", "RA", "RMF", "RHD")

gen start_density = .
replace start_density = 1 if inlist(zone_short, "R1", "RA")
replace start_density = 2 if zone_short == "R2"
replace start_density = floor(30 * acreage) if zone_short == "RMF"

gen sq_footage = 43560 * acreage
gen bldg_footprint_pre_rhd = 0.85 * 0.8 * sq_footage // 80% lot coverage, 15% of building for stairs and circulation
gen res_area_pre_rhd = 2 * bldg_footprint_pre_rhd // 35 ft height limit,  first floor: 12 feet (allowing for commercial-grade construction) 
                                  // upper floors: 10 feet each, remaining 3 feet for roof structure/parapet, one floor going to parking
gen units_pre_rhd = res_area_pre_rhd / 410 // Unit Mix for Market Viability and Code Compliance: 70% Studio units (350 sq ft), 30% 1-bedroom units (550 sq ft)
drop bldg_footprint_pre_rhd


replace start_density = floor(units_pre_rhd) if zone_short == "RHD"

tempfile main
sa `main'

import delimited using "${processed}/area/spokane_parcels_near_CC.csv", clear

keep objectid
gen near_cc = 1

tempfile near_cc
sa `near_cc'

import delimited using "${processed}/area/spokane_parcels_near_transit.csv", clear

keep objectid
gen near_transit = 1

tempfile near_transit
sa `near_transit'

use `main', clear

merge 1:1 objectid using `near_cc'

drop _merge

merge 1:1 objectid using `near_transit'

replace near_transit = 0 if missing(near_transit)
replace near_cc = 0 if missing(near_cc)

gen end_density = .
replace end_density = 4 if res == 1 & (near_transit == 1 | near_cc == 1)
replace end_density = 2 if res == 1 & missing(end_density)

gen bldg_footprint_post = sq_footage * 0.85 // Minus required circulation/exit stairs (15%)

/*
Above Ground Configuration:

55 feet allows 5 stories
1 story for parking + 4 stories residential
Usable area per floor = 37,026 sq ft
Residential area: 4 stories × 37,026 = 148,104 sq ft
*/

gen res_area_post_rmf = 4 * bldg_footprint_post
/*
Parking Capacity:


Underground: 2 levels × 37,026 = 74,052 sq ft
Above ground: 1 level × 37,026 = 37,026 sq ft
Total parking area: 111,078 sq ft
Total parking spaces: 111,078 ÷ 300 = 370 spaces available


Unit Calculation (limited by parking):


Can support 370 units (1:1 parking ratio)
Space needed: 370 units × 410 sq ft = 151,700 sq ft
This fits within our 148,104 sq ft of residential space


Open Space Required:


370 units × 56.1 sq ft = 20,757 sq ft
Can be accommodated through:

Ground level spaces around building
Rooftop amenity spaces
Balconies/private spaces



Therefore, with a mix of underground and above-ground parking, the maximum density would be 370 units per acre. This is more realistic than full underground parking while still achieving significant density.
This seems like a more feasible scenario balancing:

Construction costs (2 underground levels vs 4)
Efficient use of height limit
Meeting all parking requirements
Providing required open space

*/

gen units_post_rmf = res_area_post_rmf / 410
assert units_post_rmf < 3 * bldg_footprint_post / 300 if zone_short == "RMF"

/*
Yes, let's calculate RHD density with the new standards from the table:
Key Changes for RHD:

75 ft height limit (up from 35 ft)
100% lot coverage (up from 80%)
No maximum density
Similar open space requirements to RMF
Same parking requirement (1 per unit)

Let's calculate using 1 acre (43,560 sq ft):

Building Configuration:


75 ft allows 7 stories (12 ft ground + 6×10 ft upper + 3 ft roof)
Need parking + residential stories
Let's try 2 above ground + 2 underground parking, leaving 5 residential stories
*/

/*
Residential Space Available:


5 stories × 37,026 = 185,130 sq ft

*/

gen res_area_post_rhd = 5 * bldg_footprint_post

/*
Parking Capacity:


4 total levels × 37,026 = 148,104 sq ft for parking
148,104 ÷ 300 = 493 parking spaces available


Unit Calculation:


185,130 ÷ 410 sq ft per unit = 451 units
Parking is sufficient (493 spaces > 451 needed)


Open Space Required:


Using same unit mix (70% studio, 30% 1-bed)
(70% × 48 sq ft) + (30% × 75 sq ft) = 56.1 sq ft average
451 units × 56.1 = 25,301 sq ft
Can be accommodated through combination of:

Ground level spaces
Rooftop amenity spaces
Balconies/private spaces



Therefore, maximum density in post-reform RHD would be 451 units per acre with:

5 stories residential
2 stories above ground parking
2 stories underground parking
Adequate parking spaces
Required open space

This is significantly higher than pre-reform RHD (144 units/acre) due to:

Greater height allowance (75 ft vs 35 ft)
Increased lot coverage (100% vs 80%)
More efficient parking configuration possible with taller building
*/

gen units_post_rhd = res_area_post_rhd / 410
assert units_post_rhd < 4 * bldg_footprint_post / 300 if zone_short == "RHD"

replace end_density = units_post_rhd if zone_short == "RHD"
replace end_density = units_post_rmf if zone_short == "RMF"

replace end_density = 4 if res == 1 & (near_transit == 1 | near_cc == 1) & end_density < 4 & (zone_short == "RHD" | zone_short == "RMF")

replace end_density = 1 if zone_short == "RA"


gen weight = end_density / start_density

replace weight = -1 if res == 0

** percent of residential land
egen tot_res_area = total(acreage) if res == 1

gen res_percent = acreage / tot_res_area if res == 1
gen percent_x_weight = res_percent * weight if weight != -1

egen intensity = total(percent_x_weight)
sum intensity