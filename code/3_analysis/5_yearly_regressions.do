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

eststo clear

/* I.2. User-Invariant File Paths */

global nrun = "drop_nt_for_dynamic_did"
global usets = 1

// timestamp
local date : display %tdCY-N-D date(c(current_date), "DMY")
local time : display %tcHH-MM-SS clock(c(current_time), "hms")
global timestamp = "`date'_`time'"
noi di "Timestamp of this run: ${timestamp}"
if $usets == 1 {
    global stamp = "${timestamp}__${nrun}"
}
else {
    global stamp = "${nrun}"
} 

use "${processed}/permits_working_yearly.dta", clear

label var treated "Treatment Dummy"

gen multi_unit_n = total_n - one_unit_n
gen multi_unit = total - one_unit

* First, create Census division variable if you don't have one
* You'll need to map state FIPS or state abbreviations to Census divisions
gen census_division = 1 if strpos(states, "ME") | strpos(states, "NH") | strpos(states, "VT") | strpos(states, "MA") | strpos(states, "RI") | strpos(states, "CT") // New England
replace census_division = 2 if strpos(states, "NY") | strpos(states, "PA") | strpos(states, "NJ") | strpos(states, "MD") // Mid-Atlantic
replace census_division = 3 if strpos(states, "OH") | strpos(states, "IN") | strpos(states, "IL") | strpos(states, "MI") | strpos(states, "WI") // East North Central
replace census_division = 4 if strpos(states, "IA") | strpos(states, "KS") | strpos(states, "MN") | strpos(states, "MO") | strpos(states, "NE") | ///
                             strpos(states, "ND") | strpos(states, "SD") // West North Central
replace census_division = 5 if strpos(states, "FL") | strpos(states, "GA") | strpos(states, "NC") | strpos(states, "SC") | strpos(states, "VA") | ///
                             strpos(states, "DC") | strpos(states, "DE") | strpos(states, "WV")  // South Atlantic
replace census_division = 6 if strpos(states, "AL") | strpos(states, "KY") | strpos(states, "MS") | strpos(states, "TN") // East South Central
replace census_division = 7 if strpos(states, "AR") | strpos(states, "LA") | strpos(states, "OK") | strpos(states, "TX") // West South Central
replace census_division = 8 if strpos(states, "AZ") | strpos(states, "CO") | strpos(states, "ID") | strpos(states, "MT") | strpos(states, "NV") | ///
                             strpos(states, "UT") | strpos(states, "WY")  // Mountain
replace census_division = 9 if strpos(states, "AK") | strpos(states, "CA") | strpos(states, "HI") | strpos(states, "OR") | strpos(states, "WA") // Pacific

* Create indicator for CBSAs in same divisions as treated cities
bysort census_division: egen any_treated_div = max(in_treatment_group)
/* keep if any_treated == 1

* Run your main specification on this subset
reghdfe permits100k treatment_intensity, absorb(cbsa_id year) cluster(cbsa_id)

* For neighboring states:
* First create list of states that have treated cities
levelsof state if ever_treated == 1, local(treated_states)

* Then create list of neighboring states for each treated state
* This is manual but could do something like:
gen neighbor = 1 if state == "MA" & inlist(state, "NH", "VT", "NY", "RI", "CT")
replace neighbor = 1 if state == "MI" & inlist(state, "WI", "IN", "OH")
// etc.

* Keep only treated states and their neighbors
keep if ever_treated == 1 | neighbor == 1

* Run specification
reghdfe permits100k treatment_intensity, absorb(cbsa_id year) cluster(cbsa_id) */

preserve
    use "/Users/sarah/Downloads/WRLURI_01_15_2020.dta", clear

    * First, collapse WRLURI to CBSA level by taking average
    collapse (mean) WRLURI18, by(cbsacode18)
    ren cbsacode18 cbsa

    * Save CBSA-level WRLURI scores
    tempfile wrluri_cbsa
    save `wrluri_cbsa'
restore

* Merge back to your main dataset
merge m:1 cbsa using `wrluri_cbsa'

* Create WRLURI quartiles/groups
xtile wrluri_group = WRLURI18, nq(4)


