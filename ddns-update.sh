#!/usr/bin/env bash
#    BSD 3-Clause License
#    
#    Copyright (c) 2024, Brendan Bank
#    All rights reserved.
#    
#    Redistribution and use in source and binary forms, with or without
#    modification, are permitted provided that the following conditions are met:
#    
#    1. Redistributions of source code must retain the above copyright notice, this
#       list of conditions and the following disclaimer.
#    
#    2. Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#    
#    3. Neither the name of the copyright holder nor the names of its
#       contributors may be used to endorse or promote products derived from
#       this software without specific prior written permission.
#    
#    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

script_name=$(basename "$0")

IFCONFIG_CMD=$(type -P ifconfig)
IFCONFIG_CMD_EXEC="${IFCONFIG_CMD} -l -u inet"
IP_CMD=$(type -P ip)
IP_CMD_EXEC="${IP_CMD} -o link show"
ERROR_TXT=""

echoerr_usage() { 
    echo "ERR: $@" 1>&2
    echo "${usage}" 1>&2
    exit 1
    }
    
echoerr() { 
    echo "ERR: $@" 1>&2
    exit 1
    }
 
echoverbose (){
    if [ "${VERBOSE}" == 1 ]; then
		echo "$@"
	else
		VERBOSE_TXT="$@"
		ERROR_TXT="${ERROR_TXT}
${VERBOSE_TXT}"
	fi
}

FETCHAPPS="curl"

for app in $FETCHAPPS; do
    FETCHAPP="$(type -P "$app")"
    [ ! -z "$FETCHAPP" ] && FETCHAPP="$app:$FETCHAPP" && break
done

[ -z "$FETCHAPP" ]  && echoerr "could not find http fetching app's: $FETCHAPPS"

NSUPDATE_APP="$(type -P "nsupdate")"
[ -z "$NSUPDATE_APP" ] && echoerr "could not fine executable 'nsupdate' in PATH directories"


getfetchapp () {
    APP=${FETCHAPP%:*}
    APP_EXEC=${FETCHAPP#*:}
    
    case $APP in
        curl) 
            APP_EXEC_ARG="${APP_EXEC} -s -$IPCLASS --show-error"
            ;;
        fetch)
            APP_EXEC_ARG="${APP_EXEC}"
            ;;
        wget)
            APP_EXEC_ARG="${APP_EXEC} --quiet -O- http://ifconfig.me"
            ;;
    esac
    
    if [ ! -z ${INTERFACE} ]; then
        APP_EXEC_ARG="${APP_EXEC_ARG} --interface $INTERFACE"
    fi
    
    APP_EXEC_ARG="${APP_EXEC_ARG} http://ifconfig.me"
    
    echoverbose "Fetch App found: $APP: $APP_EXEC_ARG"
}

checkinterface () {

    if [ ! -z ${IP_CMD} ] && [ -x ${IP_CMD} ] ; then
        INTERFACES=$($IP_CMD_EXEC | awk -F': ' '{print $2}' )
    elif [ ! -z ${IFCONFIG_CMD} ] && [ -x ${IFCONFIG_CMD} ] ; then
        INTERFACES=$($IFCONFIG_CMD_EXEC)
    else
        echoerr "Could not find ${IP_CMD} or ${IFCONFIG_CMD} insure the correct directories are in the PATH variable"
    fi
    
    INTERFACE_FOUND=false
    echoverbose "Check if interface $INTERFACE in INTERFACES:" $INTERFACES
    for I in $INTERFACES; do
        [ "$INTERFACE" == $I ] &&  INTERFACE_FOUND=true && break
    done

    if [ $INTERFACE_FOUND == false ] ; then
        echoerr "Could not find INTERFACE '${INTERFACE}' valid interfaces are: $INTERFACES"
    fi
}


checkipaddress () {
    CHECK_RR_IP=$1
    CHECK_RR_IPCLASS=$2
    echoverbose "checking if valid ip adress $CHECK_RR_IP IPv$CHECK_RR_IPCLASS"
    
    if [ $CHECK_RR_IPCLASS == 4 ] ; then
        regex='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
    else
        regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
    fi
    
    if [[ $CHECK_RR_IP =~ $regex ]]; then
        return 1
    else
        echo "IP Address ${CHECK_RR_IP} is not an valid IPv4 address"
        return 0
    fi
    
}

