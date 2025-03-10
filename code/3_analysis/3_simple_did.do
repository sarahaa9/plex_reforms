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

xtreg total_n treated_intens, r fe

xtreg two_unit_n treated_intens, r fe

xtreg three_four_unit_n treated_intens, r fe

xtreg five_plus_unit_n treated_intens, r fe

/*
** Simple DiD - Monthly Outcome, Normalized, Total Permits

foreach x of local controls{
	eststo est`x': xtreg total_n `x', r fe
}


esttab using "${overleaf}/simpled_dids.tex", ///
			 nocons label f b(3) se(3) compress obslast replace stats(N,fmt("%9.0fc"))
eststo clear

* Restricting pre-period to 2015-2018

preserve
	drop if year < 2015
	foreach x of local controls{
		eststo est`x'2015: xtreg total_n `x', r fe
	}

	esttab using "${overleaf}/simple_dids_2015.tex", ///
				 nocons label f b(3) se(3) compress obslast replace stats(N,fmt("%9.0fc"))
	eststo clear
restore

** Outcome variable - duplexes

foreach x of local controls{
	eststo est2`x': xtreg two_unit_n `x', r fe
}

esttab using "${overleaf}/simpled_dids_duplexes.tex", ///
			 nocons label f b(3) se(3) compress obslast replace stats(N,fmt("%9.0fc"))
eststo clear

** Simple DiD - Yearly Outcome, Normalized, Total Permits

lab var yearly_permits_n "Total - Nor., Yearly"

preserve

	duplicates drop yearly_permits_n year cbsa, force

	gen not_yet_treated_year = .
	replace not_yet_treated_year = 0 if (treated_year == 0 & in_treatment_group == 1)
	replace not_yet_treated_year = 1 if (treated_year == 1 & in_treatment_group == 1)

	lab var not_yet_treated_year "Only Not-Yet-Treated as Controls - Yearly"

	gen comb_treated_year = .
	replace comb_treated_year = 0 if (treated_year == 0 & in_treatment_group == 1) | (in_treatment_group == 0)
	replace comb_treated_year = 1 if (treated_year == 1 & in_treatment_group == 1)

	lab var comb_treated_year "Not-Yet-Treated and Never Treated as Controls - Yearly"

	foreach y in yearly_permits_n y_one_unit_n y_two_unit_n y_three_four_unit_n y_five_plus_unit_n y_five_plus_structures_n{
		eststo est`y': xtreg `y' comb_treated_year, r fe
	}

	esttab using "${overleaf}/simple_did_year.tex", ///
				 nocons label f b(3) se(3) compress obslast replace stats(N,fmt("%9.0fc"))
	eststo clear

restore

* Restricting pre-period to 2015-2018
preserve
	drop if year < 2015

	duplicates drop yearly_permits_n year cbsa, force

	gen not_yet_treated_year = .
	replace not_yet_treated_year = 0 if (treated_year == 0 & in_treatment_group == 1)
	replace not_yet_treated_year = 1 if (treated_year == 1 & in_treatment_group == 1)

	lab var not_yet_treated_year "Only Not-Yet-Treated as Controls - Yearly"

	gen comb_treated_year = .
	replace comb_treated_year = 0 if (treated_year == 0 & in_treatment_group == 1) | (in_treatment_group == 0)
	replace comb_treated_year = 1 if (treated_year == 1 & in_treatment_group == 1)

	lab var comb_treated_year "Not-Yet-Treated and Never Treated as Controls - Yearly"

	foreach x in not_yet_treated_year comb_treated_year{
		eststo est`x': xtreg yearly_permits_n `x', r fe
	}

	esttab using "${overleaf}/simple_did_year_2015.tex", ///
				 nocons label f b(3) se(3) compress obslast replace stats(N,fmt("%9.0fc"))
	eststo clear

restore


/******************************************************************************
*                             Graphs of Pre-Trends                             *
******************************************************************************/

* Starting with just Walla Walla for pre-trend graph

