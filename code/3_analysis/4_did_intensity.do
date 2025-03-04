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



use "${processed}/permits_working.dta", clear

global overleaf "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms and Permits"

global dynamic_dids = "${overleaf}/Dynamic DiDs/${stamp}"

cap mkdir "${dynamic_dids}"

drop groups // was used to harmonize CBSA
drop observations msa_cut min_cbsa
drop n // for cleaning permit data
drop missings // counts non-missing values in v1
drop is_pmsa is_cmsa old_msa states hyphen_pos msa_prefix space_pos name_prefix mult_cbsa source MetroMicroCode unique cbsa_master dup _merge

/******************************************************************************
*                            Defining Control Groups                          *
******************************************************************************/

gen never_treated = (in_treatment_group == 0)

gen not_yet_treated = (treated == 0 & in_treatment_group == 1)

* treated == 0 is another control group containing both never_treated and not_yet_treated

local controls comb_treated // nyt_treated

/******************************************************************************
*                              Pooled Diff-in-Diff                            *
******************************************************************************/

* Never treated as control
gen nt_treated = .
replace nt_treated = 1 if treated == 1
replace nt_treated = 0 if never_treated == 1 // control group

* Not yet treated as control
gen nyt_treated = .
replace nyt_treated = 1 if treated == 1
replace nyt_treated = 0 if not_yet_treated == 1 // control group

lab var nyt_treated "Only Not-Yet-Treated as Controls"

* Combined control group
gen comb_treated = .
replace comb_treated = 1 if treated == 1
replace comb_treated = 0 if treated == 0

lab var comb_treated "Not-Yet-Treated and Never Treated as Controls"


/* Rough add of intensity */

gen treated_intens = .

label var treated_intens "Treatment Intensity"
label var treated "Treatment Dummy"

replace treated_intens = 3.522699 if strpos(msa, "San Francisco") & strpos(msa, "CA") & t > ym(2022, 10)
replace treated_year = 1 if strpos(msa, "San Francisco") & strpos(msa, "CA") & year > 2022
replace in_treatment_group = 1 if strpos(msa, "San Francisco") & strpos(msa, "CA")

replace treated_intens = 1.880045  if strpos(msa, "Richfield") & strpos(msa, "MN") & t > ym(2023, 1)
replace treated_year = 1 if strpos(msa, "Richfield") & strpos(msa, "MN") & year > 2023
replace in_treatment_group = 1 if strpos(msa, "Richfield") & strpos(msa, "MN")

replace treated_intens = 1.066261 if strpos(msa, "Durham") & strpos(msa, "NC") & t > ym(2019, 10)
replace treated_year = 1 if strpos(msa, "Durham") & strpos(msa, "NC") & year > 2019
replace in_treatment_group = 1 if strpos(msa, "Durham") & strpos(msa, "NC")

replace treated_intens = 1.939016 if strpos(msa, "Raleigh") & strpos(msa, "NC") & t > ym(2021, 6)
replace treated_year = 1 if strpos(msa, "Raleigh") & strpos(msa, "NC") & year > 2021
replace in_treatment_group = 1 if strpos(msa, "Raleigh") & strpos(msa, "NC")

replace treated_intens = 5.20324 if strpos(msa, "Portland") & strpos(msa, "OR") & t > ym(2020, 8)
replace treated_year = 1 if strpos(msa, "Portland") & strpos(msa, "OR") & year > 2020
replace in_treatment_group = 1 if strpos(msa, "Portland") & strpos(msa, "OR")

replace treated_intens = 3.202148 if strpos(msa, "Charlottesville") & strpos(msa, "VA") & t > ym(2021, 11)
replace treated_year = 1 if strpos(msa, "Charlottesville") & strpos(msa, "VA") & year > 2021
replace in_treatment_group = 1 if strpos(msa, "Charlottesville") & strpos(msa, "VA")

