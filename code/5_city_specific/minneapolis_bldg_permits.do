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

use "${processed}/area/mpls_parcels_zoning_pre_post.dta", clear
drop _merge

tempfile zoning
sa `zoning'

import delimited using "/Users/sarah/Downloads/CCS Permits.csv", clear bindquote(strict) 

ren apn pin

drop if real(pin)==. & pin!=""
destring pin, replace

merge m:1 pin using `zoning'

gen rezoned = (zoning_post != zoning_pre)
gen upzoned = (end_density > start_density)

gen permit_issue_year = substr(issuedate, 1, 4)
destring permit_issue_year, replace

* First create the date variable
gen permit_date = date(substr(issuedate, 1, 10), "YMD")
format permit_date %td

* Then create the time variable
gen permit_issue_time = substr(issuedate, 12, 8)

* Create a tag/indicator variable
gen after_reform = (permit_date >= td(01jan2020))

sum after_reform // mean = 0.71

gen treat_post = (after_reform == 1 & upzoned == 1)
sum treat_post // mean = 0.0079

drop if _merge == 2 // 104,272 observations deleted

drop sub4_pt sub4_exemp


/* population of interest
- permits for residential construction
- new residences
- in areas that were residential pre- and post-reform



. tab worktype if dwellingunitsnew > 0 & !missing(dwellingunitsnew)

   workType |      Freq.     Percent        Cum.
------------+-----------------------------------
   Addition |         22        1.67        1.67
 Conversion |        107        8.11        9.78
       Misc |          1        0.08        9.86
        New |        977       74.07       83.93
    Remodel |        159       12.05       95.98
    UnitCon |         49        3.71       99.70
 UnitFinish |          4        0.30      100.00
------------+-----------------------------------
      Total |      1,319      100.00

* conversion can be duplex to single-family
* conversion can be triplex to duplex
* maybe ignore conversions for now, because I need comments to understand change in units
*/
keep if _merge == 3
keep if permittype == "Commercial" | permittype == "Res"
keep if worktype == "New"

/* keep if both_res == 1
reg dwellingunitsnew treat_post after_reform upzoned, r

gen duplex_legal = (inlist(zoning_pre, "R1", "R1A"))
gen duplex_legal_post = (after_reform == 1 & duplex_legal == 1)

reg dwellingunitsnew duplex_legal_post after_reform duplex_legal if occupancytype == "TFD"

e

preserve
   collapse (total) dwellingunitsnew, by(year)
restore */

* Generate policy period indicator (0 = pre-reform, 1 = post-reform)
gen post_reform = (permit_date >= td(1jan2020))

* Create treatment group indicators
gen r1_zones = (inlist(zoning_pre, "R1", "R1A"))
gen r2_zones = (inlist(zoning_pre, "R2", "R2B"))

* Generate outcome variable for duplex permits
gen is_duplex = (occupancytype == "TFD")

* Generate time variables for event study
gen months_from_reform = mofd(permit_date) - mofd(td(1jan2020))

*------------------------------------------------------------------*

* Overall effect on duplex construction
* Basic regression
eststo reg1: reg is_duplex i.r1_zones##i.post_reform i.r2_zones, robust
estadd local monthfe "No"
estadd local yearfe "No"

* Separate month and year fixed effects to control for seasonality
gen month = month(permit_date)
gen year = year(permit_date)

eststo reg2: reg is_duplex i.r1_zones##i.post_reform i.r2_zones i.month i.year, robust
estadd local monthfe "Yes"
estadd local yearfe "Yes"

*------------------------------------------------------------------*

* First, let's look at the range of months_from_reform
sum months_from_reform

* Create shifted time bins (adding 48 to make all values positive)
gen shifted_months = months_from_reform + 48

* Create binned event-time indicators (6-month bins)
egen time_bin = cut(shifted_months), at(0,6,12,18,24,30,36,42,48,54,60,72,84,96)

