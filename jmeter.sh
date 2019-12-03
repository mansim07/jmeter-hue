#!/bin/bash

export CONF_DIR="$( cd -P "$( dirname "$0" )" && pwd )"
SCRIPT_DIR=${CONF_DIR}
JAVA_VER=$(java -version 2>&1 | grep -i version | sed 's/.*version ".*\.\(.*\)\..*"/\1/; 1q')

if [[ ${JAVA_VER} -lt 8 ]]
then
  JAVA_HOME=${SCRIPT_DIR}/jdk1.8.0_144
  if [[ ! -d ${JAVA_HOME} ]]
  then
    wget -O ${SCRIPT_DIR}/jdk-8u144-linux-x64.tar.gz http://clr.sec.cloudera.com/configcloudcat/jdk-8u144-linux-x64.tar.gz
    tar -zxvf ${SCRIPT_DIR}/jdk-8u144-linux-x64.tar.gz -C ${SCRIPT_DIR}
  fi
  PATH=${JAVA_HOME}/bin:$PATH
fi

#parse command line arguments
parse_arguments()
{
  # Test that we're using compatible getopt version.
  getopt -T > /dev/null
  if [[ $? -ne 4 ]]; then
    echo "Incompatible getopt version."
    exit 1
  fi

  # Parse short and long option parameters.

  GUI=true
  SCRIPTFILE=HueHiveImpala514.jmx
  USERPROPERTIES=user.properties
  PROXYHOST=
  PROXYPORT=3128
  THREADS=1
  PROT=http
  HOST=cconner59-1.gce.cloudera.com
  PORT=8889
  USERSFILE=users.csv
  IPSFILE=iplist.csv
  RAMPTIME=60

  GETOPT=`getopt -n $0 -o n,t:,p:,z:,y:,x:,r:,s,H:,P:,u:,j:,v,h \
      -l disablegui,scriptfile:,userprop:,proxyhost:,proxyport:,threads:,ramptime:,ssl,host:,port:,usersfile:,jmeterhome:,verbose,help \
      -- "$@"`
  eval set -- "$GETOPT"
  while true;
  do
    case "$1" in
    -n|--disablegui)
      GUI=
      shift
      ;;
    -t|--scriptfile)
      SCRIPTFILE=$2
      shift 2
      ;;
    -p|--userprop)
      USERPROPERTIES=$2
      shift 2
      ;;
    -z|--proxyhost)
      PROXYHOST=$2
      shift 2
      ;;
    -y|--proxyport)
      PROXYPORT=$2
      shift 2
      ;;
    -x|--threads)
      THREADS=$2
      shift 2
      ;;
    -r|--ramptime)
      RAMPTIME=$2
      shift 2
      ;;
    -s|--ssl)
      PROT=https
      shift
      ;;
    -H|--host)
      HOST=$2
      shift 2
      ;;
    -P|--port)
      PORT=$2
      shift 2
      ;;
    -u|--usersfile)
      USERSFILE=$2
      shift 2
      ;;
    -j|--jmeterhome)
      JMETER_HOME=$2
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      usage
      exit 1
      ;;
    esac
  done
  #
  if [[ -z ${JMETER_HOME} ]]
  then
    if [[ -f ${SCRIPT_DIR}/../jmeter/bin/jmeter.sh ]]
    then
      JMETER_SCRIPT=${SCRIPT_DIR}/../jmeter/bin/jmeter.sh
    elif [[ -f /opt/jmeter/bin/jmeter.sh ]]
    then
      JMETER_SCRIPT=/opt/jmeter/bin/jmeter.sh
    fi
    if [[ -z ${JMETER_SCRIPT} ]]
    then
      JMETER_SCRIPT=$(locate jmeter.sh || echo "FAILED")
      JMETER_SCRIPT=$(echo ${JMETER_SCRIPT} | awk '{print $1}')
      if [[ ! -f ${JMETER_SCRIPT} ]]
      then
        echo "Unable to find jmeter.sh"
	echo "Please install jmeter and set '--jmeterhome' option"
	usage
	exit 1
      fi
    fi
  else
    if [[ -f ${JMETER_HOME}/bin/jmeter.sh ]]
    then
      JMETER_SCRIPT=${JMETER_HOME}/bin/jmeter.sh
    else
      echo "Could not find jmeter.sh in ${JMETER_HOME}"
      usage
      exit 1
    fi
  fi

}

