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

use "${processed}/permits_working.dta", clear

local forest_green = "74 103 65"

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

* Use treatment data
merge m:1 cbsa using "${processed}/treatment_intensities.dta", keep(match master) nogenerate

* Initialize treatment variables
gen treated = 0
gen in_treatment_group = 0
gen treated_year = 0
gen treated_intens = 1  // Default for untreated

* Apply treatment based on consolidated data
levelsof cbsa if !missing(treat_intens), local(treated_cbsas)
foreach c of local treated_cbsas {
    * Get values for this CBSA
    sum treat_intens if cbsa == `c', meanonly
    local intensity = r(mean)
    
    sum reform_year if cbsa == `c', meanonly
    local ref_year = r(mean)
    
    sum reform_month if cbsa == `c', meanonly
    local ref_month = r(mean)
    
    * Apply treatment
    replace treated = 1 if cbsa == `c' & t > ym(`ref_year', `ref_month')
    replace treated_year = 1 if cbsa == `c' & year > `ref_year'
    replace in_treatment_group = 1 if cbsa == `c'
    replace treated_intens = `intensity' if cbsa == `c' & t > ym(`ref_year', `ref_month')
}

gen post = (year > reform_year)

label define cbsa 47460 "Walla Walla" 38900 "Portland, OR" 39580 "Raleigh" 20500 "Durham" 41860 "San Francisco" ///
                  24340 "Grand Rapids" 44060 "Spokane" 33460 "Minneapolis"
label values cbsa cbsa

drop if missing(year)

gen multi_unit = total - one_unit

foreach y in total one_unit two_unit three_four_unit five_plus_unit multi_unit{

    preserve

        keep if in_treatment_group == 1

        collapse (sum) `y', by(cbsa year treated treat_intens post in_treatment_group)

        gen log_permits = ln(`y')


        reg log_permits i.post##i.cbsa i.year

        * Store coefficients as locals
        local base_effect = _b[1.post] // stores the base post coefficient
        local port_effect = _b[1.post#38900.cbsa] // stores Portland interaction
        local ral_effect = _b[1.post#39580.cbsa] // stores Raleigh interaction
        local sf_effect = _b[1.post#41860.cbsa] // stores SF interaction
        local ww_effect = _b[1.post#47460.cbsa] // stores Walla Walla interaction
        local gr_effect = _b[1.post#24340.cbsa] // stores Grand Rapids interaction
        local mpls_effect = _b[1.post#33460.cbsa] // stores Minneapolis interaction
        local spk_effect = _b[1.post#44060.cbsa] // sotres Spokane interaction
        
        clear
        set obs 8
        
        * Generate variables
        gen cbsa = .
        gen coef = .
        gen treat_intens = .
        
        * Fill in values with the coefficients from the regression
        replace cbsa = 38900 in 1  // Portland
        replace cbsa = 39580 in 2  // Raleigh 
        replace cbsa = 41860 in 3  // SF
        replace cbsa = 47460 in 4  // Walla Walla
        replace cbsa = 20500 in 5  // Durham (baseline)
        replace cbsa = 24340 in 6  // Grand Rapids
        replace cbsa = 33460 in 7 // Minneapolis
        replace cbsa = 44060 in 8 // Spokane
        
        * Fill in coefficients - adding interaction effects to base effect
        replace coef = `base_effect' + `port_effect' if cbsa == 38900   // Portland
        replace coef = `base_effect' + `ral_effect' if cbsa == 39580   // Raleigh
        replace coef = `base_effect' + `sf_effect' if cbsa == 41860    // SF
        replace coef = `base_effect' + `ww_effect' if cbsa == 47460   // Walla Walla
        replace coef = `base_effect' + `gr_effect' if cbsa == 24340 // Grand Rapids
        replace coef = `base_effect' + `mpls_effect' if cbsa == 33460 // Minneapolis
        replace coef = `base_effect' + `spk_effect' if cbsa == 44060 // Spokane
        replace coef = `base_effect' if cbsa == 20500   // Durham (just base effect)

        * Use treatment data
        merge m:1 cbsa using "${processed}/treatment_intensities.dta", keep(match master) nogenerate

        * Initialize treatment variables
        gen treated = 0
        gen in_treatment_group = 0
        gen treated_year = 0
        gen treated_intens = 1  // Default for untreated

        * Apply treatment based on consolidated data
        levelsof cbsa if !missing(treat_intens), local(treated_cbsas)
        foreach c of local treated_cbsas {
            * Get values for this CBSA
            sum treat_intens if cbsa == `c', meanonly
            local intensity = r(mean)
            
            sum reform_year if cbsa == `c', meanonly
            local ref_year = r(mean)
            
            sum reform_month if cbsa == `c', meanonly
            local ref_month = r(mean)
            
            * Apply treatment
            replace treated = 1 if cbsa == `c' & t > ym(`ref_year', `ref_month')
            replace treated_year = 1 if cbsa == `c' & year > `ref_year'
            replace in_treatment_group = 1 if cbsa == `c'
            replace treated_intens = `intensity' if cbsa == `c' & t > ym(`ref_year', `ref_month')
        }

        label define cbsa 47460 "Walla Walla" 38900 "Portland, OR" 39580 "Raleigh" 20500 "Durham" ///
                          41860 "San Francisco" 24340 "Grand Rapids" 33460 "Minneapolis" 44060 "Spokane"
        label values cbsa cbsa

        gen pos = 3
        replace pos = 9 if cbsa == 47460
        replace pos = 6 if cbsa == 20500

        if "`y'" == "total"{
            local title_frag = "Total Permits"
            replace pos = 12 if cbsa == 20500
            replace pos = 3 if cbsa == 41860
            replace pos = 6 if cbsa == 24340
            replace pos = 12 if cbsa == 47460
        }
        if "`y'" == "one_unit"{
            local title_frag = "One-Unit Permits"
            replace pos = 6 if cbsa == 38900
            replace pos = 12 if cbsa == 20500
            replace pos = 12 if cbsa == 44060
            replace pos = 6 if cbsa == 41860
        }
        if "`y'" == "two_unit"{
            local title_frag = "Duplex Permits"
            replace pos = 6 if cbsa == 33460
            replace pos = 12 if cbsa == 20500 | cbsa == 39580
        }
        if "`y'" == "three_four_unit"{
            local title_frag = "Tri- and Fourplex Permits"
            replace pos = 12 if cbsa == 41860
            replace pos = 12 if cbsa == 24340
            replace pos = 6 if cbsa == 33460
        }
        if "`y'" == "five_plus_unit"{
            local title_frag = "Five-Plus-Unit Permits"
            replace pos = 12 if cbsa == 20500 | cbsa == 41860 | cbsa == 38900 | cbsa == 44060
            replace pos = 6 if cbsa == 33460
            replace pos = 9 if cbsa == 24340
        }
        if "`y'" == "multi_unit"{
            local title_frag = "Non-Single-Family Permits"
            replace pos = 12 if cbsa == 20500
            replace pos = 9 if cbsa == 24340
        }
        
        * Create the scatter plot
        twoway scatter coef treat_intens, mlabel(cbsa) ///
            mcolor("`forest_green'") ///
            mlabcolor("`forest_green'") ///
            ytitle("Treatment Effect") ///
            xtitle("Treatment Intensity") ///
            title("Treatment Effects on `title_frag' by Intensity") ///
            mlabvposition(pos) ///
            mlabsize(vsmall) ///
            xlabel( , nogrid) ///
            yline(0) ///
            ylabel(-3(1)3, nogrid) ///
            yscale(range(-3 3)) ///
            graphregion(margin(l=5 r=5)) ///
            name(`y', replace)
        graph export "${figures}/delta_permits_`y'_post.png", replace

    restore
}