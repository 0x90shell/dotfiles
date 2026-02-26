package main

import (
	"encoding/binary"
	"strings"
	"testing"
)

// makeJsEventBytes builds raw 8-byte js_event from components.
func makeJsEventBytes(time uint32, value int16, evType uint8, number uint8) []byte {
	buf := make([]byte, 8)
	binary.LittleEndian.PutUint32(buf[0:4], time)
	binary.LittleEndian.PutUint16(buf[4:6], uint16(value))
	buf[6] = evType
	buf[7] = number
	return buf
}

func TestParseJsEvent(t *testing.T) {
	tests := []struct {
		name       string
		buf        []byte
		wantErr    bool
		wantTime   uint32
		wantValue  int16
		wantType   uint8
		wantNumber uint8
	}{
		{
			name:       "button press",
			buf:        makeJsEventBytes(1000, 1, jsEventButton, 0),
			wantTime:   1000,
			wantValue:  1,
			wantType:   jsEventButton,
			wantNumber: 0,
		},
		{
			name:       "axis positive",
			buf:        makeJsEventBytes(2000, 16000, jsEventAxis, 1),
			wantTime:   2000,
			wantValue:  16000,
			wantType:   jsEventAxis,
			wantNumber: 1,
		},
		{
			name:       "axis negative",
			buf:        makeJsEventBytes(3000, -500, jsEventAxis, 1),
			wantTime:   3000,
			wantValue:  -500,
			wantType:   jsEventAxis,
			wantNumber: 1,
		},
		{
			name:      "axis max positive",
			buf:       makeJsEventBytes(0, 32767, jsEventAxis, 0),
			wantValue: 32767,
			wantType:  jsEventAxis,
		},
		{
			name:      "axis max negative (int16 min)",
			buf:       makeJsEventBytes(0, -32768, jsEventAxis, 0),
			wantValue: -32768,
			wantType:  jsEventAxis,
		},
		{
			name:       "init button",
			buf:        makeJsEventBytes(0, 0, jsEventInit|jsEventButton, 5),
			wantType:   jsEventInit | jsEventButton,
			wantNumber: 5,
		},
		{
			name:       "init axis with drift value",
			buf:        makeJsEventBytes(0, -517, jsEventInit|jsEventAxis, 1),
			wantValue:  -517,
			wantType:   jsEventInit | jsEventAxis,
			wantNumber: 1,
		},
		{
			name:    "all zeros",
			buf:     make([]byte, 8),
			wantErr: false,
		},
		{
			name:    "wrong size - too short",
			buf:     make([]byte, 4),
			wantErr: true,
		},
		{
			name:    "wrong size - too long",
			buf:     make([]byte, 16),
			wantErr: true,
		},
		{
			name:    "wrong size - empty",
			buf:     []byte{},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ev, err := parseJsEvent(tt.buf)
			if tt.wantErr {
				if err == nil {
					t.Fatal("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if ev.Time != tt.wantTime {
				t.Errorf("Time = %d, want %d", ev.Time, tt.wantTime)
			}
			if ev.Value != tt.wantValue {
				t.Errorf("Value = %d, want %d", ev.Value, tt.wantValue)
			}
			if ev.Type != tt.wantType {
				t.Errorf("Type = 0x%02x, want 0x%02x", ev.Type, tt.wantType)
			}
			if ev.Number != tt.wantNumber {
				t.Errorf("Number = %d, want %d", ev.Number, tt.wantNumber)
			}
		})
	}
}

func TestIsSignificantEvent(t *testing.T) {
	tests := []struct {
		name     string
		ev       JsEvent
		deadzone int16
		want     bool
	}{
		// Button events always count
		{"button press", JsEvent{Type: jsEventButton, Value: 1}, 6000, true},
		{"button release", JsEvent{Type: jsEventButton, Value: 0}, 6000, true},

		// Axis events with default deadzone 6000
		{"axis above deadzone", JsEvent{Type: jsEventAxis, Value: 8000}, 6000, true},
		{"axis below deadzone", JsEvent{Type: jsEventAxis, Value: 500}, 6000, false},
		{"axis at exact deadzone", JsEvent{Type: jsEventAxis, Value: 6000}, 6000, true},
		{"axis just below deadzone", JsEvent{Type: jsEventAxis, Value: 5999}, 6000, false},
		{"axis zero", JsEvent{Type: jsEventAxis, Value: 0}, 6000, false},
		{"axis negative above deadzone", JsEvent{Type: jsEventAxis, Value: -8000}, 6000, true},
		{"axis negative below deadzone", JsEvent{Type: jsEventAxis, Value: -500}, 6000, false},
		{"axis negative at exact deadzone", JsEvent{Type: jsEventAxis, Value: -6000}, 6000, true},
		{"axis max positive", JsEvent{Type: jsEventAxis, Value: 32767}, 6000, true},
		{"axis max negative (int16 min)", JsEvent{Type: jsEventAxis, Value: -32768}, 6000, true},

		// Real DualSense drift values (both controllers)
		{"DualSense drift -517", JsEvent{Type: jsEventAxis, Value: -517}, 6000, false},
		{"DualSense drift -775", JsEvent{Type: jsEventAxis, Value: -775}, 6000, false},
		{"DualSense drift -4129", JsEvent{Type: jsEventAxis, Value: -4129}, 6000, false},
		{"DualSense drift -4387", JsEvent{Type: jsEventAxis, Value: -4387}, 6000, false},

		// Init events always filtered
		{"init button", JsEvent{Type: jsEventInit | jsEventButton, Value: 1}, 6000, false},
		{"init axis large value", JsEvent{Type: jsEventInit | jsEventAxis, Value: 32767}, 6000, false},
		{"init axis drift", JsEvent{Type: jsEventInit | jsEventAxis, Value: -517}, 6000, false},

		// Deadzone = 0 (effectively disabled)
		{"deadzone 0 any axis", JsEvent{Type: jsEventAxis, Value: 1}, 0, true},
		{"deadzone 0 zero value", JsEvent{Type: jsEventAxis, Value: 0}, 0, true},
		{"deadzone 0 init still filtered", JsEvent{Type: jsEventInit | jsEventAxis, Value: 100}, 0, false},

		// Large deadzone
		{"large deadzone below", JsEvent{Type: jsEventAxis, Value: 20000}, 25000, false},
		{"large deadzone at max", JsEvent{Type: jsEventAxis, Value: 32767}, 32767, true},

		// Unknown event types
		{"unknown type 0x03", JsEvent{Type: 0x03, Value: 100}, 4000, false},
		{"type zero", JsEvent{Type: 0x00, Value: 100}, 4000, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isSignificantEvent(tt.ev, tt.deadzone)
			if got != tt.want {
				t.Errorf("isSignificantEvent(%+v, %d) = %v, want %v",
					tt.ev, tt.deadzone, got, tt.want)
			}
		})
	}
}