usage()
{
cat << EOF
usage: $0 [options]

Jmeter Wrapper for Hue:

OPTIONS
   -n|--disablegui         Disable gui to run on remote systems or in a script
   -t|--scriptfile	   JMX script file to run
   -p|--userprop	   Custom user properties file
   -z|--proxyhost	   Custom HTTP proxy host
   -y|--proxyport	   Custom HTTP proxy port
   -x|--threads		   Number of concurrent threads
   -r|--ramptime	   Thread ramp time
   -s|--ssl		   Enable SSL
   -H|--host		   Hue Host
   -P|--port		   Hue Port
   -u|--usersfile	   List of users username,password
   -v|--verbose            Enable verbose logging
   -h|--help               Show this message.
EOF
}

main()
{

  parse_arguments "$@"

  USERSFILE=${CONF_DIR}/${USERSFILE}
  IPSFILE=${CONF_DIR}/${IPSFILE}
  USERPROPERTIES=${CONF_DIR}/${USERPROPERTIES}
  SCRIPTFILEBASE=$(echo ${SCRIPTFILE} | awk -F\. '{print $1}')
  SCRIPTFILE=${CONF_DIR}/${SCRIPTFILE}
  RESPONSE_LOG_PREFIX=${CONF_DIR}/../response_logs/${SCRIPTFILEBASE}
  mkdir -p ${RESPONSE_LOG_PREFIX}

  JMETER_OPTS="-Djava.security.krb5.conf=${CONF_DIR}/krb5.conf -Djava.security.auth.login.config=${CONF_DIR}/jaas.conf"
#  JMETER_OPTS="-Dsun.security.krb5.debug=true -Djava.security.krb5.conf=${CONF_DIR}/krb5.conf -Djava.security.auth.login.config=${CONF_DIR}/jaas.conf"
  JVM_ARGS="-Djava.security.krb5.conf=${CONF_DIR}/krb5.conf -Djava.security.auth.login.config=${CONF_DIR}/jaas.conf -Dlog4j.configurationFile=${CONF_DIR}/log4j2.xml"
#  JVM_ARGS="-Dsun.security.krb5.debug=true -Djava.security.krb5.conf=${CONF_DIR}/krb5.conf -Djava.security.auth.login.config=${CONF_DIR}/jaas.conf"

  export KRB5_CONFIG=${CONF_DIR}/krb5.conf
  export JMETER_OPTS JVM_ARGS
  COMMAND="${JMETER_SCRIPT}"

  if [[ -f /etc/redhat-release ]]
  then
    IPCOMMAND="ip addr show"
  else
    IPCOMMAND="ifconfig -a"
  fi

  ${IPCOMMAND} | grep inet | grep -v "inet6\|127.0.0.1\|192.168" | awk '{print $2}' | awk -F\/ '{print $1}' > ${IPSFILE}

  if [[ -z ${GUI} ]] || [[ -f /etc/redhat-release ]]
  then
    COMMAND="${COMMAND} -n"
  fi

  COMMAND="${COMMAND} -t ${SCRIPTFILE} -p ${USERPROPERTIES} -JTHREADS=${THREADS} -JRAMPTIME=${RAMPTIME}"
  COMMAND="${COMMAND} -JPROT=${PROT} -JHOST=${HOST} -JPORT=${PORT} -JUSERSFILE=${USERSFILE} -JIPSFILE=${IPSFILE}"
  COMMAND="${COMMAND} -JRESPONSE_LOG_PREFIX=${RESPONSE_LOG_PREFIX}"
  COMMAND="${COMMAND} -l chris.csv"
  if [[ ! -z ${PROXYHOST} ]]
  then
    COMMAND="${COMMAND} -H ${PROXYHOST} -P ${PROXYPORT}"
  fi

  echo "${COMMAND}"
  ${COMMAND}

}

main "$@"
