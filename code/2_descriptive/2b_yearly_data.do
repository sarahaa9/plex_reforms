
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
use "${processed}/permits_working_monthly.dta", clear

drop if missing(census2010) // 7,224 observations deleted

drop groups msa_cut min_cbsa csa n month_cov_percent missings is_pmsa is_cmsa old_msa hyphen_pos msa_prefix ///
     space_pos name_prefix mult_cbsa source total_ytd one_unit_ytd two_unit_ytd three_four_unit_ytd five_plus_unit_ytd ///
     five_plus_structures_ytd MetroMicroCode unique cbsa_master dup _merge

* Create a new variable instead of replacing
bysort cbsa year census2010: egen mode_state = mode(states)

* Look at the cases that will change
list cbsa year census2010 states mode_state if states != mode_state, clean noobs

/*    cbsa   year   cen~2010   states   mode_s~e  
    22380   2002     134421       AZ      AZ-UT  
    22380   2003     134421    AZ-UT         AZ  
    22380   2003     134421    AZ-UT         AZ  
    22380   2003     134421    AZ-UT         AZ  
    22380   2003     134421    AZ-UT         AZ  
    34820   2014     376722    SC-NC         SC  
    34820   2014     376722    SC-NC         SC  
    34820   2014     376722    SC-NC         SC  
    34820   2014     376722    SC-NC         SC  
    37620   2014      92673       WV      WV-OH  
    37620   2014      92673       WV      WV-OH  
    37620   2014      92673       WV      WV-OH  
    37620   2014      92673       WV      WV-OH  
        .      .     107449       MS             
        .      .     107449       AZ         
*/

* Then if it looks correct:
replace states = mode_state
drop mode_state

collapse (sum) total one_unit two_unit three_four_unit five_plus_unit total_n one_unit_n two_unit_n three_four_unit_n ///
                     five_plus_unit_n, by(cbsa year census2010 states)

drop if year == 2024 // 349 observations deleted

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

gen treated = post * in_treatment_group

label define cbsa 47460 "Walla Walla" 38900 "Portland, OR" 39580 "Raleigh" 20500 "Durham" 41860 "San Francisco" ///
                  24340 "Grand Rapids" 44060 "Spokane" 33460 "Minneapolis"
label values cbsa cbsa

save "${processed}/permits_working_yearly.dta", replace