preserve
	gen walla_treat = .
	replace walla_treat = 1 if in_treatment_group == 1 & strpos(msa, "Walla Walla") & strpos(msa, "WA")
	replace walla_treat = 0 if in_treatment_group == 0 | (in_treatment_group == 1 & treated_year == 0 & missing(walla_treat))

	collapse yearly_permits_n, by(year walla_treat)
	twoway line yearly_permits_n year if walla_treat == 1 || line yearly_permits_n year if walla_treat == 0, ///
				legend(order(1 "Walla Walla" 2 "Control")) xline(2018) ytitle("Total Permits Issued Annually" "Normalized by Population") xtitle("Year")
	graph export "${overleaf}/pre_trends_walla.png", replace
restore

preserve
	gen minneapolis_treat = .
	replace minneapolis_treat = 1 if in_treatment_group == 1 & strpos(msa, "Minneapolis") & strpos(msa, "MN")
	replace minneapolis_treat = 0 if in_treatment_group == 0 | (in_treatment_group == 1 & treated_year == 0 & missing(minneapolis_treat))

	tempfile minneapolis
	sa `minneapolis'

	collapse yearly_permits_n, by(year minneapolis_treat)
	twoway line yearly_permits_n year if minneapolis_treat == 1 || line yearly_permits_n year if minneapolis_treat == 0, ///
				legend(order(1 "Minneapolis" 2 "Control")) xline(2019) ytitle("Total Permits Issued Annually" "Normalized by Population") xtitle("Year")
	graph export "${overleaf}/pre_trends_minneapolis.png", replace

	use `minneapolis', clear

	duplicates drop yearly_permits_n year cbsa, force

	

	replace minneapolis_treat = 0 if minneapolis_treat == 1 & treated_year == 0

	pause
	eststo minneapolis: xtreg yearly_permits_n minneapolis_treat if year > 2014, r fe

	esttab using "${overleaf}/simple_did_minneapolis.tex", ///
				 nocons label f b(3) se(3) compress obslast replace stats(N, fmt("%9.0fc"))


restore

/******************************************************************************
*                      Dynamic Difference-in-differences                      *
******************************************************************************/

*defining relative time
*reference period is 2016

gen rel_time = 0 // never-treated groups

replace rel_time = year - 2018 if strpos(msa, "Walla Walla") & strpos(msa, "WA")
replace rel_time = year - 2019 if (strpos(msa, "Durham") & strpos(msa, "NC")) | (strpos(msa, "Grand Rapids") & strpos(msa, "MI")) | (strpos(msa, "Minneapolis") & strpos(msa, "MN"))
replace rel_time = year - 2020 if strpos(msa, "Portland") & strpos(msa, "OR")
replace rel_time = year - 2021 if (strpos(msa, "Charlotte") & strpos(msa, "NC")) | (strpos(msa, "Charlottesville") & strpos(msa, "VA"))
replace rel_time = year - 2022 if (strpos(msa, "San Francisco") & strpos(msa, "CA")) | (strpos(msa, "Gainesville") & strpos(msa, "FL")) | (strpos(msa, "Rochester") & strpos(msa, "MN")) | ///
								  (strpos(msa, "Spokane") & strpos(msa, "WA"))
replace rel_time = year - 2023 if (strpos(msa, "Oakland") & strpos(msa, "CA") & cbsa != 41860) | (strpos(msa, "Atlanta") & strpos(msa, "GA")) | (strpos(msa, "Boise") & strpos(msa, "ID")) | ///
								  (strpos(msa, "Iowa City") & strpos(msa, "IA")) | (strpos(msa, "Richfield") & strpos(msa, "MN")) | (strpos(msa, "Arlington") & strpos(msa, "VA"))

*already have treated variable

*Stata won't allow factors with negative values, so let's shift
* time-to-treat to start at 0, keeping track of where the true -1 is
summ rel_time
g shifted_ttt = rel_time - r(min)
summ shifted_ttt if rel_time == -1
local true_neg1 = r(mean)
* 27

*Regress on our interaction terms with FEs for group and year,
* clustering at the group (state) level
* use ib# to specify our reference group

