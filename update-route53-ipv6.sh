#!/bin/bash

# troubleshooting file
exec > /tmp/debug-my-script.txt 2>&1

echo Path is: $PATH
echo User is: $USER

# AWS Hosted Zone ID
ZONEID="Your ZoneID here"
echo Zone Id: $ZONEID

# The CNAME you want to update e.g. hello.example.com
RECORDSET=`/usr/bin/hostnamea`
echo Record Set: $RECORDSET

# More advanced options below
# The Time-To-Live of this recordset
TTL=60
# Change this if you want
COMMENT="Auto updating @ `date`"
# Change to AAAA if using an IPv6 address
TYPE="AAAA"

# Get the external IP address
IP=`dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{ print $2}'`
#IP=`wget -qO- http://instance-data/latest/meta-data/public-ipv4`
echo Got IP address: $IP

# Get current dir (stolen from http://stackoverflow.com/a/246128/920350)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo Current directory is: $DIR

LOGFILE="$DIR/update-route53.log"
IPFILE="$DIR/update-route53.ip"
#LOGFILE="$HOME/update-route53.log"
#IPFILE="$HOME/update-route53.ip"

#if ! valid_ip $IP; then
#    echo "Invalid IP address: $IP" >> "$LOGFILE"
#    exit 1
#fi
#echo Valid IP address.

# Check if the IP has changed
if [ ! -f "$IPFILE" ]
    then
    touch "$IPFILE"
fi

if grep -Fxq "$IP" "$IPFILE"; then
    # code if found
    echo "IP is still $IP. Exiting" >> "$LOGFILE"
    exit 0
else
    echo "IP has changed to $IP" >> "$LOGFILE"
    # Fill a temp file with valid JSON
    TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
    cat > ${TMPFILE} << EOF
    {
      "Comment":"$COMMENT",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$IP"
              }
            ],
            "Name":"$RECORDSET",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

    # Update the Hosted Zone record
    aws route53 change-resource-record-sets --hosted-zone-id $ZONEID --change-batch file://"$TMPFILE" >> "$LOGFILE"
    echo "" >> "$LOGFILE"

    # Clean up
    rm $TMPFILE
fi

# All Done - cache the IP address for next time
echo "$IP" > "$IPFILE"

echo Route53 update finished
