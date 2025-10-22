# 📊 Board Assignment System - Visual Architecture

## 🔄 Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ESP32 BOARD LIFECYCLE                            │
└─────────────────────────────────────────────────────────────────────────┘

Step 1: FACTORY/SETUP
┌──────────────────┐
│  ESP32 Device    │
│  ┌────────────┐  │
│  │ BOARD_ID:  │  │  ← Hardcoded in firmware
│  │ BOARD_001  │  │
│  └────────────┘  │
└────────┬─────────┘
         │
         │ Flash firmware
         │
         ▼

Step 2: FIRST BOOT
┌──────────────────┐
│  WiFi Config     │
│  Portal Mode     │  ← User connects and configures
│  SSID:           │
│  SmartSwitch_001 │
└────────┬─────────┘
         │
         │ User enters:
         │ - WiFi credentials
         │ - Supabase URL
         │ - Supabase key
         │
         ▼

Step 3: REGISTRATION
┌─────────────────────────────────────┐
│   ESP32 Connects to Supabase        │
│                                     │
│   POST /boards                      │
│   {                                 │
│     "id": "BOARD_001",              │
│     "owner_id": NULL,          ← NULL (unassigned)
│     "status": "online",             │
│     "mac_address": "AA:BB:CC...",   │
│     "firmware_version": "2.0.0",    │
│     "last_online": "2025-10-10..."  │
│   }                                 │
└────────┬────────────────────────────┘
         │
         │ Board is now REGISTERED but UNASSIGNED
         │
         ▼
┌─────────────────────────────────────┐
│      Supabase Database              │
│  ┌───────────────────────────────┐  │
│  │ boards table:                 │  │
│  │ id: "BOARD_001"               │  │
│  │ owner_id: NULL                │  │ ← Available for claiming
│  │ status: "online"              │  │
│  │ last_online: 2025-10-10 10:00 │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
         │
         │ Heartbeat every 30 seconds
         │ Updates last_online
         │
         ▼

Step 4: USER CLAIMS BOARD
┌─────────────────────────────────────┐
│     User Opens Flutter App          │
│                                     │
│  Home → Boards → [Add Manual]       │
└────────┬────────────────────────────┘
         │
         │ User enters: BOARD_001
         │
         ▼
┌─────────────────────────────────────┐
│   Click "Check Availability"        │
│                                     │
│   App calls:                        │
│   checkBoardAvailability("BOARD_001")│
└────────┬────────────────────────────┘
         │
         │ Query database
         │
         ▼
┌─────────────────────────────────────┐
│   Validation Checks:                │
│   ✓ Does board exist?               │
│   ✓ Is owner_id NULL?               │
│   ✓ Is status "online"?             │
│   ✓ Is last_online < 5 min?         │
└────────┬────────────────────────────┘
         │
         │ All checks pass
         │
         ▼
┌─────────────────────────────────────┐
│   Display to User:                  │
│  ┌───────────────────────────────┐  │
│  │ ✅ Board is available!        │  │
│  │ MAC: AA:BB:CC:DD:EE:FF        │  │
│  │ Last Online: Just now         │  │
│  │                               │  │
│  │ [Board Name: ________]        │  │
│  │ [Add Board]                   │  │
│  └───────────────────────────────┘  │
└────────┬────────────────────────────┘
         │
         │ User clicks "Add Board"
         │
         ▼
┌─────────────────────────────────────┐
│   validateAndClaimBoard()           │
│                                     │
│   UPDATE boards                     │
│   SET owner_id = 'user-uuid-123',   │
│       home_id = 'home-uuid-456'     │
│   WHERE id = 'BOARD_001'            │
│   AND owner_id IS NULL  ← Atomic    │
└────────┬────────────────────────────┘
         │
         │ Success!
         │
         ▼
┌─────────────────────────────────────┐
│      Board Now Owned by User        │
│  ┌───────────────────────────────┐  │
│  │ boards table:                 │  │
│  │ id: "BOARD_001"               │  │
│  │ owner_id: "user-uuid-123"     │  │ ← NOW ASSIGNED
│  │ home_id: "home-uuid-456"      │  │
│  │ status: "online"              │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
         │
         │ Board appears in user's list
         │
         ▼