preserve
	duplicates drop yearly_permits_n year cbsa, force

	eststo est1_tot: reghdfe yearly_permits_n ib`true_neg1'.shifted_ttt, a(cbsa year) vce(cluster cbsa)
	estimates store tot_coeffs

	eststo clear

	coefplot tot_coeffs, drop(_cons) ///
						 coeflabels(0.shifted_ttt = "-28" 1.shifted_ttt = "-27" 2.shifted_ttt = "-26" 3.shifted_ttt = "-25" 4.shifted_ttt="-24" ///
						  			5.shifted_ttt = "-23" 6.shifted_ttt="-22" 7.shifted_ttt="-21" 8.shifted_ttt = "-20" 9.shifted_ttt = "-19" 10.shifted_ttt="-18" ///
									11.shifted_ttt="-17" 12.shifted_ttt="-16" 13.shifted_ttt="-15" 14.shifted_ttt="-14" 15.shifted_ttt="-13"  ///
									16.shifted_ttt="-12" 17.shifted_ttt="-11" 18.shifted_ttt="-10" 19.shifted_ttt = "-9" 20.shifted_ttt = "-8" 21.shifted_ttt = "-7" ///
									22.shifted_ttt = "-6" 23.shifted_ttt = "-5" 24.shifted_ttt = "-4" 25.shifted_ttt = "-3" 26.shifted_ttt = "-2" ///
									28.shifted_ttt = "0" 29.shifted_ttt = "1" 30.shifted_ttt = "2" 31.shifted_ttt = "3" 32.shifted_ttt = "4" 33.shifted_ttt = "5") ///
						 vertical ///
						 xtitle("{stSerif:Years Since Policy Came into Effect}") xscale(titlegap(2)) xline(28, lcolor(black)) ///
						 yline(0,lcolor(black) lpattern(dash)) graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white) ilwidth(vvvthin)) ///
						 ciopts(lwidth(thin) lcolor(black)) mcolor(black)

	graph export "${dynamic_dids}/eventstudy_tot.png", replace
restore

*---------------------------------
** Dropping part of the pre-period
*---------------------------------
ren y_five_plus_structures_n y_5_plus_struc_n
ren y_three_four_unit_n y_3_4_unit_n
ren y_five_plus_unit_n y_5_plus_unit_n

local outcomes yearly_permits_n y_one_unit_n y_two_unit_n y_3_4_unit_n y_5_plus_unit_n y_5_plus_struc_n

preserve
	duplicates drop yearly_permits_n y_one_unit_n y_two_unit_n y_3_4_unit_n y_5_plus_unit_n y_5_plus_struc_n year cbsa, force

	foreach x of local outcomes{

		eststo est1_`x': reghdfe `x' ib`true_neg1'.shifted_ttt if shifted_ttt > 22, a(cbsa year) vce(cluster cbsa)
		estimates store `x'_coeffs

		eststo clear

		coefplot `x'_coeffs, drop(_cons) ///
							coeflabels(23.shifted_ttt = "-5" 24.shifted_ttt = "-4" 25.shifted_ttt = "-3" 26.shifted_ttt = "-2" ///
										28.shifted_ttt = "0" 29.shifted_ttt = "1" 30.shifted_ttt = "2" 31.shifted_ttt = "3" 32.shifted_ttt = "4" 33.shifted_ttt = "5") ///
							vertical ///
							xtitle("{stSerif:Years Since Policy Came into Effect}") xscale(titlegap(2)) xline(5, lcolor(black) lpattern(solid) lwidth(vthin)) ///
							yline(0,lcolor(black) lpattern(dash)) graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white) ilwidth(vvvthin)) ///
							ciopts(lwidth(medthick) lcolor(black)) mcolor(black)

		graph export "${dynamic_dids}/eventstudy_`x'_5.png", replace
	}
restore

*--------------------------------------------------------------
** Restricting the sample to just MSAs with reforms before 2021
*--------------------------------------------------------------

