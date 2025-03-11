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

use "${processed}/permits_working_yearly.dta", clear

local forest_green = "74 103 65"

** Binary treatment variable

/* qui reg total_n treated i.year i.cbsa, cluster(cbsa)
di in red "Total"
lincom treated

qui reg one_unit_n treated i.year i.cbsa, cluster(cbsa)
di in red "One Unit"
lincom treated

qui reg two_unit_n treated i.year i.cbsa, cluster(cbsa)
di in red "Two Unit"
lincom treated

qui reg three_four_unit_n treated i.year i.cbsa, cluster(cbsa)
di in red "Three and Four Unit"
lincom treated

qui reg five_plus_unit_n treated i.year i.cbsa, cluster(cbsa)
di in red "Five Plus Unit"
lincom treated */

** Event study graphs

/******************************************************************************
*                      Dynamic Difference-in-differences                      *
******************************************************************************/

*defining relative time
*reference period is 2016

gen rel_time = 0 // never-treated groups

replace rel_time = year - 2019 if cbsa == 47460 // Walla Walla
replace rel_time = year - 2020 if cbsa == 24340 // Grand Rapids
replace rel_time = year - 2020 if cbsa == 20500 // Durham
replace rel_time = year - 2020 if cbsa == 33460 // Minneapolis
replace rel_time = year - 2022 if cbsa == 38900 // Portland
replace rel_time = year - 2022 if cbsa == 39580 // Raleigh
replace rel_time = year - 2023 if cbsa == 41860 // SF
replace rel_time = year - 2023 if cbsa == 44060 // Spokane
replace rel_time = year - 2023 if cbsa == 40340 // Rochester, MN

/* * Make a balanced panel with a subset of reforms
bysort cbsa: egen min_year = min(rel_time)
bysort cbsa: egen max_year = max(rel_time)
drop if min_year > -5  & in_treatment_group == 1 // Drop CBSAs that enter after start
drop if max_year < 3 & in_treatment_group == 1 // Drop CBSAs that exit before end */

*Stata won't allow factors with negative values, so let's shift time-to-treat to start at 0, keeping track of where the true -1 is
summ rel_time
g shifted_ttt = rel_time - r(min)
summ shifted_ttt if rel_time == -1
local true_neg1 = r(mean) // 27

* Save original rel_time
gen original_rel_time = rel_time

* Get median treatment date among treated cities
sum year if rel_time == 0 & in_treatment_group == 1
local median_treat_year = r(mean)

drop if in_treatment_group == 0

foreach y in total_n one_unit_n two_unit_n three_four_unit_n five_plus_unit_n{

    * Create relative time for controls based on this median
    replace rel_time = year - `median_treat_year' if in_treatment_group == 0

    *Regress on our interaction terms with FEs for group and year,
    * clustering at the group (cbsa) level
    * use ib# to specify our reference group

    eststo est1_tot: reg `y' c.treat_intens#ib`true_neg1'.shifted_ttt i.cbsa i.year if inrange(rel_time, -5, 5), vce(cluster cbsa)
    estimates store tot_coeffs

    eststo clear

    if "`y'" == "total_n"{
        local title_frag = "Total Permits"
    }
    if "`y'" == "one_unit_n"{
        local title_frag = "One-Unit Permits"
    }
    if "`y'" == "two_unit_n"{
        local title_frag = "Duplex Permits"
    }
    if "`y'" == "three_four_unit_n"{
        local title_frag = "Tri- and Fourplex Permits"
    }
    if "`y'" == "five_plus_unit_n"{
        local title_frag = "Five-Plus-Unit Permits"
    }

    coefplot tot_coeffs, drop(_cons i.cbsa i.year) ///
                        title("Effect of Plex Reforms on `title_frag'") ///
                        keep(*shifted_ttt#c.treat_intens) ///
                        coeflabels(23.shifted_ttt#c.treat_intens = "-5" 24.shifted_ttt#c.treat_intens = "-4" ///
                                   25.shifted_ttt#c.treat_intens = "-3" 26.shifted_ttt#c.treat_intens = "-2" ///
                                   28.shifted_ttt#c.treat_intens = "0" 29.shifted_ttt#c.treat_intens = "1" ///
                                   30.shifted_ttt#c.treat_intens = "2" 31.shifted_ttt#c.treat_intens = "3" ///
                                   32.shifted_ttt#c.treat_intens = "4" 33.shifted_ttt#c.treat_intens = "5") ///
                        vertical ///
                        ylabel( , nogrid) ///
                        xlabel( , nogrid) ///
                        xtitle("{stSerif:Years Since Policy Came into Effect}") xscale(titlegap(2)) xline(5, lcolor(gray)) ///
                        ytitle("{stSerif: Permits per 100k Population}") ///
                        yline(0,lcolor(gray) lpattern(dash)) graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white) ilwidth(vvvthin)) ///
                        ciopts(lwidth(thin) lcolor(black)) mcolor(black) ///
                        name(`y', replace) ///
                        note("Only not-yet-treated cities as controls, dropped never-treated cities. No normalization by pre-period mean")

    graph export "${overleaf}/eventstudy_`y'_no_norm_only_nyt_cities.png", replace
    pause

}

* Instead of using post directly, let's use the variation in treatment intensity

*drop if in_treatment_group == 0

qui reg total_n c.treat_intens i.year i.cbsa, cluster(cbsa)
lincom treat_intens

qui reg one_unit_n c.treat_intens i.year i.cbsa, cluster(cbsa)
lincom treat_intens

qui reg two_unit_n c.treat_intens i.year i.cbsa, cluster(cbsa)
lincom treat_intens

qui reg three_four_unit_n c.treat_intens i.year i.cbsa, cluster(cbsa)
lincom treat_intens

qui reg five_plus_unit_n c.treat_intens i.year i.cbsa, cluster(cbsa)
lincom treat_intens

/*
lincom treat_intens

 ( 1)  treat_intens = 0

------------------------------------------------------------------------------
       total | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
         (1) |  -33.21869   37.00089    -0.90   0.370    -105.9391    39.50175
------------------------------------------------------------------------------

. 
. qui reg one_unit c.treat_intens i.year i.cbsa, cluster(cbsa)

. lincom treat_intens

 ( 1)  treat_intens = 0

------------------------------------------------------------------------------
    one_unit | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
         (1) |  -82.93891   62.54405    -1.33   0.185    -205.8611    39.98329
------------------------------------------------------------------------------

. 
. qui reg two_unit c.treat_intens i.year i.cbsa, cluster(cbsa)

. lincom treat_intens

 ( 1)  treat_intens = 0

------------------------------------------------------------------------------
    two_unit | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
         (1) |  -3.562335   3.633084    -0.98   0.327    -10.70269     3.57802
------------------------------------------------------------------------------

. 
. qui reg three_four_unit c.treat_intens i.year i.cbsa, cluster(cbsa)

. lincom treat_intens

 ( 1)  treat_intens = 0

------------------------------------------------------------------------------
three_four~t | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
         (1) |  -3.666273   3.590636    -1.02   0.308     -10.7232    3.390655
------------------------------------------------------------------------------

. 
. qui reg five_plus_unit c.treat_intens i.year i.cbsa, cluster(cbsa)

. lincom treat_intens

 ( 1)  treat_intens = 0

------------------------------------------------------------------------------
five_plus_~t | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
         (1) |   56.94882   82.71862     0.69   0.492    -105.6239    219.5215
------------------------------------------------------------------------------

