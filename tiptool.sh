#!/bin/bash

TIPTOOL_HOME="${HOME}/.tiptool"
if [[ ! -d "${TIPTOOL_HOME}" ]] ; then
	mkdir -p "${TIPTOOL_HOME}"
	if [[ ! -d "${TIPTOOL_HOME}" ]] ; then
		echo "Cannot create '${TIPTOOL_HOME}'. Exiting."
		exit
	fi
fi
TIPFILE="${TIPTOOL_HOME}/tips.txt"
TMPTIPFILE="${TIPFILE}.tmp"

# Defaults
MODE="QUERY"
MONTHS=(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
TOKEN_COST=.08

# Functions
function calcPercent() {
	printf '%7.0f' `echo "( (${1} * 100) / (${2} * 100) ) * 100" | bc -l`
}

function calcCost() {
	echo "${1} * ${TOKEN_COST}" | bc -l
}

# Params: title matchCount matchTokens
function printStats() {
	printf '\n=== %s\n' "${1}"
	printf '            Count          Tokens         Dollars\n'
	printf 'Match     %7d         %7d         %7.2f\n' ${2} ${3} `calcCost ${3}`
	printf 'Total     %7d         %7d         %7.2f\n' $totalCount $totalTokens `calcCost ${totalTokens}`
	printf 'Percent   %7.0f         %7.0f      %7.0f\n' `calcPercent ${2} ${totalCount}` `calcPercent ${3} ${totalTokens}`  `calcPercent ${3} ${totalTokens}`
}

# Add a tip read in from the input to the tip file
function addTip() {
	if [ "${DEBUG_MODE}" != "" ] ; then
		echo "     addTip [${year}|${month}|${day}|${time}|${type}|${camgirl}|${tokens}|${note}]"
	fi
	if [[ "${year}" != "" ]] ; then
		year=`echo ${year} | tr -d '[,]'`
		year=`printf '%04d' ${year}`

		monthNo=0
		currentMonthNo=0
		for currentMonthName in "${MONTHS[@]}"; do
			currentMonthNo=$((${currentMonthNo} + 1))
			if [ "${month}" = "${currentMonthName}" ]; then
				monthNo=`printf '%02d' ${currentMonthNo}`
				break
			fi
		done

		if [ ${monthNo} -eq 0 ] ; then
			if [ "${DEBUG_MODE}" != "" ] ; then
				echo "      Bad month, skipping"
			fi
		fi

		day=`echo ${day} | tr -d '[a-z,]'`
		day=`printf '%02d' ${day}`

		time=`echo ${time} | tr ':' '\t'`

		if [ "${DEBUG_MODE}" != "" ] ; then
			echo "WRITING [${monthNo}|${day}|${year}|${time}|${type}|${camgirl}|${tokens}|${note}]"
		fi
		echo -e "${year}\t${monthNo}\t${day}\t${time}\t${type}\t${camgirl}\t${tokens}\t${note}" >> "${TMPTIPFILE}"

		count=$(($count + 1))
	else
		if [ "${DEBUG_MODE}" != "" ] ; then
			echo "      Empty year, skipping"
		fi
	fi
}

# Read lines from stdin
# Since we may have tip lines, and won't know it until after the data, we have to process each line after reading the next and
# determining what kind of line it is
function addTips() {
	echo "Adding rows"

	if [[ -f "${TIPFILE}" ]] ; then
		cp "${TIPFILE}" "${TMPTIPFILE}"
	else
		rm -f "${TMPTIPFILE}"
	fi

	count=0
	read -a lineIn
	#while read month day year time type camgirl tokens extra
	while [[ "${lineIn[0]}" != "" ]]
	do
		if [ "${DEBUG_MODE}" != "" ] ; then
			echo "READING [${lineIn[*]}]"
		fi

		# Identify the kind of line last read
		if [[ ${lineIn[0]} =~ [A-Z][a-z][a-z] &&  ${lineIn[1]} =~ [0-9][0-9stndrd,]+ &&  ${lineIn[2]} =~ [0-9]{4}[,] ]] ; then
			if [[ ${lineIn[6]} =~ [0-9]+ ]] ; then
				if [ "${DEBUG_MODE}" != "" ] ; then
					echo "     Tip line with a single-word type"
				fi
				addTip
				month=${lineIn[0]}
				day=${lineIn[1]}
				year=${lineIn[2]}
				time=${lineIn[3]}
				type=${lineIn[4]}
				camgirl=${lineIn[5]}
				tokens=${lineIn[6]}
				note=""
			else
				if [ "${DEBUG_MODE}" != "" ] ; then
					echo "     Tip line with a double-word type"
				fi
				addTip
				month=${lineIn[0]}
				day=${lineIn[1]}
				year=${lineIn[2]}
				time=${lineIn[3]}
				type="${lineIn[4]}${lineIn[5]}"
				camgirl=${lineIn[6]}
				tokens=${lineIn[7]}
				note=""
			fi
		else
			if [ "${DEBUG_MODE}" != "" ] ; then
				echo "     Tip note line"
			fi
			note="${lineIn[*]}"
			# This record will be written on the next read, so don't addTip here
		fi

		read -a lineIn
	done

	# Process the last line
	addTip

	# Make sure we have sorted rows
	# We can't sort unique to elimiate duplicate adds in case there are multiple tips in the same second
	sort  < "${TMPTIPFILE}" > "${TIPFILE}"

	echo "${count} rows added, "`wc -l "${TIPFILE}"`" total"
	exit
}


# Parse parameters
while [[ $# -gt 0 ]]
do
	key="$1"
	shift
	echo "KEY='${key}'"
	case ${key} in
		-sy|--search_year)
			SEARCH_YEAR="$1"
			shift
			;;
		-sm|--search_month)
			SEARCH_MONTH="$1"
			shift
			;;
		-sd|--search_day)
			SEARCH_DAY="$1"
			shift
			;;
		-st|--search_type)
			SEARCHTYPE="$1"
			shift
			;;
		-sc|--search_camgirl)
			SEARCH_CAMGIRL="$1"
			shift
			;;
		-str|--search_tokenrange)
			SEARCH_TOKENRANGE=1
			SEARCH_TOKENRANGE_MIN=$1
			shift
			SEARCH_TOKENRANGE_MAX=$1
			shift
			;;
		-sn|--search_note)
			SEARCH_NOTE="$1"
			shift
			;;
		-sa|--search_ALL)
			SEARCH_ALL="$1"
			shift
			;;
		-r|--PRINT_RECORDS)
			PRINT_RECORDS=1
			;;
		-gc|--groupby-camgirl)
			GROUPBYCAMGIRL=1
			declare -A gbCamGirlCount
			declare -A gbCamGirlTokens
			;;
		-gm|--groupby-month)
			GROUPBYMONTH=1
			declare -A gbMonthCount
			declare -A gbMonthTokens
			;;
		-a|--add-tips)
			addTips
			;;
		-v|--verbose)
			DEBUG_MODE=1
			;;
		*)
			# unknown option
			echo "Unknown option '${key}'"
			;;
	esac
