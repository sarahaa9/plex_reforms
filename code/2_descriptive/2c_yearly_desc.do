
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

* First, add these label commands before your esttab command
label var total "Total Permits"
label var one_unit "1-Unit"
label var two_unit "2-Unit" 
label var three_four_unit "3-4 Unit"
label var five_plus_unit "5+ Unit"

label var total_n "Total Permits"
label var one_unit_n "1-Unit"
label var two_unit_n "2-Unit" 
label var three_four_unit_n "3-4 Unit"
label var five_plus_unit_n "5+ Unit"

** Summary Statistics Table **
eststo est1: estpost tabstat total one_unit two_unit three_four_unit five_plus_unit, c(stat) stat(mean sd min max n)


esttab using "${overleaf}/summ_stats.tex", ////
             cells("mean(fmt(%9.0fc)) sd(fmt(%9.0fc)) min(fmt(%9.0fc)) max(fmt(%9.0fc)) count(fmt(%9.0fc))") nonumber ///
             nomtitle nonote noobs label booktabs f ///
             collabels("Mean" "SD" "Min" "Max" "N")  ///
             title("Table 1 \label{table1}") replace

** Summary Statistics Table - Permit Numbers Normalized by 2010 Population **

eststo est1: estpost tabstat total_n one_unit_n two_unit_n three_four_unit_n five_plus_unit_n, c(stat) stat(mean sd min max n)

esttab using "${overleaf}/summ_stats_nor.tex", ////
             cells("mean(fmt(%9.0fc)) sd(fmt(%9.0fc)) min(fmt(%9.0fc)) max(fmt(%9.0fc)) count(fmt(%9.0fc))") nonumber ///
             nomtitle nonote noobs label booktabs f ///
             collabels("Mean" "SD" "Min" "Max" "N") replace

** Treated vs. Control for Normalized Permit Numbers **

* For treatment group
eststo est1: estpost tabstat total_n one_unit_n two_unit_n three_four_unit_n five_plus_unit_n ///
        if in_treatment_group == 1 & year < 2019, ///
        statistics(mean sd min max count) columns(statistics)
        
esttab using "${overleaf}/summ_stats_treat.tex", ///
        cells("mean(fmt(%9.0fc)) sd(fmt(%9.0fc)) min(fmt(%9.0fc)) max(fmt(%9.0fc)) count(fmt(%9.0fc))") nonumber ///
        nomtitle nonote noobs label fragment plain ///
        collabels(none) ///
        title(none) replace ///
        prehead("") posthead("") prefoot("") postfoot("")

* For control group
eststo est1: estpost tabstat total_n one_unit_n two_unit_n three_four_unit_n five_plus_unit_n ///
        if in_treatment_group == 0 & year < 2019, ///
        statistics(mean sd min max count) columns(statistics)
        
esttab using "${overleaf}/summ_stats_control.tex", ///
        cells("mean(fmt(%9.0fc)) sd(fmt(%9.0fc)) min(fmt(%9.0fc)) max(fmt(%9.0fc)) count(fmt(%9.0fc))") nonumber ///
        nomtitle nonote noobs label fragment plain ///
        collabels(none) ///
        title(none) replace ///
        prehead("") posthead("") prefoot("") postfoot("")