func TestParseInputDevicesFromReader(t *testing.T) {
	tests := []struct {
		name       string
		names      []string // specificNames to set
		input      string
		wantCount  int
		wantDevice *Device // check first device if non-nil
	}{
		{
			name:  "single DS3",
			names: []string{"Sony PLAYSTATION(R)3 Controller"},
			input: `I: Bus=0005 Vendor=054c Product=0268 Version=0111
N: Name="Sony PLAYSTATION(R)3 Controller"
P: Phys=aa:bb:cc:dd:ee:ff
S: Sysfs=/devices/virtual/misc/uhid/0005:054C:0268.0001/input/input0
U: Uniq=00:1a:2b:3c:4d:5e
H: Handlers=js0 event15
B: PROP=0
B: EV=1b

`,
			wantCount: 1,
			wantDevice: &Device{
				Name:     "Sony PLAYSTATION(R)3 Controller",
				Uniq:     "00:1a:2b:3c:4d:5e",
				Handlers: []string{"js0", "event15"},
			},
		},
		{
			name:  "DualSense matched, motion sensors filtered",
			names: []string{"DualSense Wireless Controller"},
			input: `I: Bus=0005 Vendor=054c Product=0ce6 Version=8100
N: Name="DualSense Wireless Controller"
P: Phys=
S: Sysfs=/devices/virtual/misc/uhid/0005:054C:0CE6.0010/input/input41
U: Uniq=e8:47:3a:e3:77:60
H: Handlers=event29 js3
B: PROP=0
B: EV=20000b

I: Bus=0005 Vendor=054c Product=0ce6 Version=8100
N: Name="DualSense Wireless Controller Motion Sensors"
P: Phys=
S: Sysfs=/devices/virtual/misc/uhid/0005:054C:0CE6.0010/input/input42
U: Uniq=e8:47:3a:e3:77:60
H: Handlers=event30 js4
B: PROP=40
B: EV=19

I: Bus=0005 Vendor=054c Product=0ce6 Version=8100
N: Name="DualSense Wireless Controller Touchpad"
P: Phys=
S: Sysfs=/devices/virtual/misc/uhid/0005:054C:0CE6.0010/input/input43
U: Uniq=e8:47:3a:e3:77:60
H: Handlers=event31 mouse7
B: PROP=5
B: EV=b

`,
			wantCount: 1,
			wantDevice: &Device{
				Name:     "DualSense Wireless Controller",
				Uniq:     "e8:47:3a:e3:77:60",
				Handlers: []string{"event29", "js3"},
			},
		},
		{
			name:  "multiple controllers",
			names: []string{"DualSense Wireless Controller", "Wireless Controller"},
			input: `I: Bus=0005 Vendor=054c Product=0ce6 Version=8100
N: Name="DualSense Wireless Controller"
P: Phys=
S: Sysfs=/devices/virtual/misc/uhid/input41
U: Uniq=e8:47:3a:e3:77:60
H: Handlers=event29 js3
B: PROP=0

I: Bus=0005 Vendor=054c Product=0ce6 Version=8100
N: Name="Wireless Controller"
P: Phys=
S: Sysfs=/devices/virtual/misc/uhid/input50
U: Uniq=d0:bc:c1:36:c8:b4
H: Handlers=event26 js1
B: PROP=0

I: Bus=0003 Vendor=046d Product=404d Version=0111
N: Name="Logitech K400 Plus"
P: Phys=usb-0000:10:00.0-5/input2:1
S: Sysfs=/devices/pci0000:00/input/input32
U: Uniq=29-eb-96-25
H: Handlers=sysrq kbd leds event8 mouse1
B: PROP=0

`,
			wantCount: 2,
		},
		{
			name:  "no js handler filtered out",
			names: []string{"DualSense Wireless Controller Touchpad"},
			input: `I: Bus=0005 Vendor=054c Product=0ce6 Version=8100
N: Name="DualSense Wireless Controller Touchpad"
P: Phys=
S: Sysfs=/devices/virtual/misc/uhid/input43
U: Uniq=e8:47:3a:e3:77:60
H: Handlers=event31 mouse7
B: PROP=5

`,
			wantCount: 0,
		},
		{
			name:  "unrecognized name filtered out",
			names: []string{"Sony PLAYSTATION(R)3 Controller"},
			input: `I: Bus=0005 Vendor=054c Product=0ce6 Version=8100
N: Name="Some Unknown Controller"
P: Phys=
S: Sysfs=/devices/virtual/input
U: Uniq=aa:bb:cc:dd:ee:ff
H: Handlers=js0 event0
B: PROP=0

`,
			wantCount: 0,
		},
		{
			name:      "empty input",
			names:     []string{"Sony PLAYSTATION(R)3 Controller"},
			input:     "",
			wantCount: 0,
		},
		{
			name:  "empty uniq field",
			names: []string{"Microsoft X-Box 360 pad 0"},
			input: `I: Bus=0003 Vendor=28de Product=11ff Version=0001
N: Name="Microsoft X-Box 360 pad 0"
P: Phys=
S: Sysfs=/devices/virtual/input/input77
U: Uniq=
H: Handlers=event256 js5
B: PROP=0

`,
			wantCount: 1,
			wantDevice: &Device{
				Name:     "Microsoft X-Box 360 pad 0",
				Uniq:     "",
				Handlers: []string{"event256", "js5"},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Save and restore global specificNames
			origNames := specificNames
			specificNames = tt.names
			defer func() { specificNames = origNames }()

			devices, err := parseInputDevicesFromReader(strings.NewReader(tt.input))
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if len(devices) != tt.wantCount {
				t.Fatalf("got %d devices, want %d", len(devices), tt.wantCount)
			}
			if tt.wantDevice != nil && tt.wantCount > 0 {
				d := devices[0]
				if d.Name != tt.wantDevice.Name {
					t.Errorf("Name = %q, want %q", d.Name, tt.wantDevice.Name)
				}
				if d.Uniq != tt.wantDevice.Uniq {
					t.Errorf("Uniq = %q, want %q", d.Uniq, tt.wantDevice.Uniq)
				}
				if len(d.Handlers) != len(tt.wantDevice.Handlers) {
					t.Errorf("Handlers = %v, want %v", d.Handlers, tt.wantDevice.Handlers)
				} else {
					for i, h := range d.Handlers {
						if h != tt.wantDevice.Handlers[i] {
							t.Errorf("Handlers[%d] = %q, want %q", i, h, tt.wantDevice.Handlers[i])
						}
					}
				}
			}
		})
	}
}
