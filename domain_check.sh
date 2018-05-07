#!/bin/bash 

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ssl/bin:/usr/sfw/bin ; export PATH

# Whois server to use (cmdline: -s)
WHOIS_SERVER="whois.kg"

# Location of system binaries
AWK="/usr/bin/awk"
WHOIS="/usr/bin/whois"
DATE="/bin/date"
CUT="/usr/bin/cut"
# Place to stash temporary files
WHOIS_TMP="/tmp/whois.$$"

#############################################################################
# Purpose: Convert a date from MONTH-DAY-YEAR to Julian format
# Acknowledgements: Code was adapted from examples in the book
#                   "Shell Scripting Recipes: A Problem-Solution Approach"
#                   ( ISBN 1590594711 )
# Arguments:
#   $1 -> Month (e.g., 06)
#   $2 -> Day   (e.g., 08)
#   $3 -> Year  (e.g., 2006)
#############################################################################
date2julian() 
{
    if [ "${1} != "" ] && [ "${2} != ""  ] && [ "${3}" != "" ]
    then
         ## Since leap years add aday at the end of February, 
         ## calculations are done from 1 March 0000 (a fictional year)
         d2j_tmpmonth=$((12 * ${3} + ${1} - 3))
        
          ## If it is not yet March, the year is changed to the previous year
          d2j_tmpyear=$(( ${d2j_tmpmonth} / 12))
        
          ## The number of days from 1 March 0000 is calculated
          ## and the number of days from 1 Jan. 4713BC is added 
          echo $(( (734 * ${d2j_tmpmonth} + 15) / 24 -  2 * ${d2j_tmpyear} + ${d2j_tmpyear}/4
                        - ${d2j_tmpyear}/100 + ${d2j_tmpyear}/400 + $2 + 1721119 ))
    else
          echo 0
    fi
}

#############################################################################
# Purpose: Convert a string month into an integer representation
# Arguments:
#   $1 -> Month name (e.g., Sep)
#############################################################################
getmonth() 
{
       LOWER=`tolower $1`
              
       case ${LOWER} in
             jan) echo 1 ;;
             feb) echo 2 ;;
             mar) echo 3 ;;
             apr) echo 4 ;;
             may) echo 5 ;;
             jun) echo 6 ;;
             jul) echo 7 ;;
             aug) echo 8 ;;
             sep) echo 9 ;;
             oct) echo 10 ;;
             nov) echo 11 ;;
             dec) echo 12 ;;
               *) echo  0 ;;
       esac
}

#############################################################################
# Purpose: Calculate the number of seconds between two dates
# Arguments:
#   $1 -> Date #1
#   $2 -> Date #2
#############################################################################
date_diff() 
{
        if [ "${1}" != "" ] &&  [ "${2}" != "" ]
        then
                echo $(expr ${2} - ${1})
        else
                echo 0
        fi
}

##################################################################
# Purpose: Converts a string to lower case
# Arguments:
#   $1 -> String to convert to lower case
##################################################################
tolower() 
{
     LOWER=`echo ${1} | tr [A-Z] [a-z]`
     echo $LOWER
}

##################################################################
# Whois data to grab expiration date
##################################################################
check_domain_status() 
{
    # Save the domain since set will trip up the ordering
    DOMAIN=${1}
    ${WHOIS} -h "whois.kg" "${1}" > ${WHOIS_TMP}

    # The whois Expiration data should resemble the following: "Expiration Date: 09-may-2008"

	DOMAINDATE=`cat ${WHOIS_TMP} | ${AWK} '/Record expires on:/ { printf $6"-"$5"-"$8 }'`

    #echo $DOMAINDATE # debug 
    # Whois data should be in the following format: "13-feb-2006"
    IFS="-"
    set -- ${DOMAINDATE}
    MONTH=$(getmonth ${2})
    IFS=""

    # Convert the date to seconds, and get the diff between NOW and the expiration date
    DOMAINJULIAN=$(date2julian ${MONTH} ${1#0} ${3})
	echo $(date_diff ${NOWJULIAN} ${DOMAINJULIAN})
}

##########################################
# Purpose: Describe how the script works
# Arguments:
#   None
##########################################
usage()
{
        echo ""
        echo "          {[ -d domain_name ]} || { -f patch to domain list file}"
        echo ""
        echo "  -d domain        : Domain to analyze (interactive mode)"
        echo "  -f patch to domain list file   : File with a list of domains"
        echo ""
}

### Evaluate the options passed on the command line
while getopts "f:d:s:x" option
do
        case "${option}"
        in

                d) DOMAIN=$OPTARG;;
                f) SERVERFILE=$OPTARG;;
                \?) usage
                    exit 1;;
        esac
done

### Baseline the dates so we have something to compare to
MONTH=$(${DATE} "+%m")
DAY=$(${DATE} "+%d")
YEAR=$(${DATE} "+%Y")
NOWJULIAN=$(date2julian ${MONTH#0} ${DAY#0} ${YEAR})

### Touch the files prior to using them
touch ${WHOIS_TMP}

### If a HOST and PORT were passed on the cmdline, use those values
if [ "${DOMAIN}" != "" ]
then
        check_domain_status "${DOMAIN}"
### If a file and a "-a" are passed on the command line, check all
### of the domains in the file to see if they are about to expire
elif [ -f "${SERVERFILE}" ]
then
        while read DOMAIN
        do
                check_domain_status "${DOMAIN}"

        done < ${SERVERFILE}

### There was an error, so print a detailed usage message and exit
else
        usage
        exit 1
fi

# Add an extra newline
echo

### Remove the temporary files
#rm -f ${WHOIS_TMP}

### Exit with a success indicator
exit 0