foreach y in total_n one_unit_n two_unit_n three_four_unit_n five_plus_unit_n multi_unit_n{

    if "`y'" == "total_n"{
        local title = "Total"
    }
    if "`y'" == "one_unit_n"{
        local title = "One Unit"
    }
    if "`y'" == "two_unit_n"{
        local title = "Duplex"
    }
    if "`y'" == "three_four_unit_n"{
        local title = "Tri and Fourplex"
    }
    if "`y'" == "five_plus_unit_n"{
        local title = "Five-plus Unit"
    }
    if "`y'" == "multi_unit_n"{
        local title = "Multi-Unit"
    }

    eststo clear

    qui reg `y' c.treat_intens i.cbsa i.year if year != 2024, cluster(cbsa) noomitted
    est store m1

    ** Not using the intensity
    qui reg `y' c.treated i.cbsa i.year if year != 2024, cluster(cbsa) noomitted
    est store m3

    ** Dropping the never-treated cities
    qui reg `y' c.treat_intens i.cbsa i.year if in_treatment_group == 1 & year != 2024, cluster(cbsa) noomitted
    est store m4

    ** Matching on WRLURI index
    * Only keep control CBSAs in same WRLURI quartile as treated CBSAs
    preserve
        bysort wrluri_group: egen any_treated = max(in_treatment_group)
        keep if in_treatment_group == 1 | (in_treatment_group == 0 & any_treated == 1)

        * Run your main specification on this subset
        qui reg `y' c.treat_intens i.cbsa i.year if year != 2024, cluster(cbsa)
        est store m6
    restore

    ** Only using CBSAs in the same Census division as treated CBSAs as controls
    preserve
        keep if any_treated_div == 1
        qui reg `y' c.treat_intens i.cbsa i.year if year != 2024, cluster(cbsa) noomitted
        est store m7
    restore


    * Create LaTeX table
    esttab m1 m4 m6 m7 m3 using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms Writing Sample/yearly_`title'_results_${timestamp}.tex", ///
        keep(treat_intens treated) ///
        label ///
        b(%9.3f) se(%9.3f) ///
        fragment ///
        nomtitles ///
        nonumbers ///
        nolines ///
        noconstant ///
        compress ///
        coeflabels(treat_intens "Plex Reform Intensity" treated "Binary") ///
        prefoot("") ///
        prehead("") ///
        posthead("") ///
        replace

}



*** Logs
foreach y in total one_unit two_unit three_four_unit five_plus_unit multi_unit{

    gen log_`y' = asinh(`y'_n)

    if "`y'" == "total"{
        local title = "Total"
    }
    if "`y'" == "one_unit"{
        local title = "One Unit"
    }
    if "`y'" == "two_unit"{
        local title = "Duplex"
    }
    if "`y'" == "three_four_unit"{
        local title = "Tri and Fourplex"
    }
    if "`y'" == "five_plus_unit"{
        local title = "Five-plus Unit"
    }
    if "`y'" == "multi_unit"{
        local title = "Multi-Unit"
    }

    eststo clear

    qui reg log_`y' c.treat_intens i.cbsa i.year if year != 2024, cluster(cbsa) noomitted
    est store m1

    ** Not using the intensity
    qui reg log_`y' c.treated i.cbsa i.year if year != 2024, cluster(cbsa) noomitted
    est store m3

    ** Dropping the never-treated cities
    qui reg log_`y' c.treat_intens i.cbsa i.year if in_treatment_group == 1 & year != 2024, cluster(cbsa) noomitted
    est store m4

    ** Matching on WRLURI index
    * Only keep control CBSAs in same WRLURI quartile as treated CBSAs
    preserve
        bysort wrluri_group: egen any_treated = max(in_treatment_group)
        keep if in_treatment_group == 1 | (in_treatment_group == 0 & any_treated == 1)

        * Run your main specification on this subset
        qui reg log_`y' c.treat_intens i.cbsa i.year if year != 2024, cluster(cbsa)
        est store m6
    restore

    ** Only using CBSAs in the same Census division as treated CBSAs as controls
    preserve
        keep if any_treated_div == 1
        qui reg log_`y' c.treat_intens i.cbsa i.year if year != 2024, cluster(cbsa) noomitted
        est store m7
    restore


    * Create LaTeX table
    esttab m1 m4 m6 m7 m3 using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms Writing Sample/logs_yearly_`title'_results_${timestamp}_ihs_norm.tex", ///
        keep(treat_intens treated) ///
        label ///
        b(%9.3f) se(%9.3f) ///
        fragment ///
        nomtitles ///
        nonumbers ///
        nolines ///
        noconstant ///
        compress ///
        coeflabels(treat_intens "Plex Reform Intensity" treated "Binary") ///
        prefoot("") ///
        prehead("") ///
        posthead("") ///
        replace

}