replace treated_intens = 13.89574 if strpos(msa, "Walla Walla") & strpos(msa, "WA") & t > ym(2018, 12)
replace treated_year = 1 if strpos(msa, "Walla Walla") & strpos(msa, "WA") & year > 2018
replace in_treatment_group = 1 if strpos(msa, "Walla Walla") & strpos(msa, "WA")

replace treated_intens = treated if missing(treated_intens)


/* qui reg total_n c.treated_intens##i.t i.cbsa i.t, cluster(cbsa) noomitted
est store m1

** Dropping Walla Walla
qui reg total_n c.treated_intens##i.t i.cbsa i.t if !strpos(msa, "Walla Walla"), cluster(cbsa) noomitted
est store m2

** Not using the intensity
qui reg total_n c.treated##i.t i.cbsa i.t, cluster(cbsa) noomitted
est store m3

** Dropping the never-treated cities
qui reg total_n c.treated_intens##i.t i.cbsa i.t if in_treatment_group == 1, cluster(cbsa) noomitted
est store m4

* Create LaTeX table
esttab m1 m2 m4 m3 using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms and Permits/results_${timestamp}.tex", ///
    keep(treated_intens treated) ///
    label ///
    b(%9.3f) se(%9.3f) ///
    title("Treatment Effects on Total N") ///
    mgroups("Full Sample" "No Walla Walla" "Treated Only" "Binary Treatment", pattern(1 1 1 1)) ///
    scalars("N Observations" "r2_a Adjusted R-squared") ///
    addnotes("All regressions include CBSA and year fixed effects." ///
            "Standard errors clustered at CBSA level in parentheses.") ///
    nomtitles ///
    replace */


* Check the distribution of treatment intensity in both samples
sum treated_intens if in_treatment_group == 1
sum treated_intens if in_treatment_group == 0

* Look at how many CBSAs are in each group
tab cbsa if in_treatment_group == 1
tab cbsa if in_treatment_group == 0

* Check your outcome variable in both groups
sum total_n if in_treatment_group == 1
sum total_n if in_treatment_group == 0

* Plot mean outcome over time by group
bysort t in_treatment_group: egen mean_outcome = mean(total_n)
twoway (line mean_outcome t if in_treatment_group == 1) ///
       (line mean_outcome t if in_treatment_group == 0), ///
       legend(label(1 "Treatment Group") label(2 "Never Treated"))

eststo clear


** Doing everything for duplexes

qui reg two_unit_n c.treated_intens##i.t i.cbsa i.t, cluster(cbsa) noomitted
est store m1

** Dropping Walla Walla
qui reg two_unit_n c.treated_intens##i.t i.cbsa i.t if !strpos(msa, "Walla Walla"), cluster(cbsa) noomitted
est store m2

** Not using the intensity
qui reg two_unit_n c.treated##i.t i.cbsa i.t, cluster(cbsa) noomitted
est store m3

** Dropping the never-treated cities
qui reg two_unit_n c.treated_intens##i.t i.cbsa i.t if in_treatment_group == 1, cluster(cbsa) noomitted
est store m4

* Create LaTeX table
esttab m1 m2 m4 m3 using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms and Permits/duplex_results_${timestamp}.tex", ///
    keep(treated_intens treated) ///
    label ///
    b(%9.3f) se(%9.3f) ///
    title("Treatment Effects on Duplex Unit Permits") ///
    mgroups("Full Sample" "No Walla Walla" "Treated Only" "Binary Treatment", pattern(1 1 1 1)) ///
    scalars("N Observations" "r2_a Adjusted R-squared") ///
    addnotes("All regressions include CBSA and year fixed effects." ///
            "Standard errors clustered at CBSA level in parentheses.") ///
    nomtitles ///
    replace

/*

xtreg total_n treated_intens, r fe

xtreg two_unit_n treated_intens, r fe

xtreg three_four_unit_n treated_intens, r fe

xtreg five_plus_unit_n treated_intens, r fe