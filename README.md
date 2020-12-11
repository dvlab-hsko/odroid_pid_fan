# odroid_pid_fan
PID control for fan speed (delayed fan curve)

# Installation

```bash
cp odroid-pid-fan.service /etc/systemd/system/
systemctl daemon-reload

// Start the service
systemctl start odroid-pid-fan

// Check that it is running
systemctl status odroid-pid-fan

// Run the script at boot
systemctl enable odroid-pid-fan
