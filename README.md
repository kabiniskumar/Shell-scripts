# Shell-scripts

In a typical datawarehousing scenario to perform manual validation of extracts, we pick a sample of records from the extract and validate the data against a target table. This process is prone to errors since the tester is not validating the whole dataset.

One solution to address this problem would be to load the entire extract to a temporary table using a mload script and validate it against the target table. But writing mload scripts needs such degree of expertise and can be time consuming as well.


This document explains the functionality of a mload generator script which takes as input, the layout of the extract that is to be validated and generates a mload script which can be readily executed to load the contents of the file to a work table.
In addition, this script also generates a bteq validation script to validate the data between the work table and the target table.


# Input files used: 

**teraload.logon** : This file should contain the logon details of the Teradata host in the below format

            cat teraload.logon
            .logon ip/username,password;

**extract_path.txt** : This file contains the extract file name(informatica generated LRF/source LRF) along with the path.

**extract_layout.txt** : This file contains the layout of the extract file.The user has to input the column names with the data type in the below format to this file. 

  Example: 
  
            cat extract_layout.txt
            acct_id INTEGER,
            parm_nm VARCHAR(50),
            pst_dt DATE FORMAT 'YYYY-MM-DD',
            gk_amt NUMERIC(15,2)

**Mload generator script**: mload_gen.ksh


# How to generate mload scripts

Execute the mload generator script after configuring the extract path and extract layout file with the below run command.


	ksh mload_gen.ksh
  
  The script will prompt for the target table name in the format \[SCHEMA.TABLE\]
  

# Output files generated:

**\<tablename\>.mload** : This is the mload script that needs to be executed to load the extract to work table.
  
**Validation_\<tablename\>.btq** : This is the bteq script that can be used for data validation between the work table and target table.

The script executes and formats the layout file according to mload standards and generates a mload script which can be readily executed.
It also generates a validation bteq that can be executed to perform source-minus-target and target-minus-source comparisons.


The user has the privilege to edit the mload/bteq scripts to accommodate any changes that he feels is necessary before the load/validation. 


Once the mload and bteq scripts are generated, use the below commands to execute the scripts


	mload < [tablename].mload > [tablename].log

On successful execution of the mload, proceed with the bteq validation using the below command.


	bteq < Validation_[tablename].btq > Validation_[tablename].log


If the bteq query returns zero records for source-minus-target and target-minus-source validations, we can conclude that the data in the target is correct with zero uncertainty. 


  


  