preserve

	drop if (strpos(msa, "Charlotte") & strpos(msa, "NC")) | (strpos(msa, "Charlotte") & strpos(msa, "NC")) | (strpos(msa, "Charlottesville") & strpos(msa, "VA"))
	drop if (strpos(msa, "San Francisco") & strpos(msa, "CA")) | (strpos(msa, "Gainesville") & strpos(msa, "FL")) | (strpos(msa, "St. Paul") & strpos(msa, "MN")) | ///
									  (strpos(msa, "Rochester") & strpos(msa, "MN")) | (strpos(msa, "Spokane") & strpos(msa, "WA"))
	drop if (strpos(msa, "Berkeley") & strpos(msa, "CA")) | (strpos(msa, "Oakland") & strpos(msa, "CA")) | (strpos(msa, "Atlanta") & strpos(msa, "GA")) | ///
									  (strpos(msa, "Boise") & strpos(msa, "ID")) | (strpos(msa, "Iowa City") & strpos(msa, "IA")) | (strpos(msa, "Richfield") & strpos(msa, "MN")) | ///
									  (strpos(msa, "Arlington") & strpos(msa, "VA"))

	duplicates drop yearly_permits_n y_one_unit_n y_two_unit_n y_3_4_unit_n y_5_plus_unit_n y_5_plus_struc_n year cbsa, force

	foreach x of local outcomes{

		eststo est1_`x': reghdfe `x' ib`true_neg1'.shifted_ttt if shifted_ttt > 22, a(cbsa year) vce(cluster cbsa)
		estimates store `x'_coeffs_res

		eststo clear

		coefplot `x'_coeffs_res, drop(_cons) ///
							coeflabels(23.shifted_ttt = "-5" 24.shifted_ttt = "-4" 25.shifted_ttt = "-3" 26.shifted_ttt = "-2" ///
										28.shifted_ttt = "0" 29.shifted_ttt = "1" 30.shifted_ttt = "2" 31.shifted_ttt = "3" 32.shifted_ttt = "4" 33.shifted_ttt = "5") ///
							vertical ///
							xtitle("{stSerif:Years Since Policy Came into Effect}") xscale(titlegap(2)) xline(5, lcolor(black) lpattern(solid) lwidth(vthin)) ///
							yline(0,lcolor(black) lpattern(dash)) graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white) ilwidth(vvvthin)) ///
							ciopts(lwidth(medthick) lcolor(black)) mcolor(black)

		graph export "${dynamic_dids}/eventstudy_`x'_5_restrict.png", replace
	}
restore

*-----------------------------
** Dropping Never-Treated MSAs
*-----------------------------

preserve
	duplicates drop yearly_permits_n y_one_unit_n y_two_unit_n y_3_4_unit_n y_5_plus_unit_n y_5_plus_struc_n year cbsa, force

	replace rel_time = . if never_treated == 1

	foreach x of local outcomes{

		eststo est1_`x': reghdfe `x' ib`true_neg1'.shifted_ttt if shifted_ttt > 22, a(cbsa year) vce(cluster cbsa)
		estimates store `x'_coeffs

		eststo clear

		coefplot `x'_coeffs, drop(_cons) ///
							coeflabels(23.shifted_ttt = "-5" 24.shifted_ttt = "-4" 25.shifted_ttt = "-3" 26.shifted_ttt = "-2" ///
										28.shifted_ttt = "0" 29.shifted_ttt = "1" 30.shifted_ttt = "2" 31.shifted_ttt = "3" 32.shifted_ttt = "4" 33.shifted_ttt = "5") ///
							vertical ///
							xtitle("{stSerif:Years Since Policy Came into Effect}") xscale(titlegap(2)) xline(5, lcolor(black) lpattern(solid) lwidth(vthin)) ///
							yline(0,lcolor(black) lpattern(dash)) graphregion(fcolor(white) lcolor(white) lwidth(vvvthin) ifcolor(white) ilcolor(white) ilwidth(vvvthin)) ///
							ciopts(lwidth(medthick) lcolor(black)) mcolor(black)

		graph export "${dynamic_dids}/eventstudy_`x'_5_no_nt.png", replace
	}
restore



