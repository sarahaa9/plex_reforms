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

forvalues y = 2019(1)2024{
	foreach m in 01 02 03 04 05 06 07 08 09 10 11 12{
		
		if `y' == 2019 & `m' < 11{
			continue
		}
		
		if `y' == 2024 & `m' >= 05{
			continue
		}
		
		if `y' == 2024{
			import excel using "${permits_raw}/cbsamonthly_`y'`m'", cellrange(A8:Q377) firstrow clear
		}
		else{
			import excel using "${permits_raw}/msamonthly_`y'`m'", cellrange(A8:Q377) firstrow clear
		}
		
		missings dropobs _all, force
		
		gen year = `y'
		gen month = `m'
		
		if `y' < 2022 | `y' == 2024{
		
			ren L total_ytd
			ren M one_unit_ytd
			ren N two_unit_ytd
			ren O three_four_unit_ytd
			ren P five_plus_unit_ytd
			ren Q five_plus_structures_ytd
			
		}
		
		if `y' >= 2022 & `y' != 2024{
			ren K total_ytd
			ren L one_unit_ytd
			ren M two_unit_ytd
			ren N three_four_unit_ytd
			ren O five_plus_unit_ytd
			ren P five_plus_structures_ytd
		}
			
		ren Total total
		ren Unit one_unit
		ren Units two_unit
		ren and4Units three_four_unit
		ren UnitsorMore five_plus_unit
		ren NumofStructuresWith5Unitso five_plus_structures
		
		
		missings dropvars _all, force
		
		tempfile permits_`y'`m'
		sa `permits_`y'`m''
		
	}
}

use `permits_201911', clear

forvalues y = 2019(1)2024{
	foreach m in 01 02 03 04 05 06 07 08 09 10 11 12{
		if `y' == 2019 & `m' <= 11{
			continue
		}
		if `y' == 2024 & `m' >= 05{
			continue
		}
		append using `permits_`y'`m''
	}
}

ren MonthlyCoveragePercent month_cov_percent
ren CSA csa
ren CBSA cbsa
ren Name msa

save "${permits_processed}/appended_permit_data_2", replace
	