* Label the bins relative to reform
label define timelab 0 "-48 to -42" 6 "-42 to -36" 12 "-36 to -30" 18 "-30 to -24" ///
                     24 "-24 to -18" 30 "-18 to -12" 36 "-12 to -6" 42 "-6 to 0" ///
                     48 "0 to 6" 54 "6 to 12" 60 "12 to 18" 72 "18 to 24" 84 "24+"
label values time_bin timelab

* Event study regression (6-month bins)
eststo reg3: reg is_duplex i.r1_zones##i.time_bin i.r2_zones i.month, cluster(zoning_pre)
estadd local monthfe "Yes"
estadd local yearfe "No"
estadd local binned "Yes"

*------------------------------------------------------------------*

* Compare duplex permits across zones over time
bysort year zoning_pre: egen zone_duplexes = total(is_duplex)

* Zone substitution regression
eststo reg4: reg zone_duplexes i.r1_zones##i.post_reform i.r2_zones##i.post_reform i.month i.year, robust
estadd local monthfe "Yes"
estadd local yearfe "Yes"

* Output to LaTeX
esttab reg1 reg2 reg4 using "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms Writing Sample/mpls_results.tex", ///
    label style(tex) replace ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) se(%9.3f) ///
    scalars("r2 \$R^2\$" "N Observations") ///
    mtitles("Basic" "With FE""Substitution") ///
    stats(monthfe yearfe N r2, ///
          labels("Month FE" "Year FE" "Observations" "\$R^2\$") ///
          fmt(%9.0fc %9.0fc %9.0fc %9.0fc %9.3f)) ///
    title("Impact of Zoning Reform on Duplex Construction") ///
    addnotes("Standard errors in parentheses, clustered at zoning level for event study." ///
            "* p<0.10, ** p<0.05, *** p<0.01" ///
            "Event study specification includes 6-month time bins from 48 months pre- to 24+ months post-reform.") ///
    keep(1.r1_zones 1.post_reform 1.r1_zones#1.post_reform 1.r2_zones 1.r2_zones#1.post_reform) ///
    order(1.r1_zones 1.post_reform 1.r1_zones#1.post_reform 1.r2_zones 1.r2_zones#1.post_reform) ///
    coeflabels(1.r1_zones "R1 Zones" ///
               1.post_reform "Post-Reform" ///
               1.r1_zones#1.post_reform "R1 × Post-Reform" ///
               1.r2_zones "R2 Zones" ///
               1.r2_zones#1.post_reform "R2 × Post-Reform") ///
    prehead("\begin{table}[htbp]\centering\caption{@title}\begin{tabular}{lccc}\hline\hline") ///
    posthead("\hline") ///
    prefoot("\hline") ///
    postfoot("\hline\hline\end{tabular}\begin{tablenotes}\footnotesize\item \emph{Notes:} @note\end{tablenotes}\end{table}")

*------------------------------------------------------------------*

* First preserve the data since we'll be collapsing it
preserve

   * Create quarter variable
   gen quarter = qofd(permit_date)
   format quarter %tq

   * Collapse to quarterly counts by zone type
   collapse (sum) n_duplexes=is_duplex, by(quarter r1_zones)

   * Create the reform date in quarterly format
   local reform_date = qofd(date("2020-01-01", "YMD"))

   * Create the graph
   twoway (bar n_duplexes quarter if r1_zones==1, color(blue%50)) ///
         (bar n_duplexes quarter if r1_zones==0, color(red%50)), ///
         xline(`reform_date', lpattern(dash) lcolor(black)) ///
         xlabel(#16, angle(45) labsize(small) format(%tq)) ///
         ylabel(0(2)10, angle(0)) ///
         xtitle("Quarter") ///
         ytitle("Number of Duplex Permits") ///
         title("Quarterly Duplex Permits by Zone Type", size(large)) ///
         subtitle("Vertical line indicates 2020 zoning reform", size(medium)) ///
         legend(label(1 "R1/R1A Zones") label(2 "Other Zones") region(color(none))) ///
         graphregion(color(white)) bgcolor(white) ///
         scheme(s2color)

restore

graph export "/Users/sarah/Library/CloudStorage/Dropbox-MIT/Apps/Overleaf/Plex Reforms Writing Sample/mpls_quarterly_permits.png", replace
