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

use "${permits_processed}/appended_permit_data_1", clear



// Create a new variable without the last character if it's an asterisk
gen msa_no_asterisk = cond(substr(msa, length(msa), 1) == "*", substr(msa, 1, length(msa) - 1), msa)
drop msa
ren msa_no_asterisk msa

order msa


// Split the string variable into two separate variables
split msa, parse(" ") gen(msa_part)

* removing more asterisks
forvalues i = 1(1)11{
	replace msa_part`i' = cond(substr(msa_part`i', length(msa_part`i'), 1) == "*", substr(msa_part`i', 1, length(msa_part`i') - 1), msa_part`i')
}

order msa_part*, after(msa)

replace msa_part1 = "" if msa_part1 == msa_part2
replace msa_part1 = msa_part2 if missing(msa_part1)

* removing redundant naming, i.e. Abilene Abilene TX MSA should get rid of one of the Abilenes
forvalues i = 2(1)10{
	local j = `i' - 1
	local k = `i' + 1
	replace msa_part`i' = "" if msa_part`i' == msa_part`j'
	replace msa_part`i' = msa_part`k' if missing(msa_part`i') & msa_part`k' != msa_part`j'
	
	replace msa_part`k' = "" if msa_part`k' == msa_part`j'
}

replace msa_part11 = "" if msa_part11 == msa_part10

missings dropvars _all, force

gen msa_clean = msa_part1 + " " + msa_part2 + " " + msa_part3 + " " + msa_part4 + " " + msa_part5 + " " + msa_part6 + " " + msa_part7 + " " + msa_part8
order msa_clean, after(msa)

pause


drop msa msa_part*
ren msa_clean msa


replace msa = trim(msa) // removing leading and trailing spaces

* Generate the indicator variable
gen is_pmsa = 0

* Use regular expressions to identify the variations of PMSA
replace is_pmsa = 1 if regexm(msa, "^(.*?)( P\s*M\s*S\s*A$)")

gen is_cmsa = 0
replace is_cmsa = 1 if regexm(msa, "^(.*?)( C\s*M\s*S\s*A$)")

replace msa = subinstr(msa, "PMSA", "", 1)
replace msa = subinstr(msa, "PMS", "", 1)
replace msa = subinstr(msa, "PMS A", "", 1)
replace msa = subinstr(msa, "PM SA", "", 1)
replace msa = subinstr(msa, "CMSA", "", 1)
replace msa = subinstr(msa, "CMS", "", 1)
replace msa = subinstr(msa, "MSA", "", 1)
replace msa = subinstr(msa, ",", "", 1)

pause

// Calculate mean, max, and min for each msa
by msa, sort: egen mean_csa = mean(csa)
by msa: egen max_csa = max(csa)
by msa: egen min_csa = min(csa)

order *_csa, after(msa)

// Check if mean, max, and min are the same
gen same_mean_max_min = (mean_csa == max_csa & mean_csa == min_csa)

// Generate the new csa based on the condition
gen new_csa = cond(same_mean_max_min, mean_csa, .)
order csa new_csa, after(msa)

drop mean_csa max_csa min_csa same_mean_max_min csa
ren new_csa csa

// Calculate mean, max, and min for each msa
by msa, sort: egen mean_cbsa = mean(cbsa)
by msa: egen max_cbsa = max(cbsa)
by msa: egen min_cbsa = min(cbsa)

// Check if mean, max, and min are the same
gen same_mean_max_min = (mean_cbsa == max_cbsa & mean_cbsa == min_cbsa)

// Generate the new cbsa based on the condition
gen new_cbsa = cond(same_mean_max_min, mean_cbsa, .)
order cbsa new_cbsa, after(msa)

drop mean_cbsa max_cbsa min_cbsa same_mean_max_min cbsa
ren new_cbsa cbsa

replace msa = strtrim(msa) // collapses multiple consecutive spaces between words into a single space

