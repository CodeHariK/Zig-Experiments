package device

const (
	ButtonA = iota
	ButtonB
	ButtonSelect
	ButtonStart
	ButtonUp
	ButtonDown
	ButtonLeft
	ButtonRight
)

// Controller represents a standard NES gamepad. The CPU reads the buttons
// sequentially one bit at a time after sending a "strobe" signal.
type Controller struct {
	buttons [8]bool // The current physical state of the 8 buttons
	index   byte    // Which button the CPU is currently reading (0-7)
	strobe  byte    // When high (1), the shift register repeatedly loads physical button state
}

func NewController() *Controller {
	return &Controller{}
}

// SetButtons maps an external input source (like a keyboard array of booleans)
// into the physical button state ready to be loaded by the game.
func (c *Controller) SetButtons(buttons [8]bool) {
	c.buttons = buttons
}

// Read is called by the CPU at memory addresses $4016 or $4017.
// It returns a single bit (0 or 1) representing the state of the current button.
func (c *Controller) Read() byte {
	value := byte(0)
	if c.index < 8 && c.buttons[c.index] {
		value = 1
	}

	c.index++

	// If the strobe is high, it continually resets the index to 0 (ButtonA)
	if c.strobe&1 == 1 {
		c.index = 0
	}
	
	return value
}

// Write is called by the CPU to set the strobe state.
// Writing 1 to it tells the controller to snapshot the buttons.
// Writing 0 to it tells the controller to stop locking the index, allowing consecutive Reads.
func (c *Controller) Write(value byte) {
	c.strobe = value
	if c.strobe&1 == 1 {
		c.index = 0
	}
}
