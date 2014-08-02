#!/bin/bash

TIPFILE="/tmp/tips.txt"
TMPTIPFILE="${TIPFILE}.tmp"

# Defaults
MODE="QUERY"
MONTHS=(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
TOKEN_COST=.08

# Functions
function calcPercent() {
	echo "CALCPERCENT DEBUG [$1|$2]" >> /tmp/out
	printf "%7.0f\n" `echo "( (${1} * 100) / (${2} * 100) ) * 100" | bc -l`
}


# Add mode
if [[ "${1}" = "-a" ]] ; then
	shift
	echo "Adding rows"

	if [[ -f "${TIPFILE}" ]] ; then
		cp "${TIPFILE}" "${TMPTIPFILE}"
	else
		rm -f "${TMPTIPFILE}"
	fi

	count=0
	while read month day year time type camgirl Tokens extra
	do
		# Fix group show, which is two words, so it shifts everything after it
		if [[ ${type} = "Group" ]] ; then
			camgirl=${Tokens}
			Tokens=${extra}
		fi

		# echo "< [${month}|${day}|${year}|${time}|${type}|${camgirl}|${Tokens}]"


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
			continue
		fi

		day=`echo ${day} | tr -d '[a-z,]'`
		day=`printf '%02d' ${day}`

		time=`echo ${time} | tr ':' '\t'`

		#echo "> [${monthNo}|${day}|${year}|${time}|${type}|${camgirl}|${Tokens}]"
		echo -e "${year}\t${monthNo}\t${day}\t${time}\t${type}\t${camgirl}\t${Tokens}" >> "${TMPTIPFILE}"
		count=$(($count + 1))
	done

	# Make sure we have sorted rows
	# We can't sort unique in case there are multiple tips in the same second
	sort  < "${TMPTIPFILE}" > "${TIPFILE}"

	echo "${count} rows added, "`wc -l "${TIPFILE}"`" total"
fi

while [[ $# -gt 0 ]]
do
	key="$1"
	shift
	case ${key} in
		-y|--year)
			SEARCHYEAR="$1"
			shift
			;;
		-m|--month)
			SEARCHMONTH="$1"
			shift
			;;
		-d|--day)
			SEARCHDAY="$1"
			shift
			;;
		-t|--type)
			SEARCHTYPE="$1"
			shift
			;;
		-c|--camgirl)
			SEARCHCAMGIRL="$1"
			shift
			;;
		-r|--printrecords)
			PRINTRECORDS=1
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
		*)
			# unknown option
			echo "Unknown option '${key}'"
			;;
	esac
done


# Read each record and process it
while read year month day hour minute second type camgirl tokens
do
	# Does this record match the filter criteria?
	isMatch=1
	if [[ "${SEARCHYEAR}" != "" && ! ${year} =~ ${SEARCHYEAR} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCHMONTH}" != "" && ! ${month} =~ ${SEARCHMONTH} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCHDAY}" != "" && ! ${day} =~ ${SEARCHDAY} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCHTYPE}" != "" && ! ${type} =~ ${SEARCHTYPE} ]] ; then
		isMatch=0
	fi
	if [[ "${SEARCHCAMGIRL}" != "" && ! ${camgirl} =~ ${SEARCHCAMGIRL} ]] ; then
		isMatch=0
	fi


	# Process the record
	if [[ $isMatch -eq 1 ]] ; then
		if [[ $PRINTRECORDS -eq 1 ]] ; then
			echo $year $month $day $hour $minute $second $type $camgirl $tokens
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
		printf '=== Month %s\n' $key
		printf '            Count          Tokens         Dollars\n'
		printf 'Match     %7d         %7d         %7.2f\n' ${gbMonthCount[$key]} ${gbMonthTokens[$key]} `echo "${gbMonthTokens[$key]} * ${TOKEN_COST}" | bc`
		printf 'Total     %7d         %7d         %7.2f\n' $totalCount $totalTokens `echo "${totalTokens} * ${TOKEN_COST}" | bc`
		printf 'Percent   %7.0f         %7.0f      %7.0f\n' `calcPercent ${gbMonthCount[$key]} ${totalCount}` `calcPercent ${gbMonthTokens[$key]} ${totalTokens}` `calcPercent ${gbMonthTokens[$key]} ${totalTokens}`
	done
fi

# Print camgirl groupings
if [[ ${GROUPBYCAMGIRL} -eq 1 ]] ; then
	for key in `echo ${!gbCamGirlCount[*]} | tr ' ' '\n' | sort`
	do
		printf '=== Camgirl %s\n' $key
		printf '            Count          Tokens         Dollars\n'
		printf 'Match     %7d         %7d         %7.2f\n' ${gbCamGirlCount[$key]} ${gbCamGirlTokens[$key]} `echo "${gbCamGirlTokens[$key]} * ${TOKEN_COST}" | bc`
		printf 'Total     %7d         %7d         %7.2f\n' $totalCount $totalTokens `echo "${totalTokens} * ${TOKEN_COST}" | bc`
		printf 'Percent   %7.0f         %7.0f      %7.0f\n' `calcPercent ${gbCamGirlCount[$key]} ${totalCount}` `calcPercent ${gbCamGirlTokens[$key]} ${totalTokens}` `calcPercent ${gbCamGirlTokens[$key]} ${totalTokens}`
	done
fi

# Print totals
printf '=== TOTALS\n'
printf '            Count          Tokens         Dollars\n'
printf 'Match     %7d         %7d         %7.2f\n' $matchCount $matchTokens `echo "${matchTokens} * ${TOKEN_COST}" | bc`
printf 'Total     %7d         %7d         %7.2f\n' $totalCount $totalTokens `echo "${totalTokens}*${TOKEN_COST}" | bc`
printf 'Percent   %7.0f         %7.0f      %7.0f\n' `calcPercent ${matchCount} ${totalCount}` `calcPercent ${matchTokens} ${totalTokens}`  `calcPercent ${matchTokens} ${totalTokens}`