Step 5: ONGOING OPERATION
┌─────────────────────────────────────┐
│   User Controls Board               │
│   - Toggle switches                 │
│   - Set timers                      │
│   - Monitor status                  │
│                                     │
│   ESP32 Syncs State                 │
│   - Every 2 seconds                 │
│   - Physical buttons work           │
│   - Real-time updates               │
└─────────────────────────────────────┘
```

---

## 🔀 Concurrent Claim Prevention

```
Two users try to claim BOARD_001 at the SAME time:

Time: T0
┌──────────────────┐              ┌──────────────────┐
│   User A         │              │   User B         │
│  "Add BOARD_001" │              │  "Add BOARD_001" │
└────────┬─────────┘              └────────┬─────────┘
         │                                 │
         │ validateAndClaimBoard()         │ validateAndClaimBoard()
         │                                 │
         ▼                                 ▼
Time: T1
┌───────────────────────────────────────────────────────┐
│           PostgreSQL Database                         │
│                                                       │
│  claim_board() function with ROW-LEVEL LOCK:         │
│                                                       │
│  SELECT * FROM boards                                 │
│  WHERE id = 'BOARD_001'                              │
│  FOR UPDATE;  ← Locks the row                        │
└───────────────────────────────────────────────────────┘
         │                                 │
         │                                 │
Time: T2  │                                 │
    ┌────▼─────────┐                  ┌────┴────────────┐
    │ User A:      │                  │ User B:         │
    │ Row LOCKED   │                  │ WAITING...      │
    │ Checking...  │                  │ (blocked)       │
    └────┬─────────┘                  └─────────────────┘
         │
         │ owner_id IS NULL ✓
         │
Time: T3  │
    ┌────▼─────────────┐
    │ UPDATE boards    │
    │ SET owner_id =   │
    │ 'user-A-uuid'    │
    │ WHERE id =       │
    │ 'BOARD_001'      │
    │ COMMIT;          │ ← Lock released
    └────┬─────────────┘
         │
         │
Time: T4  │                                 │
         │                          ┌───────▼──────────┐
         │                          │ User B:          │
         │                          │ Lock acquired!   │
         │                          │ Checking...      │
         │                          │                  │
         │                          │ owner_id = NOT NULL ✗
         │                          │                  │
         │                          │ ROLLBACK;        │
         │                          │ Throw Error:     │
         │                          │ "Already assigned"│
         │                          └──────────────────┘
         │
         ▼
┌────────────────────┐           ┌──────────────────────┐
│ User A:            │           │ User B:              │
│ ✅ Success!        │           │ ❌ Error:            │
│ Board claimed      │           │ "Board already       │
│                    │           │  assigned to         │
│                    │           │  another user"       │
└────────────────────┘           └──────────────────────┘

Result: ONLY User A gets the board. User B gets clear error.
```

---

## 🚦 Status Flow Diagram

```
┌───────────────────────────────────────────────────────────┐
│              Board Status Transitions                     │
└───────────────────────────────────────────────────────────┘

         FACTORY
           │
           │ Flash firmware
           │
           ▼
      [NEVER BOOTED]
           │
           │ Power on
           │
           ▼
     [CONFIG MODE] ───── If no WiFi config
           │
           │ WiFi configured
           │
           ▼
      [CONNECTING]
           │
           │ WiFi connected
           │
           ▼
     [REGISTERING]
           │
           │ POST to Supabase
           │
           ▼
  [ONLINE, UNASSIGNED] ← owner_id = NULL
           │
           │ User claims via app
           │
           ▼
   [ONLINE, ASSIGNED] ← owner_id = user_id
           │
           ├──────────┬──────────┬──────────┐
           │          │          │          │
           ▼          ▼          ▼          ▼
     [CONTROLLING] [TIMERS]  [OFFLINE]  [MAINTENANCE]
                               (no heartbeat)
                                   │
                                   │ Comes back online
                                   │
                                   ▼
                           [ONLINE, ASSIGNED]
```

---

## 🎭 User Interface States

```
┌─────────────────────────────────────────────────────────────┐
│              "Add Manual Board" Dialog States               │
└─────────────────────────────────────────────────────────────┘

STATE 1: INITIAL
┌─────────────────────────────────────┐
│ Add Board Manually                  │
│─────────────────────────────────────│
│ Enter the Board ID:                 │
│ [BOARD_______]                      │
│                                     │
│ [Check Availability]                │
│                                     │
│                    [Cancel] [    ]  │
└─────────────────────────────────────┘
        │
        │ User types BOARD_001
        │
        ▼

