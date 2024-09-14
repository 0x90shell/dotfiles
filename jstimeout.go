/*

Script to automatically disable the bluetooth gamepad when
there is no activity for a specified time. It matches /dev/input
with bluetooth mac addresses for DS3 controllers to force a 
BT disconnect. This is necessary, because DS3 timeout cannot be 
configured without a PS3 due to a proprietary timeout implementation 
by Sony.

Use -m or --maxidletime arg to set idle time between 1s and 10800s (3h)
The default idle time is 3600s (1h)

This script uses the dot file ".jstimeout.devices" to identify 
controllers to monitor. Add names from /proc/bus/input/devices 
for any additional controllers that need to be monitored.

Мake the script executable and add it to autorun in desktop mode 
or better yet a systemctl service to recover it if it crashes.i

################################################################
######                 Device List Setup                  ######
################################################################

Devices file must be in same folder as the jstimeout binary.

------
./.jstimeout.devices
------
Sony PLAYSTATION(R)3 Controller
Sony Computer Entertainment Wireless Controller

################################################################
######            [Opt 1] User Service Setup              ######
################################################################

Replace WorkingDirectory path to be where jstimeout & device file 
are located. ExecStart should be the exec path to launch jstimeout.

-------
~/.config/systemd/user/jstimeout.service
------
[Unit]
Description=jstimeout daemon
After=network.target auditd.service
[Service]
ExecStartPre=/bin/sleep 10
Type=idle
WorkingDirectory=/home/user/bin/
ExecStart=/home/user/bin/jstimeout
Restart=on-failure
RestartSec=5
[Install]
WantedBy=default.target

------
Commands 
------
systemctl daemon-reload
systemctl enable --user jstimeout.service
systemctl start --user jstimeout.service

*/

package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/exec" // For executing shell commands
	"strings"
	"sync"
	"time"
)

const eventSize = 24 // Size of struct "llHHI" (as per the Python code)

var specificNames []string

type Device struct {
	Name     string
	Uniq     string
	Handlers []string
}

// Function to read device names from the file
func loadSpecificNames(filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("failed to open file: %v", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" {
			specificNames = append(specificNames, line)
		}
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("error reading file: %v", err)
	}

	return nil
}

func parseInputDevices() ([]Device, error) {
	file, err := os.Open("/proc/bus/input/devices")
	if err != nil {
		return nil, fmt.Errorf("failed to open devices: %v", err)
	}
	defer file.Close()

	var devices []Device
	var currentDevice Device
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if strings.HasPrefix(line, "N: Name=") {
			currentDevice.Name = strings.Trim(line[len("N: Name="):], `"`)
		} else if strings.HasPrefix(line, "U: Uniq=") {
			currentDevice.Uniq = strings.TrimSpace(line[len("U: Uniq="):])
		} else if strings.HasPrefix(line, "H: Handlers=") {
			currentDevice.Handlers = strings.Fields(line[len("H: Handlers="):])
		} else if line == "" && currentDevice.Name != "" {
			for _, handler := range currentDevice.Handlers {
				if strings.HasPrefix(handler, "js") {
					for _, name := range specificNames {
						if currentDevice.Name == name {
							devices = append(devices, currentDevice)
							break
						}
					}
				}
			}
			currentDevice = Device{}
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scanner error: %v", err)
	}
	return devices, nil
}

func inputChecker(devPath string, uniq string, deviceEvent chan struct{}, quit chan bool) {
	fmt.Printf("Checking input on device: %s (%s)\n", uniq, devPath)

	file, err := os.Open(devPath)
	if err != nil {
		fmt.Printf("Failed to open device %s: %v\n", uniq, err)
		return
	}
	defer file.Close()

	buffer := make([]byte, eventSize)

	for {
		select {
		case <-quit:
			fmt.Printf("Stopping input check for device %s\n", uniq)
			return
		default:
			// Read the input event (non-blocking read)
			n, err := file.Read(buffer)
			if err != nil {
				// Handle EOF or other errors
				fmt.Printf("Error reading event from device %s: %v\n", uniq, err)
				return
			}

			if n > 0 {
				// Signal input detected by setting the event
				deviceEvent <- struct{}{}
                // Commenting out to de-clutter logs
				// fmt.Printf("Input detected for device %s\n", uniq)
			}
		}
	}
}