rrcheckdnsname () {
    RRHOSTNAME=$1
    RRSERVER=$2
    RRTYPE=$3
    echoverbose "Run: dig -4 +short ${RRHOSTNAME}  ${RRTYPE} @${RRSERVER}"
    
    RR_IP=$(dig -4 +short ${RRHOSTNAME}  ${RRTYPE} @${RRSERVER})
    if [ $? != 0 ] ; then
        echoverbose "Something went wrong with nsupdate: "
        echoverbose "dig returned '${RR_IP}'"
        exit 1
    fi

    [ -z ${RR_IP} ]  && return 0
    
    if [[ ! -z ${RR_IP} ]] && [ ${REVERSE} == 1 ]; then
        RR_IP=${RR_IP%?}
        echoverbose "Hostname ${RRHOSTNAME} exists (RR_IP=${RR_IP}" 
        
        return 0
    elif [[ ! -z ${RR_IP} ]] && [ ${REVERSE} == 1 ]; then
        echoverbose "Hostname ${RRHOSTNAME} does not exists"
        return 1
    fi
    
    checkipaddress ${RR_IP} ${IPCLASS}
    if [ $? -eq 1 ]; then
        echoverbose "Hostname ${RRHOSTNAME} exists" 
        return 0
    else
        echoverbose "Hostname ${RRHOSTNAME} does not exists"
        return 1
    fi
    
}

# https://stackoverflow.com/questions/14697403/expand-ipv6-address-in-shell-script @user48678
# helper to convert hex to dec (portable version)
hex2dec(){
    [ "$1" != "" ] && printf "%d" "$(( 0x$1 ))"
}

# https://stackoverflow.com/questions/14697403/expand-ipv6-address-in-shell-script @user48678
# expand an ipv6 address
expand_ipv6() {
    ip=$1

    # prepend 0 if we start with :
    echo $ip | grep -qs "^:" && ip="0${ip}"

    # expand ::
    if echo $ip | grep -qs "::"; then
        colons=$(echo $ip | sed 's/[^:]//g')
        missing=$(echo ":::::::::" | sed "s/$colons//")
        expanded=$(echo $missing | sed 's/:/:0/g')
        ip=$(echo $ip | sed "s/::/$expanded/")
    fi

    blocks=$(echo $ip | grep -o "[0-9a-f]\+")
    set $blocks

    printf "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x\n" \
        $(hex2dec $1) \
        $(hex2dec $2) \
        $(hex2dec $3) \
        $(hex2dec $4) \
        $(hex2dec $5) \
        $(hex2dec $6) \
        $(hex2dec $7) \
        $(hex2dec $8)
}

reverseip6() {
    IPV6=$(expand_ipv6 $1)
    REVERSE_IP=$(echo $IPV6 | awk '{
        gsub(/:/,"")
        for (i=length($0); i>0; i--) {
            printf "%s.", substr($0,i,1)
        }
        print "ip6.arpa"
    }')
    echoverbose "REVERSE_IP = $REVERSE_IP"
}

reverseip4 () {
    FORWARD_IP=$1
    [ -z "$FORWARD_IP" ] && echoerr "reverseip called without an argument!"
    REVERSE_IP=$(echo ${FORWARD_IP} | awk 'BEGIN{FS="."}{print $4"."$3"."$2"."$1".in-addr.arpa"}')
}

makeNSUPDATE_DELETE () {

read -r -d '' NSUPDATE <<EOF
server ${NAMESERVER}
update delete ${HOSTNAME}.  ${RRTYPE}
show
send
quit
EOF

}

makeNSUPDATE () {

read -r -d '' NSUPDATE <<EOF
server ${NAMESERVER}
update delete ${HOSTNAME}.  ${RRTYPE}
update add ${HOSTNAME}.     300      IN     ${RRTYPE} ${MY_IP}
show
send
quit
EOF

}



read -r -d '' usage <<EOF

usage: $script_name [-H HOSTNAME] [-k keyfile] [-6] [-4] [-I INTERFACE] [-n NAMESERVER] [-F] [-v] [-D] [-r] [-l logfile] [-h] []IP ADRESS]

if IP ADRESS is omitted it will query the ip adress from http://ifconfig.me, If -I is given 'fetch' it will use this interface.

    -H             Hostname to set the  resource record to
    -k             Location of the bind keyfile
    -6             Set ipv6 ip adress (if -I is set)
    -4             Set ipv4 ip adress (if -I is set)
    -I             Interface to get the ip address from
    -n             nameserver to update, eg. 1.2.3.4
    -F             Force an update even if the resource record exists 
    -v             Be verbose
    -D             Deletes the resource record (if the resource record exists)
    -r             Sets the reverse IP Adress (1.2.3.4.IN-ADDR.ARPA) to the hostname
    -l             LOGFILE send all log to a seperate logfile including STDERR
    -h             This message
EOF


## Main starting

OPTSTRING=":l:h:I:n:k:H46vFDr"
IPCLASS=4
FORCE_UPDATE=0
DELETE=0
REVERSE=0

while getopts ${OPTSTRING} opt; do
  case ${opt} in
    h) HOSTNAME=${OPTARG} ;;
    4) IPCLASS=4 ;;
    6) IPCLASS=6 ;;
    I) INTERFACE=${OPTARG} ;;
    n) NAMESERVER=${OPTARG} ;;
    F) FORCE_UPDATE=1 ;; # Force update
    v) VERBOSE=1 ;;
    D) DELETE=1 ;;
    r) REVERSE=1 ;;
    l) LOGFILE=${OPTARG} ;;
    k) KEYFILE=${OPTARG} ;;
    H) echo "Help ${usage}"; exit 1 ;;
    :) echoerr_usage "Option -${OPTARG} requires an argument." ;;
    *) echoerr_usage "Unknown option -${OPTARG}" ;;
  esac
