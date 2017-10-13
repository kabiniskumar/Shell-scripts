
######################################################################################################
#
#Mload automation script to load an extract to work table and to validate it against the target table
#
# Created by : Kabini S Kumar
#
######################################################################################################

echo " Target Table Name[SCHEMA.TABLE]: "
read tgt_tbl

TERA_DB_LOGON=teraload.logon;
CURR_DT=`date +%Y%m%d`
env=`cat ${TERA_DB_LOGON} |  awk -F'/' '{print substr($2,0,3)}'`;
LOG_TBL=${env}WORK.LOGTABLE${RANDOM};
table_name=`echo $tgt_tbl | cut -d'.' -f2`;
WORK_TBL=${env}WORK.${table_name}_${RANDOM};
BTEQ_LOG_FILE=${tgt_tbl}_bteqlog_${CURR_DT}.log;
MLOAD_SCRIPT=${table_name}_load.mload;
LAYOUT_FILE=extract_layout.txt;

EXTRACT_NM=`cat extract_path.txt`;

#Create worktable to load the extract data

bteq <<bteqend 1>${BTEQ_LOG_FILE} 2>&1

.SESSIONS 1;
.RUN FILE ${TERA_DB_LOGON};

CREATE TABLE ${WORK_TBL}
AS ${tgt_tbl}
WITH NO DATA;

.IF ERRORCODE <> 0 THEN .QUIT 10

.LOGOFF
.QUIT 0;

bteqend

#Create file layout from the user specified format

sed -r 's/,$|^,//' ${LAYOUT_FILE} > Tmp1_${LAYOUT_FILE}
sed -i '/^[ ]*$/d' Tmp1_${LAYOUT_FILE}
#Change the formatting to fit for all datatypes


awk '
{datatype= toupper($2);
if (datatype ~ /BYTEINT/)
        datatype="VARCHAR(3)";
else if (datatype ~ /SMALLINT/)
        datatype="VARCHAR(5)";
else if (datatype ~ /INTEGER/)
        datatype="VARCHAR(10)";
else if (datatype ~ /BIGINT/)
        datatype="VARCHAR(20)";
else if (datatype ~ /DECIMAL/)
        datatype="VARCHAR(20)";
else if (datatype ~ /NUMERIC/)
        datatype="VARCHAR(20)";
else if (datatype ~ /FLOAT/)
        datatype="VARCHAR(20)";
else if (datatype ~ /DATE/)
        datatype="VARCHAR(12)";
else if (datatype ~ /TIME/)
        datatype="VARCHAR(25)";
else if (datatype ~ /TIMESTAMP/)
        datatype="VARCHAR(45)";
print ".field "$1" * "datatype";"
attr=$1;
$1="";

if(toupper($2) ~ /VARCHAR/)
        print ",:"attr  >> "castoutput.txt"
else
        print ",CAST(:"attr" AS "$0")" >> "castoutput.txt"

}' < Tmp1_${LAYOUT_FILE} > Tmp_${LAYOUT_FILE}

sed -i '1s/^,//' castoutput.txt

#Create insert clause values

awk ' { if (NR ==1) { print $1 } else { print ","$1}} ' Tmp1_${LAYOUT_FILE} > Column_list.txt

#Generate Mload script to load extract to work table


echo ".logtable ${LOG_TBL};
.RUN FILE ${TERA_DB_LOGON};
.begin import mload tables ${WORK_TBL};

.layout ${table_name}_layout ;
`cat Tmp_${LAYOUT_FILE}`


.dml label ${table_name}_insert;
insert into ${WORK_TBL}
(
`cat Column_list.txt`
)
 values
(
`cat castoutput.txt`
);

.import infile ${EXTRACT_NM}
format vartext '|'
layout ${table_name}_layout
apply ${table_name}_insert;

.end mload;

.logoff; " >${MLOAD_SCRIPT};


#Create validation queries

echo "
/*Validation of data between the target table and extract loaded to work table*/

bteq <<bteqend 1>${BTEQ_LOG_FILE} 2>&1

.SESSIONS 1;
.RUN FILE ${TERA_DB_LOGON};

/*Validate source minus target data */

Select
`cat Column_list.txt`
from
${WORK_TBL}
minus
Select
`cat Column_list.txt`
from
${tgt_tbl};

.IF ACTIVITYCOUNT <>0 THEN .QUIT 10

/*Validate target minus source data */


Select
`cat Column_list.txt`
from  ${tgt_tbl}
minus
Select
`cat Column_list.txt`
from
${WORK_TBL};

.IF ACTIVITYCOUNT <>0 THEN .QUIT 20

.LOGOFF
.QUIT 0;

bteqend

" > Validation_${table_name}.btq

#Remove the temp files
rm Tmp1_${LAYOUT_FILE};
rm Tmp_${LAYOUT_FILE};
rm Column_list.txt
rm castoutput.txt;