func monitorDevice(devPath string, uniq string, maxIdle time.Duration, wg *sync.WaitGroup, quit chan bool) {
	defer wg.Done()
	fmt.Printf("Monitoring device: %s (%s)\n", uniq, devPath)

	idleSince := time.Now()
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	deviceEvent := make(chan struct{})
	go inputChecker(devPath, uniq, deviceEvent, quit)

	for {
		select {
		case <-quit:
			fmt.Printf("Stopping monitoring for device %s\n", uniq)
			return
		case <-deviceEvent:
			// Reset idle timer when input is detected
			idleSince = time.Now()
            // Commenting out to de-clutter logs
			// fmt.Printf("Resetting idle timer for device %s\n", uniq)
		case <-ticker.C:
			// Check if the device has been idle for too long
			idleDuration := time.Since(idleSince)
			if idleDuration >= maxIdle {
				fmt.Printf("Device %s idle for %v, disconnecting...\n", uniq, idleDuration)
				disconnectDevice(uniq)
				return
			}
		}
	}
}

func disconnectDevice(uniq string) {
	cmd := exec.Command("bluetoothctl", "disconnect", uniq)
	err := cmd.Run()
	if err != nil {
		fmt.Printf("Failed to disconnect %s: %v\n", uniq, err)
	} else {
		fmt.Printf("Disconnected device %s\n", uniq)
	}
}

func main() {
	maxIdle := flag.Int("maxidletime", 3600, "Maximum idle time in seconds (1-10800)")
	maxIdleShort := flag.Int("m", 3600, "Maximum idle time in seconds (shorthand) (1-10800)")
    filePath := flag.String("devicefile", ".jstimeout.devices", "Path to the file containing device names")

	flag.Parse()

	// Validate max idle time
	idleValue := *maxIdle
	if *maxIdleShort != 3600 {
		idleValue = *maxIdleShort
	}
	if idleValue < 1 || idleValue > 10800 {
		fmt.Println("Error: max idle time must be between 1 and 10,800 seconds (3 hours)")
		os.Exit(1)
	}

    // Load device names from file
	if err := loadSpecificNames(*filePath); err != nil {
		fmt.Printf("Error loading device names: %v\n", err)
		return
	}

	// Print the device names on startup
	fmt.Println("Loaded device names:")
	for _, name := range specificNames {
		fmt.Println(" -", name)
	}

	idleDuration := time.Duration(idleValue) * time.Second
	fmt.Printf("Max idle time set to: %v seconds\n", idleDuration.Seconds())

	deviceQuitChannels := make(map[string]chan bool)
	var mu sync.Mutex

	for {
		devices, err := parseInputDevices()
		if err != nil {
			fmt.Printf("Error parsing devices: %v\n", err)
			time.Sleep(5 * time.Second)
			continue
		}

		currentDevices := make(map[string]bool)
		mu.Lock()

		// Handle new devices
		for _, device := range devices {
			if _, exists := deviceQuitChannels[device.Uniq]; !exists {
				for _, handler := range device.Handlers {
					if strings.HasPrefix(handler, "js") {
						quit := make(chan bool)
						deviceQuitChannels[device.Uniq] = quit
						var wg sync.WaitGroup
						wg.Add(1)
						go monitorDevice("/dev/input/"+handler, device.Uniq, idleDuration, &wg, quit)
					}
				}
			}
			currentDevices[device.Uniq] = true
		}

		// Handle removed devices
		for uniq, quit := range deviceQuitChannels {
			if _, stillPresent := currentDevices[uniq]; !stillPresent {
				fmt.Printf("Device %s removed, stopping monitoring...\n", uniq)
				close(quit)
				delete(deviceQuitChannels, uniq)
			}
		}

		mu.Unlock()

		time.Sleep(5 * time.Second)
	}
}