STATE 2: CHECKING
┌─────────────────────────────────────┐
│ Add Board Manually                  │
│─────────────────────────────────────│
│ Enter the Board ID:                 │
│ [BOARD_001]                         │
│                                     │
│ [⏳ Checking...]                    │
│                                     │
│                    [Cancel] [    ]  │
└─────────────────────────────────────┘
        │
        │ Database query
        │
        ▼

STATE 3A: AVAILABLE ✅
┌─────────────────────────────────────┐
│ Add Board Manually                  │
│─────────────────────────────────────│
│ Enter the Board ID:                 │
│ [BOARD_001]                         │
│                                     │
│ [Check Availability]                │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ ✅ Board is available and       │ │
│ │    online!                      │ │
│ │ MAC: AA:BB:CC:DD:EE:FF          │ │
│ │ Last Online: Just now           │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Board Name (Optional):              │
│ [Smart Switch BOARD_001]            │
│                                     │
│            [Cancel] [Add Board] ← Enabled
└─────────────────────────────────────┘

STATE 3B: ALREADY ASSIGNED ⚠️
┌─────────────────────────────────────┐
│ Add Board Manually                  │
│─────────────────────────────────────│
│ Enter the Board ID:                 │
│ [BOARD_001]                         │
│                                     │
│ [Check Availability]                │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ ⚠️ Board already assigned to    │ │
│ │    another user                 │ │
│ │ MAC: AA:BB:CC:DD:EE:FF          │ │
│ └─────────────────────────────────┘ │
│                                     │
│                    [Cancel] [    ]  │
└─────────────────────────────────────┘

STATE 3C: OFFLINE ❌
┌─────────────────────────────────────┐
│ Add Board Manually                  │
│─────────────────────────────────────│
│ Enter the Board ID:                 │
│ [BOARD_001]                         │
│                                     │
│ [Check Availability]                │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ ❌ Board is offline             │ │
│ │    Check power and WiFi         │ │
│ │ MAC: AA:BB:CC:DD:EE:FF          │ │
│ │ Last Online: 7m ago             │ │
│ └─────────────────────────────────┘ │
│                                     │
│                    [Cancel] [    ]  │
└─────────────────────────────────────┘

STATE 4: CLAIMING
┌─────────────────────────────────────┐
│ Claiming board...                   │
│                                     │
│        ⏳                           │
│                                     │
└─────────────────────────────────────┘
        │
        │ Database update
        │
        ▼

STATE 5: SUCCESS
┌─────────────────────────────────────┐
│ ✅ Board "Smart Switch BOARD_001"   │
│    successfully added! 🎉           │
└─────────────────────────────────────┘
```

---

## 🗄️ Database Schema Visualization

```
┌──────────────────────────────────────────────────────────────────┐
│                         BOARDS TABLE                             │
├──────────────────────────────────────────────────────────────────┤
│ id              TEXT PRIMARY KEY     ← "BOARD_001" (hardcoded)   │
│ owner_id        UUID NULL            ← NULL until claimed        │
│ home_id         UUID NULL            ← NULL until claimed        │
│ room_id         UUID NULL            ← NULL until assigned       │
│ name            TEXT NOT NULL        ← "Smart Switch BOARD_001"  │
│ status          TEXT                 ← 'online', 'offline'       │
│ mac_address     TEXT                 ← WiFi MAC address          │
│ firmware_ver    TEXT                 ← "2.0.0"                   │
│ last_online     TIMESTAMP            ← Updated every 30s         │
│ is_active       BOOLEAN              ← TRUE (soft delete)        │
│ created_at      TIMESTAMP            ← Registration time         │
│ updated_at      TIMESTAMP            ← Last modification         │
└──────────────────────────────────────────────────────────────────┘
         │
         │ One-to-Many
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│                        SWITCHES TABLE                            │
├──────────────────────────────────────────────────────────────────┤
│ id              TEXT PRIMARY KEY     ← "BOARD_001_switch_1"      │
│ board_id        TEXT FK              ← "BOARD_001"               │
│ name            TEXT                 ← "Switch 1"                │
│ type            TEXT                 ← 'light', 'fan', etc.      │
│ position        INTEGER              ← 0, 1, 2, 3 (relay pin)    │
│ state           BOOLEAN              ← ON/OFF                    │
│ is_enabled      BOOLEAN              ← Can be controlled?        │
│ last_change     TIMESTAMP            ← Last state change         │
└──────────────────────────────────────────────────────────────────┘
         │
         │ One-to-Many
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│                         TIMERS TABLE                             │
├──────────────────────────────────────────────────────────────────┤
│ id              UUID PRIMARY KEY     ← Auto-generated            │
│ switch_id       TEXT FK              ← "BOARD_001_switch_1"      │
│ user_id         UUID FK              ← Who created timer         │
│ name            TEXT                 ← "Morning Light"           │
│ type            timer_type           ← scheduled, countdown      │
│ time            TEXT                 ← "07:00"                   │
│ action          BOOLEAN              ← ON or OFF                 │
│ is_enabled      BOOLEAN              ← Active?                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                      DEVICE_LOGS TABLE                           │
├──────────────────────────────────────────────────────────────────┤
│ id              UUID PRIMARY KEY                                 │
│ switch_id       TEXT FK              ← Which switch              │
│ user_id         UUID FK              ← Who did it                │
│ action          TEXT                 ← 'turned_on', 'board_claimed'│
│ triggered_by    TEXT                 ← 'manual', 'app', 'timer'  │
│ created_at      TIMESTAMP            ← When                      │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                      SECURITY ARCHITECTURE                       │
└─────────────────────────────────────────────────────────────────┘

