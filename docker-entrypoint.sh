#!/bin/bash
set -e
export PYTHONPATH=${MIST_HOME}/src/main/python:${SPARK_HOME}/python/:`readlink -f ${SPARK_HOME}/python/lib/py4j*`:${PYTHONPATH}
cd ${MIST_HOME}

if [ "$1" = 'tests' ]; then
  ./sbt/sbt -DsparkVersion=${SPARK_VERSION} -Dconfig.file=src/test/resources/tests-${SPARK_VERSION}.conf "project examples" clean package "project mist" clean assembly test
elif [ "$1" = 'mist' ]; then
  if [ -e "configs/user.conf" ]; then
    cp -f configs/user.conf configs/docker.conf
  fi
  export IP=`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
  echo "$IP    master" >> /etc/hosts
  sed -i "s/leader/$IP/" configs/docker.conf
  ./bin/mist start master --config configs/docker.conf
elif [ "$1" = 'worker' ]; then
  if [ ! -z $3 ]; then
    echo $3 | base64 -d  > configs/docker.conf
  fi
  export IP=`getent hosts master | awk '{ print $1 }'`
  sed -i "s/leader/$IP/" configs/docker.conf
  ./bin/mist start worker --runner local --namespace $2 --config configs/docker.conf $4
# FIX UP
elif [ "$1" = 'mist-ecs' ]; then
  if [ -e "configs/ecs.conf" ]; then
    cp -f configs/ecs.conf configs/docker.conf
  fi
  sed -i "s/mist-hostname/mist-master/" configs/docker.conf
  mkdir -p ~/.aws/
  echo -e "[default]\noutput = json\nregion = eu-west-1" > ~/.aws/config
  ./bin/mist start master --config configs/docker.conf
elif [ "$1" = 'worker-ecs' ]; then
  if [ -e "configs/ecs.conf" ]; then
    cp -f configs/ecs.conf configs/docker.conf
  fi
  mkdir -p ~/.aws/
  echo -e "[default]\noutput = json\nregion = eu-west-1" > ~/.aws/config
  $SPARK_HOME/sbin/start-master.sh -h 0.0.0.0
  export IP=`ifconfig ethwe 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`
  sed -i "s/mist-hostname/$IP/" configs/docker.conf
  ./bin/mist start worker --runner local --namespace $2 --config configs/docker.conf $3
elif [ "$1" = 'dev' ]; then
  ./sbt/sbt -DsparkVersion=${SPARK_VERSION} assembly
  ./sbt/sbt -DsparkVersion=${SPARK_VERSION} "project examples" package
  ./bin/mist start master --config configs/docker.conf
else
  exec "$@"
fi