done


# Read each record and process it
while read year month day hour minute second type camgirl tokens note
do
	# Does this record match the filter criteria?
	isMatch=1
	if [[ "${SEARCH_YEAR}" != "" && ! ${year} =~ ${SEARCH_YEAR} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCH_MONTH}" != "" && ! ${month} =~ ${SEARCH_MONTH} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCH_DAY}" != "" && ! ${day} =~ ${SEARCH_DAY} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCHTYPE}" != "" && ! ${type} =~ ${SEARCHTYPE} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCH_CAMGIRL}" != "" && ! ${camgirl} =~ ${SEARCH_CAMGIRL} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCH_TOKENRANGE}" != "" && ( ${tokens} -lt ${SEARCH_TOKENRANGE_MIN} || ${tokens} -gt ${SEARCH_TOKENRANGE_MAX}  ) ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCH_NOTE}" != "" && ! ${note} =~ ${SEARCH_NOTE} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCH_ALL}" != "" && ! "$year $month $day $hour $minute $second $type $camgirl $tokens $note" =~ ${SEARCH_ALL} ]] ; then
		isMatch=0
	fi


	# Process the record
	if [[ $isMatch -eq 1 ]] ; then
		if [[ $PRINT_RECORDS -eq 1 ]] ; then
			echo "[$year|$month|$day|$hour|$minute|$second|$type|$camgirl|$tokens|$note]"
		fi
		matchCount=$(($matchCount + 1))
		matchTokens=$(($matchTokens + $tokens))

		# Grouping operations
		if [[ ${GROUPBYMONTH} -eq 1 ]] ; then
			gbMonthCount[${year}.${month}]=$((gbMonthCount[${year}.${month}] + 1))
			gbMonthTokens[${year}.${month}]=$((gbMonthTokens[${year}.${month}] + $tokens))
		fi
		if [[ ${GROUPBYCAMGIRL} -eq 1 ]] ; then
			gbCamGirlCount[$camgirl]=$((gbCamGirlCount[$camgirl] + 1))
			gbCamGirlTokens[$camgirl]=$((gbCamGirlTokens[$camgirl] + $tokens))
		fi
	fi
	totalCount=$(($totalCount + 1))
	totalTokens=$(($totalTokens + $tokens))
done < "${TIPFILE}"

# Print month groupings
if [[ ${GROUPBYMONTH} -eq 1 ]] ; then
	for key in `echo ${!gbMonthCount[*]} | tr ' ' '\n' | sort`
	do
		printStats "Month ${key}" ${gbMonthCount[$key]} ${gbMonthTokens[$key]}
	done
fi

# Print camgirl groupings
if [[ ${GROUPBYCAMGIRL} -eq 1 ]] ; then
	for key in `echo ${!gbCamGirlCount[*]} | tr ' ' '\n' | sort`
	do
		printStats "Camgirl ${key}" ${gbCamGirlCount[$key]} ${gbCamGirlTokens[$key]}
	done
fi

# Print totals
printStats "TOTALS" ${matchCount} ${matchTokens}



