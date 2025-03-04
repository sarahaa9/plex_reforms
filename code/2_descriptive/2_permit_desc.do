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


set scheme modern
/******************************************************************************
*                      Merging Population and Permit Data                     *
******************************************************************************/

use "${permits_processed}/left_hand", clear
replace msa = subinstr(msa, ",", "", 1)


replace states = regexs(2) if regexm(msa, "^(.*?)( [A-Z]{2}(?:-[A-Z]{2})*)$") & missing(states)
replace states = trim(states)

replace primary_state = substr(states, 1, 2) if missing(primary_state)

* Find the position of the hyphen in the first 7 characters
replace hyphen_pos = strpos(substr(msa, 1, 7), "-") if missing(hyphen_pos)

* Generate the variable with all characters before the hyphen
replace msa_prefix = substr(msa, 1, hyphen_pos - 1) if hyphen_pos > 0 & missing(msa_prefix)


replace msa_cut = substr(msa, 1, 7) if missing(msa_cut)
replace msa_cut = msa_prefix if !missing(msa_prefix)


* Find the position of the first space
replace space_pos = strpos(msa, " ") if missing(space_pos)

* Generate the variable with everything before the first space
replace name_prefix = substr(msa, 1, space_pos - 1) if space_pos > 0 & missing(name_prefix)

replace msa_cut = name_prefix if length(msa) <= 7
replace msa_cut = subinstr(msa_cut, ",", "", 1)
replace msa_cut = trim(msa_cut)

merge m:1 msa_cut primary_state using "${processed}/population"

gen total_n                = total / (census2010 / 1e5)
gen one_unit_n             = one_unit / (census2010 / 1e5)
gen two_unit_n             = two_unit / (census2010 / 1e5)
gen three_four_unit_n      = three_four_unit / (census2010 / 1e5)
gen five_plus_unit_n       = five_plus_unit / (census2010 / 1e5)
gen five_plus_structures_n = five_plus_structures / (census2010 / 1e5)

/******************************************************************************
*                         Marking Treated Observations                        *
******************************************************************************/

gen treated = 0
gen in_treatment_group = 0
gen treated_year = 0

replace treated = 1 if cbsa == 41860 & t > ym(2022, 10) // San Francisco
replace treated_year = 1 if cbsa == 41860 & year > 2022
replace in_treatment_group = 1 if cbsa == 41860

replace treated = 1 if cbsa == 12060 & t > ym(2023, 5) // Decatur is in the Atlanta metropolitan area
replace treated_year = 1 if cbsa == 12060 & year > 2023
replace in_treatment_group = 1 if cbsa == 12060

replace treated = 1 if cbsa == 14260 & t >= ym(2023, 12) // Boise
replace treated_year = 1 if cbsa == 14260 & year > 2023
replace in_treatment_group = 1 if cbsa == 14260

replace treated = 1 if cbsa == 26980 & t >= ym(2024, 1) // Iowa City
replace treated_year = 1 if cbsa == 26980 & year >= 2024
replace in_treatment_group = 1 if cbsa == 26980

replace treated = 1 if cbsa == 24340 & t > ym(2019, 4) // Grand Rapids
replace treated_year = 1 if cbsa == 24340 & year > 2019
replace in_treatment_group = 1 if cbsa == 24340

replace treated = 1 if cbsa == 33460 & t >= ym(2020, 1) // Minneapolis
replace treated_year = 1 if cbsa == 33460 & year >= 2020
replace in_treatment_group = 1 if cbsa == 33460

replace treated = 1 if cbsa == 40340 & t >= ym(2023, 1) // Rochester
replace treated_year = 1 if cbsa == 40340 & year >= 2023
replace in_treatment_group = 1 if cbsa == 40340

replace treated = 1 if cbsa == 16740 & t >= ym(2023, 6) // Charlotte
replace treated_year = 1 if cbsa == 16740 & year > 2023
replace in_treatment_group = 1 if cbsa == 16740

replace treated = 1 if cbsa == 20500 & t >= ym(2019, 10) // Durham
replace treated_year = 1 if cbsa == 20500 & year > 2019
replace in_treatment_group = 1 if cbsa == 20500

replace treated = 1 if cbsa == 39580 & t > ym(2021, 8) // Raleigh
replace treated_year = 1 if cbsa == 39580 & year > 2021
replace in_treatment_group = 1 if cbsa == 39580

replace treated = 1 if cbsa == 38900 & t >= ym(2021, 8) // Portland
replace treated_year = 1 if cbsa == 38900 & year > 2021
replace in_treatment_group = 1 if cbsa == 38900

replace treated = 1 if cbsa == 47900 & t >= ym(2023, 7) // Arlington
replace treated_year = 1 if cbsa == 47900 & year > 2023
replace in_treatment_group = 1 if cbsa == 47900

