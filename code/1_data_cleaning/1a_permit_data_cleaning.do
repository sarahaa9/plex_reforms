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

forvalues y = 1995(1)2019{
	foreach m in 01 02 03 04 05 06 07 08 09 10 11 12{
		di in red "The year is `y' and the month is `m'"
		
		if `y' == 2019 & `m' >= 11{
			continue
		}
		
		if `y' == 1999 & `m' == 05{
			continue
		}
		
		import delimited "${permits_raw}/cbsamonthly_`y'`m'.txt", delimiter(space, collapse) bindquote(nobind) clear
		gen year = `y'
		gen month = `m'
		missings dropobs _all, force
		
		drop if strpos(v2, "Table")
		drop if strpos(v2, "Unadjusted")
		drop if strpos(v2, "Num")
		drop if strpos(v2, "Struc")
		drop if strpos(v2, "tures")
		drop if strpos(v2, "With")
		drop if strpos(v2, "requested")
		drop if strpos(v2, "January")
		drop if strpos(v2, "February")
		drop if strpos(v2, "March")
		drop if strpos(v2, "April")
		drop if strpos(v2, "May")
		drop if strpos(v2, "June")
		drop if strpos(v2, "July")
		drop if strpos(v2, "August")
		drop if strpos(v2, "September")
		drop if strpos(v2, "October")
		drop if strpos(v2, "November")
		drop if strpos(v2, "December")
		drop if strpos(v2, "Total")
		drop if v2 == "shows"
		drop if v2 == "monthly"
		drop if v3 == "offices"
		drop if v3 == "Monthly"
		drop if v2 == "-"
		drop if v2 == "For"
		drop if v2 == "so"
		drop if v2 == "This"
		drop if v2 == "in"
		drop if v2 == "*"
		drop if v8 == "Units" | v7 == "Units" | v8 == "units"
		cap drop if v1 == "*"
		drop if v2 == "for"
		
		missings dropvars _all, force
		
		pause
		
		if (`y' > 2009 | (`y' == 2009 & `m' >= 08 & `m' != 09)){
			
			* Generate a variable that counts non-missing values in v1

			egen missings = count(v1)

			* Check if all values are missing and execute the command accordingly
			if missings == 0 {
				capture confirm variable v14
				if (_rc == 0) == 1{
					replace v14 = v13
				}
				capture confirm variable v13
				if (_rc == 0) == 1{
					replace v13 = v12
				}
				replace v12 = v11
				replace v11 = v10
				replace v10 = v9
				replace v9 = v8
				replace v8 = v7
				replace v7 = v6
				replace v6 = v5
				replace v5 = v4
				replace v4 = v3
				replace v3 = v2
				replace v2 = "" if v1 == "" 
			}
			
			
			** Dealing with the observations where the name is split between two rows and on the second row the part of the name is in v2
			
			
			foreach i in 14 13 12 11 10 9 8 7 6 5 4 3 2{
				local j = `i' - 1

				capture confirm variable v`i'
		
				if (_rc == 0) == 0{
					continue
				}
				
				replace v`i' = v`j' if missing(v1) & !missing(v2)
			}
			
			** Dealing with observations where a number that isn't the CBSA is in v2
			
			ren v1 csa
			ren v2 cbsa
			ren v3 v2
			ren v4 v3
			ren v5 v4
			ren v6 v5
			ren v7 v6
			ren v8 v7
			ren v9 v8
			ren v10 v9
			ren v11 v10
			capture confirm existence variable v13
			if _rc == 1{
				ren v12 v11
			}
			capture confirm existence variable v13
			if _rc == 1{
				ren v13 v12
			}
			capture confirm existence variable v14
			if _rc == 1{
				ren v14 v13
			}
		}
		
		capture confirm variable v1
		
		if (_rc == 0) == 1{
			di in red "is this happening"
			gen msa = v1
			order msa
			missings dropvars v1, force
		}
		
		
		cap gen msa = v2 if !regexm(v2, "[0-9]")
		order msa
		
		missings dropvars v2, force
		cap replace msa = msa + " " + v2 if !regexm(v2, "[0-9]") & v2 != ""
		replace msa = msa + " " + v3 if !regexm(v3, "[0-9]") & v3 != ""
		replace msa = msa + " " + v4 if !regexm(v4, "[0-9]") & v4 != ""
		replace msa = msa + " " + v5 if !regexm(v5, "[0-9]") & v5 != ""
		replace msa = msa + " " + v6 if !regexm(v6, "[0-9]") & v6 != ""
		replace msa = msa + " " + v7 if !regexm(v7, "[0-9]") & v7 != ""
		replace msa = msa + " " + v8 if !regexm(v8, "[0-9]") & v8 != ""
		
		
		capture confirm variable v1
		if (_rc == 0) == 1{
			replace v1 = "" if !regexm(v1, "[0-9]")
			missings dropvars v1, force
		}
		replace v2 = "" if !regexm(v2, "[0-9]")
		replace v3 = "" if !regexm(v3, "[0-9]")
		replace v4 = "" if !regexm(v4, "[0-9]")
		replace v5 = "" if !regexm(v5, "[0-9]")
		replace v6 = "" if !regexm(v6, "[0-9]")
		replace v7 = "" if !regexm(v7, "[0-9]")
		replace v8 = "" if !regexm(v8, "[0-9]")
		
		
		order msa
		
		gen total = .
		gen one_unit = .
		gen two_unit = .
		gen three_four_unit = .
		gen five_plus_unit = .
		gen five_plus_structures = .
		gen month_cov_percent = .
		
		destring v2 v3 v4 v5 v6 v7 v8 v9 v10, replace
		cap destring v11, replace
		cap destring v12, replace
		cap destring v13, replace
		cap destring v14, replace
		
		order total, after(msa)
		
		forvalues i = 2(1)14{

			capture confirm variable v`i'
		
			if (_rc == 0) == 0{
				continue
			}
			gen v`i'used = (v`i' != . & missing(total))
			replace total = v`i' if v`i' != . & missing(total)
			replace v`i' = . if v`i'used == 1
			drop v`i'used
		}
		
		order one_unit, after(total)
	
		
		forvalues i = 2(1)14{
			
			capture confirm variable v`i'
		
			if (_rc == 0) == 0{
				continue
			}
			gen v`i'used = (v`i' != . & missing(one_unit))
			replace one_unit = v`i' if v`i' != . & missing(one_unit)
			replace v`i' = . if v`i'used == 1
			drop v`i'used
		}
		
		order two_unit, after(one_unit)
		
		forvalues i = 2(1)14{
			
			capture confirm variable v`i'
		
			if (_rc == 0) == 0{
				continue
			}
			gen v`i'used = (v`i' != . & missing(two_unit))
			replace two_unit = v`i' if v`i' != . & missing(two_unit)
			replace v`i' = . if v`i'used == 1
			drop v`i'used
		}
		
		order three_four_unit, after(two_unit)
		
		
		forvalues i = 2(1)14{
			
			capture confirm variable v`i'
		
			if (_rc == 0) == 0{
				continue
			}
			gen v`i'used = (v`i' != . & missing(three_four_unit))
			replace three_four_unit = v`i' if v`i' != . & missing(three_four_unit)
			replace v`i' = . if v`i'used == 1
			drop v`i'used
		}
		
		order five_plus_unit, after(three_four_unit)
		
		
		forvalues i = 2(1)14{
			
			capture confirm variable v`i'
		
			if (_rc == 0) == 0{
				continue
			}
			gen v`i'used = (v`i' != . & missing(five_plus_unit))
			replace five_plus_unit = v`i' if v`i' != . & missing(five_plus_unit)
			replace v`i' = . if v`i'used == 1
			drop v`i'used
		}
		
		order five_plus_structures, after(five_plus_unit)
		
		
		forvalues i = 2(1)14{
			
			capture confirm variable v`i'
		
			if (_rc == 0) == 0{
				continue
			}
			gen v`i'used = (v`i' != . & missing(five_plus_structures))
			replace five_plus_structures = v`i' if v`i' != . & missing(five_plus_structures)
			replace v`i' = . if v`i'used == 1
			drop v`i'used
		}
		
		order month_cov_percent, after(five_plus_structures)
		
		
		forvalues i = 2(1)14{
			
			capture confirm variable v`i'
		
			if (_rc == 0) == 0{
				continue
			}
			gen v`i'used = (v`i' != . & missing(month_cov_percent))
			replace month_cov_percent = v`i' if v`i' != . & missing(month_cov_percent)
			replace v`i' = . if v`i'used == 1
			drop v`i'used
		}
		
		
		missings dropvars _all, force
		
		drop if missing(msa) & missing(total) & missing(one_unit) & missing(two_unit) & missing(three_four_unit) & missing(five_plus_unit) & missing(five_plus_structures)
		di in red "before dealing with the names split between two rows"
		pause 
		
		gen n = _n
		sum n
		local max = `r(max)'
		
		forvalues i = 1(1)`max' {
			local j = `i' + 1
			replace msa = msa[`i'] + " " + msa[`j'] if total[`i'] == . & one_unit[`i'] == . & two_unit[`i'] == . & three_four_unit[`i'] == . & five_plus_unit[`i'] == . & five_plus_structures[`i'] == . & _n == `j'
			replace msa = "clear" if total[`i'] == . & one_unit[`i'] == . & two_unit[`i'] == . & three_four_unit[`i'] == . & five_plus_unit[`i'] == . & five_plus_structures[`i'] == . & _n == `i'
			
			capture confirm variable csa cbsa
			if (_rc == 0) == 0{
				continue
			}
			replace csa = csa[`i'] if _n == `j' & msa[`i'] == "clear"
			replace cbsa = cbsa[`i'] if _n == `j' & msa[`i'] == "clear"
		}
		
		drop if msa == "clear"
		
		missings dropvars _all, force
		
		tempfile permits_`y'`m'
		sa `permits_`y'`m''
		
		
		
	}
}

use `permits_199501', clear

forvalues y = 1995(1)2019{
	foreach m in 01 02 03 04 05 06 07 08 09 10 11 12{
		if `y' == 1995 & `m' == 1{
			continue
		}
		if `y' == 2019 & `m' >= 11{
			continue
		}
		if `y' == 1999 & `m' == 05{
			continue
		}
		append using `permits_`y'`m''
	}
}

destring csa cbsa, replace

save "${permits_processed}/appended_permit_data_1", replace
