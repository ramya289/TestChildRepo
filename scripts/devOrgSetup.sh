#!/bin/bash
  
# This is the bash script to create Scratch Org and Install the Base Package and Push Code

# bash scripts/devOrgSetup.sh (Use this command to run this file)

echo "This is the bash script to create Scratch Org and Install the Base Package and Push Code"

# Dev Hub alias name
# If it's not connected with your CLI then run this below command
# sfdx auth:web:login -d -a bwDevHub
# devHub=bwDevHub
devHub=RBWPDevHub

echo "Enter alias Name for Scratch Org: "
read scratch_alias
 
echo "Creating Scratch Org"  
#sfdx force:org:create -v $devHub -a $scratch_alias orgName=$scratch_alias features=PersonAccounts hasSampleData=true -f config/project-scratch-def.json -d 15 -w 5
sfdx force:org:create -v $devHub -a $scratch_alias orgName=$scratch_alias hasSampleData=true -f config/project-scratch-def.json -d 30 -w 5
# -w: The streaming client socket timeout (in minutes).
# -d: Duration of the scratch org (in days) (default:7, min:1, max:30).
echo "=============================================================================" 

# Base Package Version Id
# Before pushing extesnion package code, the Org should have dependency version insatlled in it.
echo "Enter the base package dependency version: "
read basePackageId

echo "Installing the Base Package" 
sfdx force:package:install -u $scratch_alias -p $basePackageId -w 5 -s AllUsers -r
echo "=============================================================================" 

echo "Pushing Code" 
sfdx force:source:push -u $scratch_alias
echo "============================================================================="

#echo "Importing sample data"
#sfdx force:data:tree:import -u $scratch_alias -p sample-data/Account-Contact-Opportunity-plan.json
#echo "=============================================================================" 

echo "Opening Org" 
sfdx force:org:open -u $scratch_alias