replace treated = 1 if cbsa == 16820 & t > ym(2024, 2) // Charlottesville
replace treated_year = 1 if cbsa == 16820 & year > 2024
replace in_treatment_group = 1 if cbsa == 16820

replace treated = 1 if cbsa == 44060 & t >= ym(2022, 8) // Spokane
replace treated_year = 1 if cbsa == 44060 & year > 2022
replace in_treatment_group = 1 if cbsa == 44060

replace treated = 1 if cbsa == 47460 & t >= ym(2019, 1) // Walla Walla
replace treated_year = 1 if cbsa == 47460 & year >= 2019
replace in_treatment_group = 1 if cbsa == 47460

lab var total                 "Total"
lab var one_unit              "One Unit"
lab var two_unit              "Two Units"
lab var three_four_unit       "Three and Four Units"
lab var five_plus_unit        "Five+ Units"
lab var five_plus_structures  "Five+ Unit Structures"

lab var total_n                 "Total - Nor."
lab var one_unit_n              "One Unit - Nor."
lab var two_unit_n              "Two Units - Nor."
lab var three_four_unit_n       "Three and Four Units - Nor."
lab var five_plus_unit_n        "Five+ Units - Nor."
lab var five_plus_structures_n  "Five+ Unit Structures - Nor."

** Summary Statistics Table **
eststo est1: estpost tabstat total one_unit two_unit three_four_unit five_plus_unit five_plus_structures, c(stat) stat(mean sd min max n)
cap esttab using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms and Permits/summ_stats.tex", cells("mean(fmt(%13.2fc)) sd(fmt(%13.2fc)) min max count") nonumber nomtitle nonote noobs label booktabs f collabels("Mean" "SD" "Min" "Max" "N")


cap esttab using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms and Permits/summ_stats.tex", ////
             cells("mean(fmt(%6.2fc)) sd(fmt(%6.2fc)) min(fmt(%9.0f)) max(fmt(%9.0fc)) count(fmt(%9.0fc))") nonumber ///
             nomtitle nonote noobs label booktabs ///
             collabels("Mean" "SD" "Min" "Max" "N")  ///
             title("Table 1 \label{table1}")

** Summary Statistics Table - Permit Numbers Normalized by 2010 Population **

eststo est1: estpost tabstat total_n one_unit_n two_unit_n three_four_unit_n five_plus_unit_n five_plus_structures_n, c(stat) stat(mean sd min max n)

cap esttab using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms and Permits/summ_stats_nor.tex", ////
             cells("mean(fmt(%6.2fc)) sd(fmt(%6.2fc)) min(fmt(%9.0f)) max(fmt(%9.0fc)) count(fmt(%9.0fc))") nonumber ///
             nomtitle nonote noobs label booktabs f ///
             collabels("Mean" "SD" "Min" "Max" "N") replace

/******************************************************************************
*                           Summarizing Balanced Panel                        *
******************************************************************************/

bys cbsa: egen t_count = count(t)
order t year month t_count, after(msa)

label variable t_count "# of months a CBSA is observed in data"

sum t_count

bys cbsa: gen nvals = (_n == 1) if t_count == 351
egen balanced_cbsas = sum(nvals)

drop nvals
bys cbsa: gen nvals = (_n == 1)
egen total_cbsa = sum(nvals)
sum total_cbsa

gen cbsa_bal = (t_count == 351)

eststo est1: estpost tabstat total one_unit two_unit three_four_unit five_plus_unit five_plus_structures if cbsa_bal == 1, c(stat) stat(mean sd min max n)

cap esttab using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms and Permits/summ_stats_bal.tex", ////
             cells("mean(fmt(%6.2fc)) sd(fmt(%6.2fc)) min(fmt(%9.0f)) max(fmt(%9.0fc)) count(fmt(%9.0fc))") nonumber ///
             nomtitle nonote noobs label booktabs f ///
             collabels("Mean" "SD" "Min" "Max" "N")  ///
             title("Table 2 \label{table2}")

* Normalized by population
eststo est1: estpost tabstat total_n one_unit_n two_unit_n three_four_unit_n five_plus_unit_n five_plus_structures_n if cbsa_bal == 1, c(stat) stat(mean sd min max n)

cap esttab using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms and Permits/summ_stats_bal_nor.tex", ////
             cells("mean(fmt(%6.2fc)) sd(fmt(%6.2fc)) min(fmt(%9.0f)) max(fmt(%9.0fc)) count(fmt(%9.0fc))") nonumber ///
             nomtitle nonote noobs label booktabs f ///
             collabels("Mean" "SD" "Min" "Max" "N") replace

save "${processed}/permits_working_monthly.dta", replace
