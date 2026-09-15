# Changelog

## 1.8.1-alpha - 2026-09-14

### Added

- Dedicated categorized HeliosBags bank window
- Automatic display of the main bank and all purchased bank bags
- Empty-slot summary now accepts cursor items and dragged stacks

### Changed

- Physical item stacks remain separately visible after splitting
- The inventory and bank use matching layouts while remaining separate windows

### Fixed

- The vanilla bank window no longer appears over the HeliosBags bank
- Bank contents no longer require clicking individual bank-bag buttons
- Split stacks now appear immediately after being placed into an empty slot

## 1.8.0-alpha - 2026-09-14

### Added

- Combined categorized view for the main bank and purchased bank bags
- Contextual Bags and Bank controls while interacting with a banker
- Automatic bag opening when a trade starts

### Fixed

- Purchased bank bags no longer remain as detached container windows
- Trade-opened bags close automatically when the trade ends
- Right-clicking an item places it in the first available trade slot
- Right-clicking an item on the Send Mail screen now adds it as an attachment
- Shift-left-clicking a stack now opens the native split selector

## 1.7.4-alpha - 2026-09-14

### Fixed

- Purchased bank-bag buttons now open their original bank-container windows
- Bank containers no longer toggle or replace the HeliosBags inventory window

## 1.7.3-alpha - 2026-09-14

### Fixed

- Right-clicking an item now transfers it while a bank or trade window is open
- Normal right-click item use remains protected outside bank and trade windows
- Pressing Escape now closes the HeliosBags window

## 1.7.2-alpha - 2026-09-14

### Fixed

- Holding Shift over gear now shows the equipped-item comparison and stat changes

## 1.7.1-alpha - 2026-09-13

### Fixed

- Empty bags caused by the search placeholder being treated as an active filter
- Items now remain visible when the search box loses focus
- Removed the unnecessary Bags button from the inventory header

## 1.7.0-alpha - 2026-09-13

### Added

- Quest-start and quest-item markers on bag icons
- Configurable Recent-item duration

### Changed

- Recent loot now returns to its normal category automatically after a short timer
- Separate acquisitions of the same item expire independently
- Bag hotkeys and bag buttons can open and close HeliosBags while a vendor is open

### Fixed

- Search now filters live by item name, item details, and category name
- Enter and Escape now finish or clear a bag search correctly

### Removed

- Equipment upgrade detection, highlights, comparison text, and settings

## 1.6.0-alpha - 2026-09-10

### Added

- Dark UI appearance mode for the 5.4.8 client
- Optional neutral solid background
- Adjustable background opacity
- Saved appearance settings

### Changed

- Removed the extra template background behind item icons
- Replaced the doubled item frame with a slightly larger, thicker border
- Quality colors and upgrade highlights now use the cleaner border treatment

## 1.5.0-alpha - 2026-09-09

### Added

- Collapsible category headers for every built-in and custom section
- Saved expanded and collapsed states between sessions
- Drag-and-drop item support for action bars, inventory movement, and deletion
- Search behavior that temporarily expands matching sections

### Changed

- Category headers are now interactive controls with clear state arrows
- Inventory totals remain accurate when sections are collapsed
- Restored the MIT license to match the public project

## 1.4.3-alpha - 2026-09-03

### Changed

- Simplified inventory handling and removed obsolete bank-related paths
- Made module initialization deterministic
- Removed dead fields and consolidated repeated junk-selling checks
- Cleaned project metadata and documentation

## 1.4.2-alpha - 2026-09-02

### Added

- Secure right-click use for targeted consumables
- Quantity-aware Recent item tracking

### Fixed

- Existing stack quantities no longer move into Recent when more are acquired

## 1.4.1-alpha - 2026-09-02

### Added

- Class-aware equipment upgrade detection
- Shift-hover stat comparisons
- Visible upgrade highlighting