done

if [ $OPTIND == 1 ] ; then echoerr_usage "$script_name requires arguments"; fi

# if there is an IP address supplied. Check it.
shift $(($OPTIND - 1))
if [ ! -z "$SETIP" ]; then
    checkipaddress  ${SETIP} ${IPCLASS}
    [ $? -eq 0 ] && echoerr_usage "IP ${SETIP} is not an valid IPv${IPCLASS} address" 
fi

# this redirects STDERR to STDOUT and prints it to the logfile
if [ ! -z "$LOGFILE" ] ; then
    exec > ${LOGFILE} 2>&1
    [ $? != 0 ] && echoerr "Trying to create logfile: ${LOGFILE}" 
    echo "`date`"
fi

# mandatory command line variables.
[ -z "${HOSTNAME}" ] &&  echoerr_usage "HOSTNAME is empty"  
[ -z "${NAMESERVER}" ] &&  echoerr_usage "NAMESERVER is empty" 
[ -z "${KEYFILE}" ] &&  echoerr_usage "KEYFILE is empty" 
[ $IPCLASS == 4 ] && RRTYPE=A || RRTYPE=AAAA

# INTERFACE is optional
[ -z "${INTERFACE}" ] &&  echoverbose "INTERFACE is empty"

if [ "$IPCLASS" -ne 4 ] && [ "$IPCLASS" -ne 6 ] ;then
    echoerr_usage "-6 or -4 is missing" 
fi

#check if the interface exists if supplied.
if [ ! -z $INTERFACE ]; then
    checkinterface
fi

#check key file
[ ! -r "$KEYFILE" ] &&  echoerr "KEYFILE $KEYFILE is does not exists or is note readable."

#check if the nameserver is a valid ip4 address
checkipaddress  $NAMESERVER ${MY_IP} 4
[ $? -eq 0 ] && echoerr_usage "NAMESERVER ${NAMESERVER} is not an valid IPv4 address" 


# if an IP address supplied on commandline set the IP we work with to that.
if [ ! -z ${SETIP} ]; then
    MY_IP=${SETIP}
# if not fetch the IP address of an external source.
else
    getfetchapp
    echoverbose "run: $APP_EXEC_ARG"
    MY_IP=$($APP_EXEC_ARG)
    [ $? != 0 ] && echoerr "APP_EXEC_ARG exited with non 0 exit code." 
	checkipaddress ${MY_IP} ${IPCLASS}
	[ $? -eq 0 ] && echoerr "${MY_IP} is invalid, exiting...."
fi

# if the reverse adress is requested transform MY_IP into a PTR record. 
if [ $REVERSE == 1 ]; then
    if [ $IPCLASS == 4 ]; then
        reverseip4 $MY_IP
    else
        reverseip6 $MY_IP
    fi
    
    MY_IP=$HOSTNAME
    HOSTNAME=$REVERSE_IP
    RRTYPE=PTR

fi
    
# check if the Resource Record exists.
rrcheckdnsname ${HOSTNAME} ${NAMESERVER} ${RRTYPE}
echoverbose "My ip address is $MY_IP / ${RR_IP} / $MY_IP"

# Do not delete is the Resource Record does not exists
if [ -z ${RR_IP} ] && [ ${DELETE} == 1 ] && [ ${FORCE_UPDATE} == 0 ]; then
    echo "There is nothing to delete on server ${NAMESERVER}, hostname ${HOSTNAME} does not exists there. "
    exit 0
# Do not update if the Resource Record is stil the same.
elif [ "${RR_IP}" == "${MY_IP}" ] && [ ${FORCE_UPDATE} == 0 ] && [ ${DELETE} == 0 ]; then
    echo "IP has not changed for $HOSTNAME -> $MY_IP. Exiting...!"
    exit 0
# Delete Resource Record
elif [ ${DELETE} == 1 ] ; then
    makeNSUPDATE_DELETE
# Update/Add Resource Record
else
    makeNSUPDATE
fi

echoverbose "Run NSUPDATE"
echoverbose "$NSUPDATE"
echoverbose ""

RETURN=$(echo "$NSUPDATE" | $NSUPDATE_APP -k $KEYFILE -v)
if [ $? != 0 ] ; then
    echo "Something went wrong with nsupdate: "
    echo "VERBOSE LOG -- $ERROR_TXT"
    echo "NSUPDATE LOG -- $RETURN"
    exit 1
fi

echoverbose ""
echoverbose "$RETURN"
if [ ${DELETE} == 1 ]; then
	echo "Delete Succesful $HOSTNAME -> $MY_IP!"
else
	echo "Update Succesful $HOSTNAME -> $MY_IP!"
fi