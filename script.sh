#!/bin/bash
# A script to do partial updates in Solr search server
#set -n
# Uncomment to check your syntax, without execution.
#


IFS=$'\n\t'
TODAY=`date "+%Y-%m-%d"`
COUNTER=0
NOW=$((`date "+%s"`))
BREAKER=10000
TAR="indexing-$TODAY.tar"
LIST_FILE="/tmp/list_of_items_to_update.csv"
LOG_FILE="/tmp/log_file.txt"

######## CHANGE credentials

echo "Script started at: `date "+%Y-%m-%d %H:%M:%S"`" >> $LOG_FILE

## usually you would fetch the data from DB based on certain date field and under some range
## here we are picking up two fields:
## - the okey which is the primary key in table and also the document id in Solr (so unique)
## - the field that needs to be added/updated in Solr document

## the following will genrate two column csv file and will save all the fetched data in the file,
/path/to/mysql -uUSER -pPASS -hHOST -DDATABASE -A -e "SELECT pkey,field FROM some_table WHERE some_datefield BETWEEN UNIX_TIMESTAMP(ADDDATE(CURDATE() , INTERVAL -1 DAY)) AND UNIX_TIMESTAMP(CURDATE())" > $LIST_FILE

## let's give proper rights
chmod a+rwx $LIST_FILE


echo "total `cat $LIST_FILE | wc -l` records" >> $LOG_FILE
echo "Data fetching done at: `date "+%Y-%m-%d %H:%M:%S"`" >> $LOG_FILE


## now we iterate 
## and in every iteration we create a formatted json payload 
## this json contains the 
cat $LIST_FILE | while read PKEY FIELD 
do
	if [ $COUNTER -gt 0 ]; then
		DATE=`date "+%Y-%m-%dT%H:%M:%SZ"`
		
## construct the data to post in JSON format
## below case assumes, all the fields are defined in schema.xml.
## if you need to create new field, make sure you have defined it in schema.xml or use the dynamic field naming convention 
	
		PARAM="[{\"SOLR_DOC_ID\":$PKEY,\"YOUR_FIELD_TO_UPDATE/CREATE\":{\"set\":$FIELD},\"indexed_time\":{\"set\":\"$DATE\"}}]"
		
		
## using the --write-out flag you can do some loggings about the process e.g. time taken to complete the curl request
		curl --write-out "id:$PKEY|Response code:%{http_code}|Total time:%{time_total}\n " --silent --raw http://localhost:SOME_PORT/solr/CORE_NAME/update -H "Content-type:application/json" -d $PARAM
		
	fi

	COUNTER=$(($COUNTER+1))	
		
## If the volume of data to update is VERY large consider putting a delay of few seconds periodically. I have chosen to put delay after indexing 10000 docs

	if [ `expr $COUNTER % $BREAKER` -eq 0 ]; then
		
## again some stats for logging

		ITERATION=$(($COUNTER/$BREAKER))
		echo "Sleeping for 5 seconds now"
		echo "Iteration no $ITERATION" 

## this will show the number of seconds it took to process the 10000 docs		
		NOW2=$((`date "+%s"`))
		DIFF=$((NOW2-NOW))
		
		echo "Took $DIFF secs"
		
		NOW=$((`date "+%s"`))
		NOW2=0
		sleep 5
	fi

done >> $LOG_FILE ##all output goes in this file


echo "Script Ended at: `date "+%Y-%m-%d %H:%M:%S"`" >> $LOG_FILE

chmod a+rwx $LOG_FILE

## create a compressed file to mail
cd /tmp/
tar -czf $TAR $LIST_FILE $LOG_FILE 

## finally mail all the log files
echo "PFA log files" | mail -s "SOME TEXT  - $TODAY" -a "$TODAY.tar" -- xxxxx@ddd.com
