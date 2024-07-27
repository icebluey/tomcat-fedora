#!/bin/bash

# functions

if [ -r /usr/share/java-utils/java-functions ]; then
  . /usr/share/java-utils/java-functions
else
  echo "Can't read Java functions library, aborting"
  exit 1
fi

_save_function() {
    local ORIG_FUNC=$(declare -f $1)
    local NEWNAME_FUNC="$2${ORIG_FUNC#$1}"
    eval "$NEWNAME_FUNC"
}

run_jsvc(){
    if [ -x /usr/bin/jsvc ]; then
        TOMCAT_USER="${TOMCAT_USER:-tomcat}"
        JSVC="/usr/bin/jsvc"

        JSVC_OPTS="-nodetach -pidfile /var/run/jsvc-tomcat${NAME}.pid -user ${TOMCAT_USER} -outfile ${CATALINA_BASE}/logs/catalina.out -errfile ${CATALINA_BASE}/logs/catalina.out"
        if [ "$1" = "stop" ]; then
            JSVC_OPTS="${JSVC_OPTS} -stop"
    	fi

        exec "${JSVC}" ${JSVC_OPTS} ${FLAGS} -classpath "${CLASSPATH}" ${OPTIONS} "${MAIN_CLASS}" "${@}"
    else
       	echo "Can't find /usr/bin/jsvc executable"
    fi

}

_save_function run run_java

run() {
   if [ "${USE_JSVC}" = "true" ] ; then
	run_jsvc $@
   else
	run_java $@
   fi
}

###############################################################################
# preamble

# Get the tomcat config (use this for environment specific settings)

if [ -z "${TOMCAT_CFG_LOADED}" ]; then
  if [ -z "${TOMCAT_CFG}" ]; then
    TOMCAT_CFG="/etc/tomcat/tomcat.conf"
  fi
  . $TOMCAT_CFG
fi

if [ -d "${TOMCAT_CONFD=/etc/tomcat/conf.d}" ]; then
  for file in ${TOMCAT_CONFD}/*.conf ; do
    if [ -f "$file" ] ; then
      . "$file"
    fi
  done
fi

if [ -z "$CATALINA_BASE" ]; then
  if [ -n "$NAME" ]; then
    if [ -z "$TOMCATS_BASE" ]; then
      TOMCATS_BASE="/var/lib/tomcats/"
    fi
    CATALINA_BASE="${TOMCATS_BASE}${NAME}"
  else
    CATALINA_BASE="${CATALINA_HOME}"
  fi
fi
VERBOSE=1
set_javacmd
cd ${CATALINA_HOME}
# CLASSPATH munging
if [ ! -z "$CLASSPATH" ] ; then
  CLASSPATH="$CLASSPATH":
fi

if [ -n "$JSSE_HOME" ]; then
  CLASSPATH="${CLASSPATH}$(build-classpath jcert jnet jsse 2>/dev/null):"
fi
CLASSPATH="${CLASSPATH}${CATALINA_HOME}/bin/bootstrap.jar"
CLASSPATH="${CLASSPATH}:${CATALINA_HOME}/bin/tomcat-juli.jar"
CLASSPATH="${CLASSPATH}:$(build-classpath commons-daemon 2>/dev/null)"

if [ -z "$LOGGING_PROPERTIES" ] ; then
  LOGGING_PROPERTIES="${CATALINA_BASE}/conf/logging.properties"
  if [ ! -f "${LOGGING_PROPERTIES}" ] ; then
    LOGGING_PROPERTIES="${CATALINA_HOME}/conf/logging.properties"
  fi
fi

###############################################################################
# server

MAIN_CLASS=org.apache.catalina.startup.Bootstrap

FLAGS="$JAVA_OPTS"
OPTIONS="-Dcatalina.base=$CATALINA_BASE \
-Dcatalina.home=$CATALINA_HOME \
-Djava.endorsed.dirs=$JAVA_ENDORSED_DIRS \
-Djava.io.tmpdir=$CATALINA_TMPDIR \
-Djava.util.logging.config.file=${LOGGING_PROPERTIES} \
-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager"

if [ "$1" = "start" ] ; then
  FLAGS="${FLAGS} $CATALINA_OPTS"
  if [ "${SECURITY_MANAGER}" = "true" ] ; then
    OPTIONS="${OPTIONS} \
    -Djava.security.manager \
    -Djava.security.policy==${CATALINA_BASE}/conf/catalina.policy"
  fi
  run start
elif [ "$1" = "stop" ] ; then
  run stop
fi

