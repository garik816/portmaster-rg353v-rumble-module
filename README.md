# PortMaster RG353V PWM Rumble Module

**Maintenance status:** This repository is superseded by [portmaster-rg353v-addons](https://github.com/garik816/portmaster-rg353v-addons), which contains the current rumble helper, additional mods, installer and tests. Historical instructions remain below.


Portable rumble helper tested on Anbernic RG353V running UnofficialOS.

It drives the vibration motor directly through sysfs PWM:

```sh
/sys/class/pwm/pwmchip1/pwm0
```

Working parameters found during testing:

```sh
RUMBLE_PERIOD=20000000
RUMBLE_ACTIVE_DUTY=10000000
RUMBLE_IDLE_DUTY=20000000
polarity=inversed
```

With `polarity=inversed`, lower `RUMBLE_ACTIVE_DUTY` usually means stronger vibration.

## Files

```text
tools/rumble-helper
```

Generic Python helper. It can:

- pulse the PWM motor manually;
- run in the background and rumble on gamepad button presses;
- listen on `/tmp/stardew-rumble` FIFO for commands from a game/mod/script.

```text
tools/sudo-shim-for-hardcoded-sudo
```

Optional shim for games that call hardcoded commands like:

```sh
echo 450000 | sudo tee /sys/class/pwm/pwmchip1/pwm0/duty_cycle
```

This was used to fix Cave Story-evo on UnofficialOS.

## Manual Test

Copy `tools/rumble-helper` into a port's tools folder and make it executable:

```sh
chmod 755 tools/rumble-helper
./tools/rumble-helper test 250
```

Stronger test:

```sh
RUMBLE_ACTIVE_DUTY=5000000 ./tools/rumble-helper test 500
```

Weaker test:

```sh
RUMBLE_ACTIVE_DUTY=15000000 ./tools/rumble-helper test 500
```

Return motor to idle manually:

```sh
p=/sys/class/pwm/pwmchip1/pwm0
echo 20000000 > $p/period
echo inversed > $p/polarity 2>/dev/null || true
echo 20000000 > $p/duty_cycle
echo 1 > $p/enable
```

## PortMaster Launcher Integration

Assume your port has this layout:

```text
ports/myport.sh
ports/myport/tools/rumble-helper
```

Add this before launching the game binary:

```sh
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
```

After the game exits, add cleanup:

```sh
if [ -n "$rumble_helper_pid" ]; then
  echo "Stopping rumble-helper pid $rumble_helper_pid..."
  kill "$rumble_helper_pid" 2>/dev/null || true
fi

# Return PWM rumble to idle in case the helper was stopped during a pulse.
if [ -d /sys/class/pwm/pwmchip1/pwm0 ]; then
  echo 0 > /sys/class/pwm/pwmchip1/pwm0/enable 2>/dev/null || true
  echo inversed > /sys/class/pwm/pwmchip1/pwm0/polarity 2>/dev/null || true
  echo "$RUMBLE_PERIOD" > /sys/class/pwm/pwmchip1/pwm0/period 2>/dev/null || true
  echo "$RUMBLE_IDLE_DUTY" > /sys/class/pwm/pwmchip1/pwm0/duty_cycle 2>/dev/null || true
  echo 1 > /sys/class/pwm/pwmchip1/pwm0/enable 2>/dev/null || true
fi
```

If the launcher uses lowercase `gamedir` instead of `GAMEDIR`, use `$gamedir/tools/rumble-helper` instead.

## FIFO Commands

When `rumble-helper` is running, it creates:

```sh
/tmp/stardew-rumble
```

Trigger a pulse:

```sh
echo "pulse 250" > /tmp/stardew-rumble
```

Custom duty:

```sh
echo "pulse 250 5000000" > /tmp/stardew-rumble
```

This is the preferred interface for a game mod or wrapper script.

## Button-Based Rumble

By default, the helper listens to `retrogame_joypad` and triggers on:

```text
A/B/X/Y/L/R/L2/R2
```

Linux event codes:

```text
304, 305, 307, 308, 310, 311, 312, 313
```

It intentionally avoids dpad/start/select so normal movement and menus do not rumble constantly.

## Cave Story-evo Hardcoded sudo Fix

Some builds call:

```sh
echo 450000 | sudo tee /sys/class/pwm/pwmchip1/pwm0/duty_cycle
sleep 0.10
echo 1000000 | sudo tee /sys/class/pwm/pwmchip1/pwm0/duty_cycle
```

On UnofficialOS, `sudo` may not exist and those old duty values are not the working RG353V values.

Install the shim:

```sh
mkdir -p "$GAMEDIR/tools"
cp tools/sudo-shim-for-hardcoded-sudo "$GAMEDIR/tools/sudo"
chmod 755 "$GAMEDIR/tools/sudo"
```

Then before launching the game:

```sh
export PATH="$GAMEDIR/tools:$PATH"
export RUMBLE_PERIOD="${RUMBLE_PERIOD:-20000000}"
export RUMBLE_ACTIVE_DUTY="${RUMBLE_ACTIVE_DUTY:-10000000}"
export RUMBLE_IDLE_DUTY="${RUMBLE_IDLE_DUTY:-20000000}"
```

The shim maps:

```text
450000  -> 10000000
1000000 -> 20000000
```

## Notes

- This is not Linux `EV_FF` / `FF_RUMBLE` force feedback.
- UnofficialOS kernel tested here did not expose `INPUT_PWM_VIBRA` or a force-feedback input device.
- This module is raw sysfs PWM control, so it is device/firmware-specific.
- Always restore idle duty after tests to avoid leaving the motor running.