drop if inlist(msa, "Alabama", "Alaska", "Arkansas", "Arizona", "California", "Hawaii", "Idaho", "Washington", "Oregon") | inlist(msa, "Montana", "Nevada", "New Mexico", "Colorado", "Utah", "Wyoming", "South Dakota", "North Dakota", "Nebraska") | ///
		inlist(msa, "Kansas", "Oklahoma", "Texas", "Michigan", "Illinois", "Wisconsin", "Iowa", "Indiana", "Missouri") | inlist(msa, "Kentucky", "Tennessee", "Mississippi", "Georgia", "North Carolina", "South Carolina", "Virginia", "West Virginia", "Massachusetts") | ///
		inlist(msa, "Maine", "Vermont", "New Hampshire", "New York", "Rhode Island", "Connecticut", "New Jersey", "Pennsylvania", "Florida") | inlist(msa, "Ohio", "Louisiana", "Maryland", "Delaware", "Minnesota", "District of Columbia", "Virgin Islands", "Puerto Rico")

*strgroup msa, generate(new_msa) threshold(0.2) force
/*
replace new_msa = 7 if msa == "Albany OR"
replace new_msa = 678 if msa == "Anderson SC"
replace new_msa = 18 if strpos(msa, "Anniston-Oxford")
replace new_msa = 21 if strpos(msa, "Appleton")
replace new_msa = 26 if strpos(msa, "Athens") & strpos(msa, "GA")
replace new_msa = 28 if strpos(msa, "Atlanta") & strpos(msa, "GA")
*/

drop if strpos(msa, "Balance of State") | strpos(msa, "Maine Unorganized Territory")
replace msa = cond(substr(msa, length(msa), 1) == "-", substr(msa, 1, length(msa) - 1), msa) // removes hyphens at the end of strings
replace msa = cond(regexm(msa, " P$"), substr(msa, 1, length(msa) - 2), msa) // removes trailing Ps

replace msa = "Seattle-Tacoma-Bremerton WA" if msa == "Seattle-Tacoma-Bremerton WA C"
replace msa = "Milwaukee-Waukesha WI" if msa == "Milwaukee-Waukesha W I"
replace msa = "Decatur AL" if msa == "Decatur Al"
replace msa = "Detroit-Ann Arbor-Flint MI" if msa == "Detroit-Ann Arbor-Flint MI CM"
replace msa = "Portland-Vancouver OR-WA" if msa == "Portland-Vancouver OR-WA PM"
replace msa = "Middlesex-Somerset-Hunterdon NJ" if msa == "Middlesex-Somerset-Hunterdon"
replace msa = "Vineland-Millville-Bridgeton NJ" if msa == "Vineland-Millville-Bridgeton"
replace msa = "Charlotte-Gastonia-Rock Hill SC" if msa == "Charlotte-Gastonia-Rock Hill"

replace msa = "Wilmington-Newark DE-MD" if msa == "Wilmington-Newark DE -MD"
replace msa = "Orange County CA" if msa == "Orange County CA  A"
replace msa = "San Francisco CA" if msa == "San Francisco CA  A"
replace msa = "Portland-Vancouver OR-WA" if msa == "Portland-Vancouver O R-WA"
replace msa = "Clarksville-Hopkinsville TN-KY" if msa == "Clarksville-Hopkinsville TN- KY"

gen old_msa = msa

replace msa = subinstr(msa, "- ", "-", .) if regexm(msa, "[A-Z]- [A-Z]") // removing spaces between multiple state abbreviations (NY-NJ- CT-PA to NY-NJ-CT-PA)

drop if is_cmsa == 1
drop if msa == "Boston-Worcester-Lawrence MA" & year == 1998 & inlist(month, 1, 2, 3)
drop if msa == "Chicago-Gary-Kenosha IL-IN-WI" & year == 1998 & inlist(month, 1, 2, 3)
drop if msa == "Cincinnati-Hamilton OH-KY-IN" & year == 1998 & inlist(month, 1, 2, 3)
drop if msa == "Denver-Boulder-Greeley CO" & year == 1998 & inlist(month, 1, 2, 3)
drop if msa == "Detroit-Ann Arbor-Flint MI" & year == 1998 & inlist(month, 1, 2, 3)
drop if msa == "Houston-Galveston-Brazoria TX" & year == 1998 & inlist(month, 1, 2, 3)
drop if msa == "Seattle-Tacoma-Bremerton WA" & year == 1998 & inlist(month, 1, 2, 3)
drop if msa == "Washington-Baltimore DC-MD-VA" & year == 1998 & inlist(month, 1, 2, 3)
drop if msa == "New York-Northern Jersey-Long  Island NY-NJ-CT" & year >= 1995 & year <= 2003
drop if msa == "New York-Northern New Jersey-Long  Island NY-NJ-CT-PA" & year >= 1995 & year <= 2003
drop if msa == "Philadelphia-Wilmington-Atlantic City PA-NJ-DE-MD" & ((year == 2002 & month == 4) | (year == 2003 & month >= 5 & month <= 12))


