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

import excel using "${raw_data}/csa-est2019-annres.xlsx", clear

ren A msa
ren B census2010
ren C estimatesbase2010
ren D pop2010
ren E pop2011
ren F pop2012
ren G pop2013
ren H pop2014
ren I pop2015
ren J pop2016
ren K pop2017
ren L pop2018
ren M pop2019

drop if strpos(msa, "row headers")
drop if strpos(pop2010, "Population Estimate")
drop if strpos(msa, "Annual Estimates")
drop if strpos(census2010, "Census")
drop if strpos(msa, "reflect changes")
drop if strpos(msa, "Suggested Citation")
drop if strpos(msa, "Source:")
drop if strpos(msa, "Release Date:")

missings dropobs _all, force
missings dropvars _all, force

destring census2010 estimatesbase2010 pop2010, replace

replace msa = subinstr(msa, ".", "", 1)

split msa, parse(" ") gen(msa_part)

order msa_part*, after(msa)

tempfile csas
save `csas'

import excel using "${raw_data}/cbsa-mic-est2019-annres.xlsx", clear

ren A msa
ren B census2010
ren C estimatesbase2010
ren D pop2010
ren E pop2011
ren F pop2012
ren G pop2013
ren H pop2014
ren I pop2015
ren J pop2016
ren K pop2017
ren L pop2018
ren M pop2019

drop if strpos(msa, "row headers")
drop if strpos(pop2010, "Population Estimate")
drop if strpos(msa, "Annual Estimates")
drop if strpos(census2010, "Census")
drop if strpos(msa, "reflect changes")
drop if strpos(msa, "Suggested Citation")
drop if strpos(msa, "Source:")
drop if strpos(msa, "Release Date:")

missings dropobs _all, force
missings dropvars _all, force

destring census2010 estimatesbase2010 pop2010, replace

replace msa = subinstr(msa, ".", "", 1)

tempfile micros
save `micros'

import excel using "${raw_data}/cbsa-met-est2019-annres.xlsx", clear

ren A msa
ren B census2010
ren C estimatesbase2010
ren D pop2010
ren E pop2011
ren F pop2012
ren G pop2013
ren H pop2014
ren I pop2015
ren J pop2016
ren K pop2017
ren L pop2018
ren M pop2019

drop if strpos(msa, "row headers")
drop if strpos(pop2010, "Population Estimate")
drop if strpos(msa, "Annual Estimates")
drop if strpos(census2010, "Census")
drop if strpos(msa, "reflect changes")
drop if strpos(msa, "Suggested Citation")
drop if strpos(msa, "Source:")
drop if strpos(msa, "Release Date:")

missings dropobs _all, force
missings dropvars _all, force

destring census2010 estimatesbase2010 pop2010, replace

replace msa = subinstr(msa, ".", "", 1)

append using `csas', gen(csas)
append using `micros', gen(micros)

generate states = regexs(2) if regexm(msa, "^(.*?)( [A-Z]{2}(?:-[A-Z]{2})*)( CSA)$")
replace states = regexs(2) if regexm(msa, "^(.*?)( [A-Z]{2}(?:-[A-Z]{2})*)( Micro Area)$") & missing(states)
replace states = regexs(2) if regexm(msa, "^(.*?)( [A-Z]{2}(?:-[A-Z]{2})*)( Metro Area)$") & missing(states)
replace states = trim(states)

generate primary_state = substr(states, 1, 2)

order states primary_state, after(msa)

drop if missing(states) | states == "PR"

drop msa_part*


count if census2010 != estimatesbase2010

replace msa = subinstr(msa, "Micro Area", "", 1)
replace msa = subinstr(msa, "Metro Area", "", 1)
replace msa = subinstr(msa, "CSA", "", 1)

replace msa = trim(msa)

replace msa = subinstr(msa, ",", "", 1)


* Find the position of the hyphen in the first 7 characters
gen hyphen_pos = strpos(substr(msa, 1, 7), "-")

* Generate the variable with all characters before the hyphen
gen msa_prefix = substr(msa, 1, hyphen_pos - 1) if hyphen_pos > 0


gen msa_cut = substr(msa, 1, 7)
replace msa_cut = msa_prefix if !missing(msa_prefix)


* Find the position of the first space
gen space_pos = strpos(msa, " ")

* Generate the variable with everything before the first space
gen name_prefix = substr(msa, 1, space_pos - 1) if space_pos > 0

replace msa_cut = name_prefix if length(msa) <= 7
replace msa_cut = trim(msa_cut)

duplicates tag msa_cut primary_state, gen(dup)

drop if dup > 0 & csas == 1

keep msa msa_cut states primary_state census2010


save "${processed}/population", replace