Layer 1: HARDWARE SECURITY
┌──────────────────────────────────┐
│ ESP32 Firmware                   │
│ - Hardcoded Board ID             │
│ - Can't be changed remotely      │
│ - Unique per device              │
└──────────────────────────────────┘

Layer 2: DATABASE CONSTRAINTS
┌──────────────────────────────────┐
│ PostgreSQL                       │
│ - Primary key on board ID        │
│ - Foreign key integrity          │
│ - Check constraints              │
│ - Unique constraints             │
└──────────────────────────────────┘

Layer 3: ROW LEVEL SECURITY (RLS)
┌──────────────────────────────────┐
│ Supabase RLS Policies            │
│ - Users see only their boards    │
│ - ESP32 can register boards      │
│ - Users update only owned boards │
└──────────────────────────────────┘

Layer 4: ATOMIC OPERATIONS
┌──────────────────────────────────┐
│ Database Functions               │
│ - claim_board() with FOR UPDATE  │
│ - Prevents race conditions       │
│ - Atomic state transitions       │
└──────────────────────────────────┘

Layer 5: APPLICATION LOGIC
┌──────────────────────────────────┐
│ Flutter Service Layer            │
│ - Validates before claiming      │
│ - Checks online status           │
│ - Verifies ownership             │
└──────────────────────────────────┘

Layer 6: USER AUTHENTICATION
┌──────────────────────────────────┐
│ Supabase Auth                    │
│ - JWT tokens                     │
│ - User ID in claims              │
│ - Session management             │
└──────────────────────────────────┘
```

---

## 📱 App Navigation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     APP SCREEN FLOW                              │
└─────────────────────────────────────────────────────────────────┘

[Login Screen]
     │
     │ Sign in with Supabase Auth
     │
     ▼
[Home Selection Screen]
     │
     │ Select/Create home
     │
     ▼
[Home Screen]
     │
     ├── [Rooms] ───► [Room Details] ───► [Boards in Room]
     │                                           │
     ├── [Boards] ◄──────────────────────────────┘
     │      │
     │      ├── [Add Manual] ───► [Manual Board Dialog]
     │      │                            │
     │      │                            │ Check Availability
     │      │                            │ Claim Board
     │      │                            │
     │      │                            ▼
     │      │                     [Board Added!]
     │      │                            │
     │      │ ◄──────────────────────────┘
     │      │
     │      ├── [Scan WiFi] ───► [WiFi Config Portal]
     │      │
     │      └── [Board Card] ───► [Switch Control Screen]
     │                                    │
     ├── [Timers]                         ├── Switch 1 [ON/OFF]
     │                                    ├── Switch 2 [ON/OFF]
     ├── [Activity]                       ├── Switch 3 [ON/OFF]
     │                                    ├── Switch 4 [ON/OFF]
     └── [Settings]                       │
                                          └── [Add Timer]
```

---

**Visual documentation complete! 📊**

These diagrams illustrate the complete architecture and flow of the manual board assignment system.
