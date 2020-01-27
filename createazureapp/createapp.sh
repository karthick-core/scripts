#!/bin/bash
#

ARGS=$(getopt -o a:b:c: -l "login:, password:, subscription:" -- "$@");
echo $ARGS;
eval set -- "$ARGS";

while true
do
  case "$1" in
  -a | --login)
  shift;
  if [ -n "$1" ];then
    login=$1;
   shift;
  fi
  ;;
  -b | --password)
  shift;
  if [ -n "$1" ];then
    password=$1;
   shift;
  fi
  ;;
  -c | --subscription)
  shift;
  if [ -n "$1" ];then
    subscription=$1;
   shift;
  fi
  ;;
  --)
  shift;
  break;
  ;;
  esac
done



lsb_release -a > /dev/null 2>&1
if [ $? -eq 0 ]
then
debian=1
else
debian=0
fi

## Install Azure CLI
az > /dev/null 2>&1
if [ $? -ne 0 ]
then
if [ $debian -eq 0 ]
then
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
sudo yum -y install azure-cli > /dev/null 2>&1
else
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash > /dev/null 2>&1
fi
else
        echo "Azure CLI is already installed"
fi

az > /dev/null 2>&1
if [ $? -ne 0 ]
then
echo "Azure CLI not found. Script cannot continue"
exit
fi


adminUserName=$login
adminPassword=$password
credpass=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo ''`
az login -u $adminUserName -p $adminPassword > /dev/null 2>&1

# Create an app
if [ $? -eq 0 ]
then
echo "Login Success"
az ad app create --display-name 'Corestack-Governance-App' --password $credpass --end-date '2100-12-30' --homepage 'https://cga.corestack.io' --reply-urls 'https://cga.corestack.io/.auth/login/add/callback' --identifier-uris 'https://cga.corestack.io' --required-resource-accesses 'requiredResourceManifest.json' > /tmp/app.json
else
exit
fi
cid=`grep appId /tmp/app.json|awk -F: '{print $NF}'|tr -d '"'|tr -d ','`
tid=`az ad app show --id $cid|grep graph|awk -F/ '{print $4}'`

# Create Service Principal
az ad sp create --id $cid > /dev/null 2>&1

# Get Service Principal ID
ppid=`az ad sp show --id $cid|grep objectId|awk -F: '{print $NF}'|tr -d '"'|tr -d ','`
echo "Service Principal ID: $ppid"

# Create Role assignments
retry=10
i=0

# This loop is to deal with azure time-out issue while creating sp and its role assignments
while [[ $i -lt $retry || $state -eq 0 ]]
do
i=$[$i+1]
az role assignment create --assignee-object-id $ppid --role b24988ac-6180-42a0-ab88-20f7382dd24c --scope /subscriptions/$subscription > /dev/null 2>&1
state=$?
done

az role assignment create --assignee-object-id $ppid --role 36243c78-bf99-498c-9df9-86d9f8d28608 --scope /subscriptions/$subscription > /dev/null 2>&1


# Verify role assignments
az role assignment list --assignee $ppid --subscription $subscription | grep roleDefinitionName
if [[ -n $cid && -n $tid ]]
then
        echo "Script Successfully Executed"
        echo "----------------------------"
        echo "clientId: $cid"
        echo "applicationId: $cid"
        echo "clientSecret: $credpass"
        echo "tenantId: $tid"
fi

rm /tmp/app.json
exit 0

