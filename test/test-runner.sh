#!/bin/bash

# Return 0 when test run is okay
# Return 1 when there was an test error
# Return 254 no connection to fhem process possible
# Return 255 if fhemcl.sh was not found

FHEM_SCRIPT="./test/fhemcl.sh"
FHEM_PORT=8083
VERBOSE=0

if [ ! -z $2 ]; then
  if [ $2 = "-v" ]; then  
        VERBOSE=1
  fi
fi


if [ ! -f $FHEM_SCRIPT ]; then
		exit 255
fi
#printf "Script %s\n" $FHEM_SCRIPT

IFS=
# Start the fhem instance with a test config file
#perl $FHEM_SCRIPT fhemtest.cfg
a=0
# Check if connection to fhem process is possible
while  true 
do 
	if $FHEM_SCRIPT $FHEM_PORT "LIST" 
	then
		break
	fi
	sleep 3
	
	if [ $a -gt "100" ]  # Limit trys
	then
	  exit 254
	fi
	a=$((a+1))
done

#RETURN=$(echo "reload 98_UnitTest" | /bin/nc localhost 7072)
#echo $RETURN


printf "\n\n--------- Starting test %s: ---------\n" "$1" 

# Load test definitions, and import them to our running instance
oIFS=$IFS
IFS=$'\n'  # Split into array at every "linebreak" 
command eval CMD='($(<test/$1-definition.txt))'
IFS=$oIFS
unset oIFS  
command eval DEF='$(printf "%s" ${CMD[@]})'  

CMD=$DEF
unset DEF

CMD=$( echo $CMD | sed '/{/,/}/s/;/;;/g') # double every ; 
#echo $CMD
#CMD=$(printf "%s" $CMD | awk 'BEGIN{RS="\n" ; ORS=" ";}{ print }' )
#CMD=$(printf "%q" $CMD )

#echo $CMD
#RETURN=$(perl $FHEM_SCRIPT 7072 "$CMD")
#RETURN=$(cat "test/$1-definition.txt" | $FHEM_SCRIPT $FHEM_PORT)
RETURN=$(echo $CMD | $FHEM_SCRIPT $FHEM_PORT)
echo "$RETURN"

#Wait until state of current test is finished
#Todo prevent forever loop here

CMD="{ReadingsVal(\"$1\",\"state\",\"\");;}"
CMD_RET=""
until [[ "$CMD_RET" =~ "finished" ]] ; do 
  CMD_RET=$($FHEM_SCRIPT $FHEM_PORT "$CMD")
  sleep 1; 
done

##
## curl -s "http://127.0.0.1:8083/fhem?cmd=jsonlist2%20test_defineDefaults%20test_output%20test_failure%20test_output%20todo_output&XHR=1" | jq '.Results[].Readings | {test_output, test_failure, todo_output}'
##
CMD="{ReadingsVal(\"$1\",\"test_output\",\"\")}"
OUTPUT=$($FHEM_SCRIPT $FHEM_PORT "$CMD")
OUTPUT=$(echo "$OUTPUT" | awk '{gsub(/\\n/,"\n")}1')

CMD="{ReadingsVal(\"$1\",\"test_failure\",\"\")}"
OUTPUT_FAILED=$($FHEM_SCRIPT $FHEM_PORT "$CMD")
testlog=$(awk '/Test '"$1"' starts here ---->/,/<---- Test '"$1"' ends here/' /opt/fhem/log/fhem-*.log)


printf "Output of %s:\n\n%s" "$1" "$OUTPUT"

if [ -z "$OUTPUT_FAILED"  ]
then
    if { [ $(echo $testlog | grep -Fxc "PERL WARNING") -gt 0 ] || [ $VERBOSE -eq 1 ]; }
	then
		echo "Warnings in FHEM Log snippet from test run:"
		echo "$testlog"
		status="ok with warnings"
	else 
		status="ok"
	fi

else
	echo "Errors of test $1:"
	echo "$OUTPUT_FAILED"

	echo "FHEM Log snippet from test run:"
	echo "$testlog"
	status="error"
fi

printf "\n\n--------- Test %s: %s ---------\n" "$1" "$status"

if [ $status == "error" ] 
then
 exit 1
fi
exit 0

#perl $FHEM_SCRIPT 7072 "shutdown"
