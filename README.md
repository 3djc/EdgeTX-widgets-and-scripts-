# EdgeTX Widgets and Scripts

A collection of Lua widgets for EdgeTX-based radios.

---

## Widgets

### SwitchInfo

A widget that lets you annotate each physical switch on your radio with a custom label, so you always know what role each switch plays in your current model.

**Supported radios:** RadioMaster TX15 series, TX16 series.

#### Features

- Displays all switches in a grid layout, grouped by rows matching the radio's physical layout.
- Each switch box shows the switch name and your custom label.
- Empty switches are visually distinct from labelled ones (inverted colours).
- Labels are saved per model — switching models loads the correct set of labels automatically.
- **Fullscreen / edit mode:** tap any switch box to enter a label directly on the radio.

#### Switch layout

| Radio | Rows                                                                    |
|-------|-------------------------------------------------------------------------|
| TX15  | SE S1 S2 SF / SA SB SC SD / SW1 SW2 SW3 / SW4 SW5 SW6                  |
| TX16  | SE SF SH SG / SA SB SC SD / LS S1 S2 RS / SW1 SW2 SW3 / SW4 SW5 SW6   |

#### Installation

1. Copy the `Widgets/SwitchInfo/` folder to the `WIDGETS/` directory on your radio's SD card.
2. On the radio, add the **Switch Info** widget to a fullscreen zone.

3. Open the widget in fullscreen to enter your switch labels.

#### Usage
1. long touch on widget to enter edit mode
2. tap any switch box to edit its label
3. use the keyboard to enter a label (max 10 characters)
4. press the back button to save the label and return to the main view

#### Data storage

Labels are saved automatically to `/MODELS/<modelname>.switches` on the SD card whenever a label is edited.
