#!/bin/sh
#
# ee.values.sh - compute the values of EE Savings Bonds over time
#
# By default compute the value as of the current month.  Optionally,
# with the flag -a, compute values from the issuing month to the
# current month.
#
# Usage:
#
#	ee.values.sh [-a] <holdings>
#
# Where <holdings> is a file containing lines in the format
# Series, Issue date, Serial Number, and Face value.  For
# example:
#
#	EE 1990-07-01 C123019924EE 100.00
#
#

# ee_value <serial> <face_value> <issue_date> <redemption_date>
#
# Output a CSV report pulled from the treasury calculator at
# https://www.treasurydirect.gov/BC/SBCPrice
#
# Dates should be in the form mm/yyyy
#
# An example:
# ee_value "C123019924EE" "$50.00" "07/1990" "02/2017"
#
# output will be the comma-separated-value output fields:
#	 initial price
#	 total value as of ${rdt}
#	 total interest as of ${rdt}
#	 year-to-date interest as of ${rdt}
#	 serial number
#	 bond series identifier
#	 face value
#	 issue date (mm/yyyy)
#	 next payment date (mm/yyyy)
#	 final payment date (mm/yyyy)
#	 interest rate note
function ee_value {
	series=$1	# bond series
	serial=$2;	# bond serial number
	face=$3;	# bond face value
	idt=$4;		# issue date (mm/yyyy)
	rdt=$5;		# redemption date (mm/yyyy)

	# clean up face value to a format that the treasury dept calculator
	# accepts (i.e., $100.00 becomes 100).
	denom=$(echo "${face}" | sed 's,^\$,,;s,\.00$,,');

	# send a query to the calculator and produce
	# the comma-separated-value output fields.
	curl -s --data-binary "RedemptionDate=${rdt}&btnUpdate.x=UPDATE&Series=EE&Denomination=${denom}&SerialNumber=${serial}&IssueDate=${idt}&SerialNumList=&IssueDateList=&SeriesList=&DenominationList=&IssuePriceList= &InterestList= &YTDInterestList=&ValueList=&InterestRateList=&NextAccrualDateList=&MaturityDateList=&NoteList=&OldRedemptionDate=782&ViewPos=0&ViewType=Partial&Version=6" https://www.treasurydirect.gov/BC/SBCPrice | awk '/Serial #/ { td = 9} /Total Price/ { td = 4 } td > 0 && /<td[^>]*>/ { print $0 ; td = td - 1;}' | tr -d '\r' | sed -E 's,</*(td|strong)[^>]*>,,g'|awk '{print $1}' | paste -d, -s - | awk -F, '{OFS=","; print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$13}'
}

# If -a was provided, compute all values for the bond from
# the issue date to the current date
if [ "$1" = "-a" ]; then
	opt_a=1;
	shift;
else
	opt_a=0;
fi;


# read bond holdings from a file, expected to be in the form
# of EE 1990-07-01 C123019924EE 100.00
while IFS='' read -r line || [[ -n "$line" ]]; do
	IFS=' ' read -r -a array <<< "$line";
	series="${array[0]}";
	idt=$(echo "${array[1]}" | awk -F- '{printf("%s/%s", $2, $1)}' );
	serial="${array[2]}";
	face=$(echo "${array[3]}" | cut -d. -f1);

	# date to start producing redemption values, if $opt_a
	# is set compute all dates, otherwise just use the current
	# month.
	if [ "$opt_a" = "1" ]; then
		start_dt=$(echo "$idt" |awk -F/ '{printf("%s%s", $2, $1)}');
		if [ "${start_dt}" -lt "199601" ]; then
			# earliest  redemption date for the treasury
			# calculator is 01/1996
			start_dt="199601";
		fi
	else
		start_dt=$(date +%Y%m);
	fi;
	
	# date to stop producing redemption values
	stop_dt=$(date "+%Y%m");
	
	# next date to produce a redemption value
	next_dt=$start_dt;
	
	# start calculating redemption values
	while [ "$next_dt" -le "$stop_dt" ]; do

		# redemption date, the date the bond is cashed in
		rdt=$(echo "$next_dt" | awk '{printf("%s/%s", substr($1, 5, 2), substr($1, 1, 4))}');

		# compute the bond value as of the redemption date
		IFS=',' read -r -a report <<< "$(ee_value "$series" "$serial" "$face" "$idt" "$rdt")";
		price="${report[0]}";		# initial price
		value="${report[1]}";		# total value as of ${rdt}
		ttl_int="${report[2]}";		# total interest as of ${rdt}
		ydt_int="${report[3]}";		# year-to-date interest as of ${rdt}
		serial="${report[4]}";		# serial number
		series="${report[5]}";		# bond series identifier
		face="${report[6]}.00";		# face value
		idt="${report[7]}";			# issue date (mm/yyyy)
		ndt="${report[8]}";		# next payment date (mm/yyyy)
		fdt="${report[9]}";			# final payment date (mm/yyyy)
		note="${report[10]}";		# interest rate note

		echo "${rdt},${series},${serial},${idt},${fdt},${note},${face},${price},${ttl_int},${value}";

		final_dt=$(echo "$fdt" |awk -F/ '{printf("%s%s", $2, $1)}');
		if [ "${final_dt}" -lt "${stop_dt}" ]; then
			# final date the bond will accrue interest is before our
			# stop date, so don't bother calculating beyond that.
			stop_dt="${final_dt}";
		fi;

		# set the next accrual date
		next_dt=$(echo "$ndt" |awk -F/ '{printf("%s%s", $2, $1)}');
	done;

done < "$1" # read holdings from filename $1.
