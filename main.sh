#!/bin/bash

# Loud fan control script to lower speed of fan based on current
# max temperature of any cpu
#
# See README.md for details.

#set to false to suppress logs
DEBUG=false


TEMPERATURE_FILE="/sys/devices/virtual/thermal/thermal_zone0/temp"
FAN_MODE_FILE="/sys/devices/platform/pwm-fan/hwmon/hwmon0/automatic"
FAN_SPEED_FILE="/sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1"
TEST_EVERY="3" #seconds
new_fan_speed_default="100"
LOGGER_NAME=odroid-xu4-fan-control

#make sure after quiting script fan goes to auto control
function cleanup {
  ${DEBUG} && logger -t $LOGGER_NAME "event: quit; temp: auto"
  echo 1 > ${FAN_MODE_FILE}
}
trap cleanup EXIT

function exit_xu4_only_supported {
  ${DEBUG} && logger -t $LOGGER_NAME "event: non-xu4 $1"
  exit 2
}
if [ ! -f $TEMPERATURE_FILE ]; then
  exit_xu4_only_supported "a"
elif [ ! -f $FAN_MODE_FILE ]; then  exit_xu4_only_supported "b"
elif [ ! -f $FAN_SPEED_FILE ]; then
  exit_xu4_only_supported "c"
fi

function round()
{
  printf "%.0f\n" $1
};

current_max_temp=`cat ${TEMPERATURE_FILE} | cut -d: -f2 | sort -nr | head -1`
echo "fan control started. Current max temp: ${current_max_temp}"
echo "For more logs see:"
echo "sudo tail -f /var/log/syslog"

kscale=5

current_fan_speed=0
speed_0=70
speed_1=250
temp_0=40
temp_1=70

kP=0.20000
kI=0.10000
kD=0.10000

vP=0
vI=0
vD=0

step=$(bc <<< "scale=$kscale;($speed_1-$speed_0)/($temp_1-$temp_0)")

diff_old=0

while [ true ];
do
  ${DEBUG} && logger -t $LOGGER_NAME "##################################"

  echo "0" > ${FAN_MODE_FILE} #to be sure we can manage fan

  current_max_temp=$(cat ${TEMPERATURE_FILE} | cut -d: -f2 | sort -nr | head -1)
  current_max_temp=$(bc <<< "scale=0;$current_max_temp/1000")
  ${DEBUG} && logger -t $LOGGER_NAME "event: read_max; temp: ${current_max_temp}"
  
  goal=$(bc <<< "scale=$kscale;$step*($current_max_temp-$temp_0)+$speed_0")
  diff=$(bc <<< "scale=$kscale;$goal-$current_fan_speed")

  ${DEBUG} && logger -t $LOGGER_NAME "goal:$goal"
  ${DEBUG} && logger -t $LOGGER_NAME "diff:$diff"
  ${DEBUG} && logger -t $LOGGER_NAME "diff_old:$diff_old"

  vP=$(bc <<< "scale=$kscale;$diff*$kP")
  ${DEBUG} && logger -t $LOGGER_NAME "vP:$vP"

  vI=$(bc <<< "scale=$kscale;$vI+$kI*$diff")
  ${DEBUG} && logger -t $LOGGER_NAME "vI:$vI"

  vD=$(bc <<< "scale=$kscale;($diff+$diff_old*(-1))*$kD")
  ${DEBUG} && logger -t $LOGGER_NAME "vD:$vD"

  diff_old=$diff
  current_fan_speed=$(bc <<< "scale=$kscale;$current_fan_speed+$vP+$vI+$vD")

  write_fan_speed=$(round $current_fan_speed)
  
  if (( $(bc <<< "$write_fan_speed<$speed_0") )); then
    write_fan_speed=0
  elif (( $(bc <<< "$write_fan_speed>$speed_1") )); then
    write_fan_speed=255
  fi

  ${DEBUG} && logger -t $LOGGER_NAME "New Fan Speed: $write_fan_speed"
  ${DEBUG} && logger -t $LOGGER_NAME "Current Temp: $current_max_temp"

  logger -t $LOGGER_NAME "event: adjust; speed: ${write_fan_speed}; temp: $current_max_temp"
  echo $write_fan_speed > ${FAN_SPEED_FILE}

  sleep ${TEST_EVERY}
done
