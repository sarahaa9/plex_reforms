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
local brown = "139 69 19"
local peru = "205 133 63"
local gray = "128 128 128"
local blue = "70 130 180"

preserve
    foreach cbsa in 47460 16820 20500 39580 38900 41860 33460 24340 16740 44060 40340 12060 47900 26980 14260 {
        foreach y in total one_unit two_unit three_four_unit five_plus_unit{
            if `cbsa' == 47460{
                local treat_month = ym(2019, 1)
                local city = "Walla Walla"
            }
            if `cbsa' == 16820{
                local treat_month = ym(2024, 3)
                local city = "Charlottesville"
            }
            if `cbsa' == 20500{
                local treat_month = ym(2019, 10)
                local city = "Durham"
            }
            if `cbsa' == 39580{
                local treat_month = ym(2021, 8)
                local city = "Raleigh"
            }
            if `cbsa' == 38900{
                local treat_month = ym(2021, 8)
                local city = "Portland"
            }
            if `cbsa' == 41860{
                local treat_month = ym(2022, 10)
                local city = "San Francisco"
            }
            if `cbsa' == 33460{
                local treat_month = ym(2020, 1)
                local city = "Minneapolis"
            }
            if `cbsa' == 24340{
                local treat_month = ym(2019, 5)
                local city = "Grand Rapids"
            }
            if `cbsa' == 16740{
                local treat_month = ym(2023, 6)
                local city = "Charlotte"
            }
            if `cbsa' == 44060{
                local treat_month = ym(2022, 8)
                local city = "Spokane"
            }
            if `cbsa' == 40340{
                local treat_month = ym(2023, 1)
                local city = "Rochester"
            }
            if `cbsa' == 12060{
                local treat_month = ym(2023, 6)
                local city = "Decatur"
            }
            if `cbsa' == 47900{
                local treat_month = ym(2023, 7)
                local city = "Arlington"
            }
            if `cbsa' == 26980{
                local treat_month = ym(2024, 1)
                local city = "Iowa City"
            }
            if `cbsa' == 14260{
                local treat_month = ym(2023, 12)
                local city = "Boise"
            }

            sort t
            format t %tmMon_CCYY

            * Create month dummies
            drop month
            gen month = month(dofm(t))

            * Create empty variable to store all seasonally-adjusted values
            gen permits_sa = .

            * Create city-specific seasonally-adjusted series
            * Regress permits on month dummies for this city
            reg `y' i.month if cbsa == `cbsa'
            predict temp_sa if cbsa == `cbsa', residuals
            
            * Add back mean level for this city
            sum `y' if cbsa == `cbsa'
            replace permits_sa = temp_sa + r(mean) if cbsa == `cbsa'
            
            * Drop temp variable
            drop temp_sa

            twoway (line permits_sa t if cbsa == `cbsa', lcolor(blue)) ///
                (lowess permits_sa t if cbsa == `cbsa', lcolor(red) lpattern(dash)), ///
                legend(label(1 "Seasonally Adjusted") label(2 "Trend")) ///
                title("`city' - `y'") xline(`treat_month')

            graph export "${figures}/`city'_`y'_permits_over_time_monthly.png", replace

            drop permits_sa
        }
    }
restore
