# RG353V PWM rumble parameters for UnofficialOS.
export RUMBLE_PERIOD="${RUMBLE_PERIOD:-20000000}"
export RUMBLE_ACTIVE_DUTY="${RUMBLE_ACTIVE_DUTY:-10000000}"
export RUMBLE_IDLE_DUTY="${RUMBLE_IDLE_DUTY:-20000000}"

rumble_helper_pid=""
if [ -x "$GAMEDIR/tools/rumble-helper" ]; then
  echo "Starting rumble-helper..."
  "$GAMEDIR/tools/rumble-helper" &
  rumble_helper_pid=$!
else
  echo "No rumble-helper found at $GAMEDIR/tools/rumble-helper"
fi

# Run game here...

if [ -n "$rumble_helper_pid" ]; then
  echo "Stopping rumble-helper pid $rumble_helper_pid..."
  kill "$rumble_helper_pid" 2>/dev/null || true
fi

if [ -d /sys/class/pwm/pwmchip1/pwm0 ]; then
  echo 0 > /sys/class/pwm/pwmchip1/pwm0/enable 2>/dev/null || true
  echo inversed > /sys/class/pwm/pwmchip1/pwm0/polarity 2>/dev/null || true
  echo "$RUMBLE_PERIOD" > /sys/class/pwm/pwmchip1/pwm0/period 2>/dev/null || true
  echo "$RUMBLE_IDLE_DUTY" > /sys/class/pwm/pwmchip1/pwm0/duty_cycle 2>/dev/null || true
  echo 1 > /sys/class/pwm/pwmchip1/pwm0/enable 2>/dev/null || true
fi