generate states = regexs(2) if regexm(msa, "^(.*?)( [A-Z]{2}(?:-[A-Z]{2})*)$")
generate primary_state = substr(states, 2, 2)
tab state

* Find the position of the hyphen in the first 7 characters
gen hyphen_pos = strpos(substr(msa, 1, 7), "-")

* Generate the variable with all characters before the hyphen
gen msa_prefix = substr(msa, 1, hyphen_pos - 1) if hyphen_pos > 0

gen msa_cut = substr(msa, 1, 7)
replace msa_cut = msa_prefix if !missing(msa_prefix) // if msa_cut has a hyphen in it

* Find the position of the first space
gen space_pos = strpos(msa, " ")

* Generate the variable with everything before the first space
gen name_prefix = substr(msa, 1, space_pos - 1) if space_pos > 0

replace msa_cut = name_prefix if length(msa) <= 7
replace msa_cut = trim(msa_cut)


order msa_cut primary_state, after(msa)
egen groups = group(msa_cut primary_state)
order groups msa_cut primary_state, after(msa)
sort groups

bys groups: egen observations = total(1)

order msa groups primary_state observations

sum groups
* `r(max)'
forvalues i = 1(1)76 {
	tab msa if groups == `i'
}

replace groups = 407 if strpos(msa, "Texarkana")
replace groups = 367 if msa == "Santa Maria-Santa Barbara CA"
replace groups = 309 if msa == "Omaha NE-IA"
replace groups = 297 if msa == "Niles MI"
replace groups = 269 if msa == "Minneapolis-St. Paul MN-WI MS"
replace groups = 262 if msa == "Miami FL"
replace groups = 249 if msa == "Macon GA"
replace groups = 185 if msa == "Urban Honolulu HI"
replace groups = 164 if msa == "Grand Pass OR"
replace groups = 131 if msa == "Fargo ND-MN"
replace groups = 80 if msa == "Chico CA"
replace groups = 74 if msa == "Charlotte-Gastonia-Rock Hill SC"

bys groups: egen min_cbsa = min(cbsa)

order min_cbsa, after(cbsa)

count if min_cbsa != cbsa & !missing(cbsa)

tab groups if min_cbsa != cbsa & !missing(cbsa)
gen mult_cbsa = (min_cbsa != cbsa & !missing(cbsa))

bys groups: replace cbsa = min_cbsa if mult_cbsa == 0

save "${permits_processed}/harmonized_text_file_data", replace


append using "${permits_processed}/appended_permit_data_2", gen(source)
replace msa = trim(msa)

by cbsa groups, sort: gen unique = (_n == 1 & !missing(groups))

sum groups
local max = r(max)
local j = `max' + 1

gen cbsa_master = .
forvalues i = 1(1)`max' {
	levelsof cbsa if groups == `i', local(cbsas)
	
	scalar cbsa_count = `:word count `cbsas''
	if cbsa_count == 1{
		continue
	}
	
	if cbsa_count == 0{
		replace cbsa = `j' if groups == `i'
		local ++j
		continue
	}
	
	
	foreach c of local cbsas{
		replace cbsa_master = (source == 1 & cbsa == `c')
		bys cbsa: egen master = max(cbsa_master)
		sum master if cbsa == `c'
		if r(mean) == 1{
			local cbsa_master = `c'
		}
		drop master
	}
	
	
	replace cbsa = `cbsa_master' if groups == `i'
}

gen t = ym(year, month)

duplicates tag cbsa t, gen(dup)
tab msa if dup >= 1 & !missing(cbsa)



xtset cbsa t

save "${permits_processed}/left_hand", replace





