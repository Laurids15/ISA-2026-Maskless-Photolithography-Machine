/*
 * ballast_emu.cpp
 * Emulator for an OSRAM P-VIP lamp ballast (standardized 5-pin interface)
 * for converting a DLP projector to an LED/UV-LED light source
 * (InFocus IN124 and similar). Also emulates removed fans and the
 * colour-wheel index sensor.
 *
 * Board     : ESP32 DevKit (ESP32-WROOM-32), Arduino-ESP32 core 3.x
 * Projector : 3.3 V logic. Direct connection - no optocouplers.
 * Power     : projector 3.3 V rail -> ESP32 3V3 pin (or 5 V -> 5V/VIN).
 *
 * Seen from the projector, the emulator behaves like the ballast:
 *  - "Flag" mode (after power-up): the Flag output reports "lamp on" once
 *    the projector has activated SCI and the emulated ignition is done.
 *  - UART mode (when the projector sends 0x70): answers commands and
 *    queries per the "Standardized UART Protocol" v3.3, 9600 8E1.
 *    Hardware UART1 is used; the Flag pin is switched between GPIO and
 *    UART TX through the GPIO matrix.
 *
 * ------------------------------------------------------------------
 * WIRING (see the build guide)
 *
 * Projector 5-pin connector (Gen4/5 standard - CHECK the pinout of your ballast!):
 *   Pin 1  Flag/TxD+   Pin 2  Flag/TxD-   Pin 3  Common LED+
 *   Pin 4  SCI/Sync    Pin 5  DIM/RxD
 * Older Gen3 "front" ballasts (connector CN1) are mirrored:
 *   Pin 5  Flag/TxD+   Pin 4  Flag/TxD-   Pin 3  Common LED+
 *   Pin 2  SCI/Sync    Pin 1  DIM/RxD
 *
 * The connector has no GND pin. Connect ESP32 GND to the projector's
 * low-voltage GND (main board, fan or colour-wheel connector) - NEVER to
 * the ballast power connector (380-400 V DC).
 *
 *   J1.3 LED+        : not connected (measure: must be <= 3.3 V)
 *   J1.5 DIM/RxD     -> 330R -> GPIO25,  10k pull-up to 3V3
 *   J1.4 SCI/Sync    -> 330R -> GPIO27,  10k pull-up to 3V3
 *   Flag/TxD         : GPIO26 -> 330R -> J1.2 (TX_INVERT 0) or J1.1 (TX_INVERT 1)
 *
 *   Measure with the ballast disconnected and the projector on (pins 1, 2 to GND):
 *     A) pin 1 = 3.3 V, pin 2 = 0 V via pull-down -> use pin 2, TX_INVERT 0
 *     B) pin 1 = 3.3 V via pull-up, pin 2 = 0 V   -> use pin 1, TX_INVERT 1
 *
 * Fan emulator (one channel per removed fan, up to 3).
 * Each channel is FAN_FIXED, FAN_PWM or FAN_LOW - see FAN_MODE.
 * Current setup: channel 1 FAN_FIXED (fan 1, real tach at 150 Hz).
 * Fans 2 and 3 have a lock/alarm signal on the white wire (0 V = running);
 * it is held low with a 1k resistor to GND, so channels 2 and 3 are unused.
 *   Fan connector pins: red (+12V), black (PWM, low = on), white (tach/alarm)
 *   Tach out   : FAN_OUT -> 4k7 -> BD139 base (pin 3), 10k base -> GND,
 *                emitter (pin 1) -> GND, collector (pin 2) -> white
 *   FAN_PWM only:
 *     Dummy    : 1k 0.5 W between red and black (pulls black up during the
 *                PWM off-time, as the fan coil did)
 *     PWM in   : black -> 10k -> FAN_IN,  3k3 from FAN_IN to GND
 *   Channel 1: FAN_IN GPIO34, FAN_OUT GPIO32
 *   Channel 2: FAN_IN GPIO35, FAN_OUT GPIO33
 *   Channel 3: FAN_IN GPIO4,  FAN_OUT GPIO14
 *
 *   In FAN_PWM mode the ESP32 measures the PWM duty cycle, lets a virtual
 *   fan spin up/down, and pulls tach low only while PWM is on - exactly
 *   like a real fan whose electronics lose power during the PWM off-time.
 *
 * Colour wheel: fake index signal on GPIO18 -> 1k -> index signal pin
 * (sensor removed). At 130 Hz the DLP controller thinks the wheel is
 * overspeeding and cuts motor power, so the motor can be removed.
 *
 * Status : on-board LED on GPIO2 - see led_update() for the patterns.
 * Log    : USB serial 115200 baud.
 * ------------------------------------------------------------------
 */

#include <Arduino.h>
#include "driver/gpio.h"
#include "esp_rom_gpio.h"
#include "soc/gpio_sig_map.h"
#include "soc/gpio_struct.h"

/* ========================== SETTINGS ========================== */

#define PIN_RXD         25    /* J1.5 DIM/RxD  (input)          */
#define PIN_SCI         27    /* J1.4 SCI/Sync (input)          */
#define PIN_FLAG        26    /* Flag / TxD    (output)         */
#define PIN_LED         2     /* on-board LED on most DevKits    */

#define TX_INVERT       0     /* 0 = case A (pin 2), 1 = case B (pin 1) */
#define LED_ACTIVE_HIGH 1

#define SCI_MODE        1     /* 1 = follow SCI from the projector, 0 = lamp always "on" */
#define SCI_TIMEOUT_MS  50    /* SCI active if low or toggled within this many ms */
#define BOOT_DELAY_MS   500   /* only used with SCI_MODE 0 */

#define IGNITION_MS     800
#define RUNUP_MS        1500
#define COOLDOWN_MS     2000

#define FAN_EMU         1     /* 1 = emulate removed fans */
#define FAN_COUNT       3
enum : uint8_t { FAN_FIXED, FAN_PWM, FAN_LOW };
static const uint8_t FAN_MODE[]    = { FAN_FIXED, FAN_LOW, FAN_LOW };
                                   /* FAN_FIXED: fixed frequency, FAN_IN unused
                                      FAN_PWM  : follows the projector PWM on black
                                      FAN_LOW  : white held low ("running"
                                                 alarm signal), FAN_IN unused */
static const uint8_t FAN_IN[]      = { 34, 35, 4 };     /* black wire via 10k/3k3 */
static const uint8_t FAN_OUT[]     = { 32, 33, 14 };    /* BD139 base via 4k7     */
static const float   FAN_FULL_HZ[] = { 150, 150, 150 }; /* fixed Hz / tach at 100 % PWM */
#define FAN_PWM_ON_LEVEL 0    /* black wire low = fan on (low-side PWM) */
#define FAN_MIN_DUTY_PM 150   /* below 15 % PWM the virtual fan stands still */
#define FAN_TAU_S       0.8f  /* how fast the virtual fan spins up/down */
#define FAN_TIMEOUT_US  20000 /* no PWM edges for this long = steady on/off */
#define FAN_LOG_MS      2000  /* print fan status to the log (0 = off) */

/* Colour wheel: fake index signal (fixed frequency, hardware PWM = no jitter)
 * PIN_CW_INDEX -> 1k -> index pin on the projector's colour-wheel connector
 * (index sensor removed). With CW_VIA_TRANSISTOR 1 it goes through a BD139
 * as open collector, like the fans.                                       */
#define CW_EMU            1
#define PIN_CW_INDEX      18
#define CW_HZ             130   /* 130 Hz: projector thinks the wheel is too fast and cuts the motor (motor can be removed). Normal: 120 Hz with a 60 Hz source */
#define CW_PULSE_US       600   /* measured: 600 us */
#define CW_PULSE_LEVEL    1     /* level on the index pin during the pulse: 1 = short high pulse (measured) */
#define CW_VIA_TRANSISTOR 0     /* 1 = BD139 in between (inverts) */

/* Sniff mode: measure the REAL, running fans (disables FAN_EMU).
 * Input per probe: wire -> 10k -> pin, BAT85 from pin to 3V3
 * (cathode to 3V3), 100k from pin to GND.
 * Probe 1 = GPIO34, probe 2 = GPIO35, probe 3 = GPIO4.               */
#define FAN_SNIFF       0     /* 1 = sniff mode */
#define SNIFF_GAP_US    500   /* gap that separates tach pulses from PWM chopping */
#if FAN_SNIFF
#undef  FAN_EMU
#define FAN_EMU         0
#endif

#define HW_ID           0x17  /* O3 MID 230W */
#define SW_ID           0x19  /* kernel GB04 */
#define LAMP_POWER_W    230
#define LAMP_VOLT_V     75
#define UMAX_V          155
#define IMAX_MA         5000
#define TEMP_RAW        0x0100
#define GAIN_MIN        0x50
#define GAIN_MAX        0x93
#define WAVEFORM_COUNT  8
#define WAVEFORM_ID     0x07
#define LABEL           "LED-EMU"

#define LOG_BAUD        115200

/* ========================== DERIVED =========================== */

#define U_RAW  ((uint16_t)((uint32_t)LAMP_VOLT_V * 65535UL / UMAX_V))
#define I_RAW  ((uint16_t)(((uint32_t)LAMP_POWER_W * 1000UL / LAMP_VOLT_V) * 1023UL / IMAX_MA))

static_assert(sizeof(LABEL) <= 16, "LABEL max 15 characters");

enum : uint8_t {
    ST_STANDBY  = 0x00,
    ST_IGNITION = 0x01,
    ST_RUNUP    = 0x04,
    ST_COOLDOWN = 0x05,
    ST_NORMAL   = 0x06
};

#define VMEM_BASE 0x8100
enum : uint8_t {
    OFS_TEMP    = 0x00,
    OFS_U       = 0x02,
    OFS_I       = 0x04,
    OFS_P       = 0x06,
    OFS_OPST    = 0x08,
    OFS_ERR     = 0x0A,
    OFS_PWD     = 0x0C,
    OFS_IMAX    = 0x0E,
    OFS_UMAX    = 0x10,
    OFS_PPR     = 0x12,
    OFS_WF_SRAM = 0x14,
    OFS_WF_EE   = 0x18,
    OFS_LABEL   = 0x1C,
    VMEM_SIZE   = 0x2C
};

/* =========================== STATE ============================ */

static HardwareSerial &Ballast = Serial1;

static uint8_t  vmem[VMEM_SIZE];
static volatile bool sci_edge;
static volatile bool rx_err;

static uint32_t now_ms;
static uint8_t  op_state = ST_STANDBY;
static uint32_t state_t0;
static bool     sci_valid, uart_mode, lamp_cmd;
static uint8_t  gain = 0x80, waveform;
static uint16_t mbox_addr;
static uint8_t  mbox_ctrl;
static uint8_t  error_status;
static uint32_t err_flash_until;

/* =========================== LOG ============================== */

static void log_bytes(char dir, const uint8_t *p, uint8_t n)
{
    Serial.print(dir);
    for (uint8_t i = 0; i < n; i++) Serial.printf(" %02X", p[i]);
    Serial.println();
}

/* ======================== FLAG / TX =========================== */

/* lit = "transistor conducting" (lamp on in flag mode) */
static void flag_level(bool lit)
{
    gpio_set_level((gpio_num_t)PIN_FLAG, (lit ^ TX_INVERT) ? 1 : 0);
}

/* Switch the Flag pin between GPIO (flag mode) and UART1 TX (UART mode) */
static void tx_attach_uart(bool on)
{
    if (on) {
        flag_level(true);                                  /* idle = mark */
        delay(1);
        esp_rom_gpio_connect_out_signal(PIN_FLAG, U1TXD_OUT_IDX, TX_INVERT, false);
    } else {
        Ballast.flush();                                   /* wait until the last byte is sent */
        esp_rom_gpio_connect_out_signal(PIN_FLAG, SIG_GPIO_OUT_IDX, false, false);
    }
}

static void send(const uint8_t *p, uint8_t n)
{
    log_bytes('>', p, n);
    Ballast.write(p, n);
}

static void send1(uint8_t b) { send(&b, 1); }

static void send_err_echo(const uint8_t *c, uint8_t n)
{
    uint8_t r[5];
    r[0] = 0xAA;
    memcpy(r + 1, c, n);
    send(r, n + 1);
    err_flash_until = now_ms + 500;
}

/* ====================== VIRTUAL MEMORY ======================== */

static void vm_put16(uint8_t ofs, uint16_t v)
{
    vmem[ofs]     = (uint8_t)(v & 0xFF);
    vmem[ofs + 1] = (uint8_t)(v >> 8);
}

static bool lamp_lit(void)
{
    return op_state == ST_RUNUP || op_state == ST_NORMAL;
}

static void vmem_init(void)
{
    memset(vmem, 0, sizeof vmem);
    vm_put16(OFS_IMAX, IMAX_MA);
    vm_put16(OFS_UMAX, UMAX_V);
    vm_put16(OFS_PPR, 0x6000);
    vmem[OFS_WF_SRAM] = 2; vmem[OFS_WF_SRAM + 1] = WAVEFORM_ID;
    vmem[OFS_WF_EE]   = 2; vmem[OFS_WF_EE + 1]   = WAVEFORM_ID;
    vmem[OFS_LABEL] = (uint8_t)sizeof(LABEL);
    memcpy(&vmem[OFS_LABEL + 1], LABEL, sizeof(LABEL) - 1);
}

static void vmem_update(void)
{
    bool on = lamp_lit();
    vm_put16(OFS_TEMP, TEMP_RAW);
    vm_put16(OFS_U, on ? U_RAW : 0);
    vm_put16(OFS_I, on ? I_RAW : 0);
    vm_put16(OFS_P, LAMP_POWER_W);
    vm_put16(OFS_OPST, op_state);
    vm_put16(OFS_ERR, error_status);
}

static int8_t item_ofs(uint8_t item)
{
    switch (item) {
    case 0x01: return OFS_TEMP;
    case 0x02: return OFS_U;
    case 0x03: return OFS_I;
    case 0x04: return OFS_P;
    case 0x05: return OFS_OPST;
    case 0x06: return OFS_ERR;
    case 0x08: return OFS_PWD;
    case 0x0C: return OFS_IMAX;
    case 0x0D: return OFS_UMAX;
    case 0x7E: return OFS_PPR;
    case 0x80: return OFS_WF_SRAM;
    case 0x81: return OFS_WF_EE;
    case 0x82: return OFS_LABEL;
    default:   return -1;
    }
}

static uint8_t mem_read(uint16_t a)
{
    if (a >= VMEM_BASE && a < VMEM_BASE + VMEM_SIZE) return vmem[a - VMEM_BASE];
    return 0x00;
}

static bool mem_write(uint16_t a, uint8_t v)
{
    if (!(mbox_ctrl & 0x01)) return false;
    if (a >= VMEM_BASE && a < VMEM_BASE + VMEM_SIZE) vmem[a - VMEM_BASE] = v;
    return true;
}

/* ===================== LAMP STATE MACHINE ===================== */

static void set_state(uint8_t s)
{
    op_state = s;
    state_t0 = now_ms;
    Serial.printf("STATE %02X\n", s);
}

static void lamp_tick(void)
{
    bool want = sci_valid && (!uart_mode || lamp_cmd) && error_status == 0;
    uint32_t dt = now_ms - state_t0;

    switch (op_state) {
    case ST_STANDBY:
        if (want) set_state(ST_IGNITION);
        break;
    case ST_IGNITION:
        if (!want)                  set_state(ST_STANDBY);
        else if (dt >= IGNITION_MS) set_state(ST_RUNUP);
        break;
    case ST_RUNUP:
        if (!want)               set_state(ST_COOLDOWN);
        else if (dt >= RUNUP_MS) set_state(ST_NORMAL);
        break;
    case ST_NORMAL:
        if (!want) set_state(ST_COOLDOWN);
        break;
    case ST_COOLDOWN:
        if (dt >= COOLDOWN_MS) set_state(ST_STANDBY);
        break;
    default:
        set_state(ST_STANDBY);
        break;
    }
}

/* ========================= STATUS LED ========================= */
/*
 *  Short blink every second      : waiting, no SCI from the projector
 *  Short blink twice a second    : SCI ok, waiting for Lamp On (UART mode)
 *  Fast blink (4 Hz)             : ignition / run-up
 *  On, short off every second    : normal operation (two offs = UART mode)
 *  Slow blink (1 Hz, 50 %)       : cool-down
 *  Flicker                       : receive error / rejected command
 */
static void led_update(void)
{
    uint32_t ph = now_ms % 1000;
    bool on;

    if ((int32_t)(err_flash_until - now_ms) > 0) {
        on = (now_ms / 40) & 1;
    } else {
        switch (op_state) {
        case ST_IGNITION:
        case ST_RUNUP:
            on = (now_ms / 125) & 1;
            break;
        case ST_NORMAL:
            on = !(ph < 60 || (uart_mode && ph >= 180 && ph < 240));
            break;
        case ST_COOLDOWN:
            on = ph < 500;
            break;
        default:
            on = sci_valid ? (ph % 500) < 60 : ph < 60;
            break;
        }
    }
    digitalWrite(PIN_LED, (on == LED_ACTIVE_HIGH) ? HIGH : LOW);
}

/* =========================== SCI ============================== */

static void IRAM_ATTR sci_isr(void) { sci_edge = true; }

static void sci_update(void)
{
#if SCI_MODE
    static uint32_t last_active = 0;
    static bool ever = false;
    if (digitalRead(PIN_SCI) == LOW || sci_edge) {   /* projector pulls SCI low = active */
        sci_edge = false;
        last_active = now_ms;
        ever = true;
    }
    bool v = ever && (now_ms - last_active) < SCI_TIMEOUT_MS;
#else
    bool v = now_ms >= BOOT_DELAY_MS;
#endif
    if (v != sci_valid) {
        sci_valid = v;
        Serial.println(v ? "SCI on" : "SCI off");
    }
}

/* ========================= COMMANDS =========================== */

static uint8_t cmd_len(uint8_t k)
{
    switch (k) {
    case 0x25: case 0x26: case 0x3A: case 0x70: case 0x75:
        return 1;
    case 0x71: case 0x72: case 0x73:
        return 2;
    case 0x74:
        return 4;
    case 0xF0: case 0xF1: case 0xF2: case 0xF3: case 0xF4: case 0xF5:
    case 0xF6: case 0xF7: case 0xF9: case 0xFA: case 0xFB:
        return 1;
    case 0xFF:
        return 2;
    default:
        return 0;
    }
}

static void enter_uart_mode(void)
{
    uart_mode = true;
    lamp_cmd  = sci_valid;
    gain      = 0x80;
    tx_attach_uart(true);
    Serial.println("UART on");
}

static void leave_uart_mode(void)
{
    tx_attach_uart(false);
    uart_mode = false;
    flag_level(lamp_lit());
    Serial.println("UART off");
}

static void do_reset(void)
{
    if (uart_mode) leave_uart_mode();
    lamp_cmd     = false;
    gain         = 0x80;
    waveform     = 0;
    mbox_addr    = 0;
    mbox_ctrl    = 0;
    error_status = 0;
    vm_put16(OFS_PWD, 0);
    if (op_state != ST_STANDBY) set_state(ST_STANDBY);
    Serial.println("RESET");
}

static void execute(const uint8_t *c, uint8_t n)
{
    uint8_t r[6];
    uint8_t rn;

    log_bytes('<', c, n);

    switch (c[0]) {
    case 0x25: lamp_cmd = true; break;
    case 0x26: lamp_cmd = false; error_status = 0; break;
    case 0x3A: do_reset(); return;                 /* no echo */
    case 0x70: gain = 0x80; break;
    case 0x75: leave_uart_mode(); return;          /* no echo */
    case 0x71:
        if (c[1] >= WAVEFORM_COUNT) goto err;
        waveform = c[1];
        break;
    case 0x72:
        if (c[1] < GAIN_MIN || c[1] > GAIN_MAX) goto err;
        gain = c[1];
        break;
    case 0x73:
        if (!mem_write(mbox_addr, c[1])) goto err;
        mbox_addr++;
        break;
    case 0x74:
        mbox_addr = ((uint16_t)c[1] << 8) | c[2];
        mbox_ctrl = c[3];
        break;
    default:
        break;
    }

    memcpy(r, c, n);
    rn = n;

    switch (c[0]) {
    case 0xF0: r[rn++] = 0x01; break;
    case 0xF1: r[rn++] = HW_ID; r[rn++] = SW_ID; break;
    case 0xF2: r[rn++] = WAVEFORM_ID; break;
    case 0xF3: r[rn++] = waveform; break;
    case 0xF4: r[rn++] = gain; break;
    case 0xF5: r[rn++] = lamp_lit() ? 0x01 : 0x00; break;
    case 0xF6: r[rn++] = WAVEFORM_COUNT; break;
    case 0xF7:
        r[rn++] = (uint8_t)(mbox_addr >> 8);
        r[rn++] = (uint8_t)(mbox_addr & 0xFF);
        r[rn++] = mbox_ctrl;
        break;
    case 0xF9: r[rn++] = mem_read(mbox_addr++); break;
    case 0xFA: r[rn++] = GAIN_MIN; break;
    case 0xFB: r[rn++] = GAIN_MAX; break;
    case 0xFF: {
        int8_t o = item_ofs(c[1]);
        if (o < 0) goto err;
        mbox_addr = VMEM_BASE + (uint8_t)o;
        r[rn++] = (uint8_t)(mbox_addr >> 8);
        r[rn++] = (uint8_t)(mbox_addr & 0xFF);
        break;
    }
    default:
        break;
    }

    send(r, rn);
    return;

err:
    send_err_echo(c, n);
}

/* ======================== FAN EMULATOR ======================== */

static inline void IRAM_ATTR pin_write(uint8_t pin, bool v)
{
    if (pin < 32) {
        if (v) GPIO.out_w1ts = 1UL << pin;
        else   GPIO.out_w1tc = 1UL << pin;
    } else {
        if (v) GPIO.out1_w1ts.val = 1UL << (pin - 32);
        else   GPIO.out1_w1tc.val = 1UL << (pin - 32);
    }
}

static inline bool IRAM_ATTR pin_read(uint8_t pin)
{
    return pin < 32 ? (GPIO.in >> pin) & 1 : (GPIO.in1.val >> (pin - 32)) & 1;
}


#if FAN_EMU
static_assert(sizeof(FAN_IN) == FAN_COUNT && sizeof(FAN_OUT) == FAN_COUNT &&
              sizeof(FAN_MODE) == FAN_COUNT &&
              sizeof(FAN_FULL_HZ) / sizeof(FAN_FULL_HZ[0]) == FAN_COUNT,
              "FAN_IN/FAN_OUT/FAN_FULL_HZ must have FAN_COUNT elements");

struct FanState {
    volatile uint32_t t_on, t_off, last_edge_us;
    volatile uint16_t duty_pm;      /* per mille of the time PWM is on */
    volatile bool     pwm_on;
    volatile bool     tach_low;
    float             hz;           /* tach frequency of the virtual fan */
    uint32_t          next_us;
};
static FanState fans[FAN_COUNT];
static portMUX_TYPE fan_mux = portMUX_INITIALIZER_UNLOCKED;

/* Tach is pulled low only while PWM is on and the virtual rotor is in "low" */
static inline void IRAM_ATTR fan_apply(uint8_t i)
{
    pin_write(FAN_OUT[i], fans[i].pwm_on && fans[i].tach_low);
}

static void IRAM_ATTR fan_edge(uint8_t i)
{
    uint32_t now = micros();
    bool on = pin_read(FAN_IN[i]) == FAN_PWM_ON_LEVEL;
    FanState &f = fans[i];

    portENTER_CRITICAL_ISR(&fan_mux);
    if (on && !f.pwm_on) {                      /* new period starts */
        uint32_t period = now - f.t_on;
        uint32_t on_t   = f.t_off - f.t_on;
        if (f.t_on && period > 0 && on_t <= period)
            f.duty_pm = (uint16_t)((uint64_t)on_t * 1000 / period);
        f.t_on = now;
    } else if (!on && f.pwm_on) {
        f.t_off = now;
    }
    f.pwm_on = on;
    f.last_edge_us = now;
    fan_apply(i);
    portEXIT_CRITICAL_ISR(&fan_mux);
}

static void IRAM_ATTR fan_isr0(void) { fan_edge(0); }
static void IRAM_ATTR fan_isr1(void) { fan_edge(1); }
static void IRAM_ATTR fan_isr2(void) { fan_edge(2); }
static void (*const fan_isrs[3])(void) = { fan_isr0, fan_isr1, fan_isr2 };
static_assert(FAN_COUNT <= 3, "Add more fan_isrN for more than 3 fans");

static void fan_setup(void)
{
    for (uint8_t i = 0; i < FAN_COUNT; i++) {
        pinMode(FAN_OUT[i], OUTPUT);
        digitalWrite(FAN_OUT[i], LOW);
        fans[i].next_us = micros();
        fans[i].last_edge_us = micros();
        if (FAN_MODE[i] == FAN_LOW) {             /* BD139 always on = white low */
            digitalWrite(FAN_OUT[i], HIGH);
            continue;
        }
        if (FAN_MODE[i] == FAN_FIXED) {           /* always "on", full speed */
            fans[i].pwm_on  = true;
            fans[i].duty_pm = 1000;
            fans[i].hz      = FAN_FULL_HZ[i];
            continue;
        }
        pinMode(FAN_IN[i], INPUT);
        attachInterrupt(digitalPinToInterrupt(FAN_IN[i]), fan_isrs[i], CHANGE);
    }
}

/* Called every ms: duty cycle -> virtual fan speed */
static void fan_tick_ms(void)
{
    const float k = 0.001f / FAN_TAU_S;
    uint32_t now = micros();

    for (uint8_t i = 0; i < FAN_COUNT; i++) {
        FanState &f = fans[i];
        if (FAN_MODE[i] != FAN_PWM) continue;

        portENTER_CRITICAL(&fan_mux);
        if (now - f.last_edge_us > FAN_TIMEOUT_US) {   /* no PWM: steady level */
            bool on = pin_read(FAN_IN[i]) == FAN_PWM_ON_LEVEL;
            f.pwm_on  = on;
            f.duty_pm = on ? 1000 : 0;
            f.last_edge_us = now - FAN_TIMEOUT_US;      /* avoid overflow */
            fan_apply(i);
        }
        uint16_t duty = f.duty_pm;
        portEXIT_CRITICAL(&fan_mux);

        float target = duty < FAN_MIN_DUTY_PM ? 0.0f : FAN_FULL_HZ[i] * duty / 1000.0f;
        f.hz += (target - f.hz) * k;
    }
}

/* Called as often as possible: generates the tach square wave per virtual fan */
static void fan_tach_run(void)
{
    uint32_t now = micros();

    for (uint8_t i = 0; i < FAN_COUNT; i++) {
        FanState &f = fans[i];
        if (FAN_MODE[i] == FAN_LOW) continue;

        if (f.hz < 2.0f) {                             /* rotor stopped */
            if (f.tach_low) {
                portENTER_CRITICAL(&fan_mux);
                f.tach_low = false;
                fan_apply(i);
                portEXIT_CRITICAL(&fan_mux);
            }
            f.next_us = now;
            continue;
        }

        if ((int32_t)(now - f.next_us) >= 0) {
            uint32_t half_us = (uint32_t)(500000.0f / f.hz);
            f.next_us += half_us;
            if ((int32_t)(now - f.next_us) > (int32_t)half_us) f.next_us = now + half_us;
            portENTER_CRITICAL(&fan_mux);
            f.tach_low = !f.tach_low;
            fan_apply(i);
            portEXIT_CRITICAL(&fan_mux);
        }
    }
}

static void fan_log(void)
{
#if FAN_LOG_MS
    static uint32_t last;
    if (now_ms - last < FAN_LOG_MS) return;
    last = now_ms;
    Serial.print("FAN");
    for (uint8_t i = 0; i < FAN_COUNT; i++) {
        if (FAN_MODE[i] == FAN_LOW) { Serial.printf("  %u: held low", i + 1); continue; }
        Serial.printf("  %u: PWM %3u%% tach %3u Hz", i + 1,
                      (unsigned)(fans[i].duty_pm / 10), (unsigned)(fans[i].hz + 0.5f));
    }
    Serial.println();
#endif
}
#endif

/* ========================= SNIFF MODE ========================= */

#if FAN_SNIFF
static const uint8_t SNIFF_IN[3]   = { 34, 35, 4 };
static const char   *SNIFF_NAME[3] = { "probe1", "probe2", "probe3" };

struct Sniff {                    /* only accessed inside sniff_mux */
    uint32_t rises, high_us, low_us, bursts;
    uint32_t last_us;
    uint32_t min_high, max_high, min_low, max_low;
    bool     level;
};
static Sniff sn[3];
static portMUX_TYPE sniff_mux = portMUX_INITIALIZER_UNLOCKED;

static void IRAM_ATTR sniff_edge(uint8_t i)
{
    uint32_t now = micros();
    bool lvl = pin_read(SNIFF_IN[i]);
    Sniff &s = sn[i];
    portENTER_CRITICAL_ISR(&sniff_mux);
    uint32_t dt = now - s.last_us;
    if (dt > SNIFF_GAP_US) s.bursts++;          /* new burst after a gap */
    if (s.level) {                               /* was high until now */
        s.high_us += dt;
        if (dt < s.min_high) s.min_high = dt;
        if (dt > s.max_high) s.max_high = dt;
    } else {
        s.low_us += dt;
        if (dt < s.min_low) s.min_low = dt;
        if (dt > s.max_low) s.max_low = dt;
    }
    if (lvl && !s.level) s.rises++;
    s.level = lvl;
    s.last_us = now;
    portEXIT_CRITICAL_ISR(&sniff_mux);
}

static void IRAM_ATTR sniff_isr0(void) { sniff_edge(0); }
static void IRAM_ATTR sniff_isr1(void) { sniff_edge(1); }
static void IRAM_ATTR sniff_isr2(void) { sniff_edge(2); }

static void sniff_reset(Sniff &s)
{
    s.rises = s.high_us = s.low_us = s.bursts = 0;
    s.min_high = s.min_low = UINT32_MAX;
    s.max_high = s.max_low = 0;
}

static void sniff_setup(void)
{
    void (*isr[3])(void) = { sniff_isr0, sniff_isr1, sniff_isr2 };
    for (uint8_t i = 0; i < 3; i++) {
        pinMode(SNIFF_IN[i], INPUT);
        sniff_reset(sn[i]);
        sn[i].level = digitalRead(SNIFF_IN[i]) == HIGH;
        sn[i].last_us = micros();
        attachInterrupt(digitalPinToInterrupt(SNIFF_IN[i]), isr[i], CHANGE);
    }
    Serial.println("SNIFF MODE: Hz = whole signal, bursts/s = tach inside PWM");
}

static void sniff_log(void)
{
    static uint32_t last;
    if (now_ms - last < 1000) return;
    last = now_ms;

    for (uint8_t i = 0; i < 3; i++) {
        Sniff c;
        portENTER_CRITICAL(&sniff_mux);
        c.rises = sn[i].rises;   c.high_us = sn[i].high_us; c.low_us = sn[i].low_us;
        c.bursts = sn[i].bursts; c.level = sn[i].level;
        c.min_high = sn[i].min_high; c.max_high = sn[i].max_high;
        c.min_low = sn[i].min_low;   c.max_low = sn[i].max_low;
        sniff_reset(sn[i]);
        portEXIT_CRITICAL(&sniff_mux);

        if (c.rises == 0) {
            Serial.printf("%s: steady %s\n", SNIFF_NAME[i], c.level ? "HIGH" : "LOW");
            continue;
        }
        uint32_t tot = c.high_us + c.low_us;
        Serial.printf("%s: %5lu Hz  duty %3lu%%  bursts/s %4lu  high %lu-%lu us  low %lu-%lu us\n",
                      SNIFF_NAME[i], (unsigned long)c.rises,
                      (unsigned long)(tot ? (uint64_t)c.high_us * 100 / tot : 0),
                      (unsigned long)c.bursts,
                      (unsigned long)c.min_high, (unsigned long)c.max_high,
                      (unsigned long)c.min_low,  (unsigned long)c.max_low);
    }
    Serial.println("--");
}
#endif

/* ===================== COLOUR-WHEEL INDEX ===================== */

#if CW_EMU
static void cw_setup(void)
{
    const uint8_t  res  = 14;
    const uint32_t full = 1UL << res;
    uint32_t pulse = (uint32_t)((uint64_t)CW_PULSE_US * CW_HZ * full / 1000000UL);
    if (pulse < 1) pulse = 1;
    bool high_during_pulse = (CW_PULSE_LEVEL ^ CW_VIA_TRANSISTOR) != 0;
    uint32_t duty = high_during_pulse ? pulse : full - pulse;

    if (!ledcAttach(PIN_CW_INDEX, CW_HZ, res)) {
        Serial.println("CW: could not start LEDC");
        return;
    }
    ledcWrite(PIN_CW_INDEX, duty);
    Serial.printf("CW index: %u Hz, pulse %u us, %s pulse\n",
                  (unsigned)CW_HZ, (unsigned)CW_PULSE_US, CW_PULSE_LEVEL ? "high" : "low");
}
#endif

/* =========================== SETUP ============================ */

void setup()
{
    setCpuFrequencyMhz(80);                 /* less power and heat; plenty for this */

    Serial.begin(LOG_BAUD);

    pinMode(PIN_LED, OUTPUT);
    pinMode(PIN_SCI, INPUT_PULLUP);
#if FAN_EMU
    fan_setup();
#endif
#if FAN_SNIFF
    sniff_setup();
#endif
#if CW_EMU
    cw_setup();
#endif

    /* UART1: RX on PIN_RXD, TX on PIN_FLAG, 9600 8E1 */
    Ballast.begin(9600, SERIAL_8E1, PIN_RXD, PIN_FLAG);
    Ballast.onReceiveError([](hardwareSerial_error_t e) {
        if (e == UART_PARITY_ERROR || e == UART_FRAME_ERROR) rx_err = true;
    });

    /* Start in flag mode: Flag pin as GPIO, "lamp off" */
    gpio_set_direction((gpio_num_t)PIN_FLAG, GPIO_MODE_OUTPUT);
    flag_level(false);
    tx_attach_uart(false);

#if SCI_MODE
    attachInterrupt(digitalPinToInterrupt(PIN_SCI), sci_isr, CHANGE);
#endif

    vmem_init();

    /* Start-up blink: 3 fast */
    for (int i = 0; i < 3; i++) {
        digitalWrite(PIN_LED, LED_ACTIVE_HIGH ? HIGH : LOW); delay(80);
        digitalWrite(PIN_LED, LED_ACTIVE_HIGH ? LOW : HIGH); delay(80);
    }

    now_ms = millis();
    state_t0 = now_ms;
    Serial.println("\nP-VIP ballast emulator (ESP32) ready");
}

/* ============================ LOOP ============================ */

void loop()
{
    static uint32_t last_tick;
    static uint8_t  cmd[4];
    static uint8_t  cmd_n;
    static uint32_t cmd_t0;
    static uint32_t ignore_until;

    now_ms = millis();

#if FAN_EMU
    fan_tach_run();
#endif

    /* 1 ms tasks */
    if (now_ms != last_tick) {
        last_tick = now_ms;
#if FAN_EMU
        fan_tick_ms();
        fan_log();
#endif
#if FAN_SNIFF
        sniff_log();
#endif
        sci_update();
        lamp_tick();
        vmem_update();
        if (!uart_mode) flag_level(lamp_lit());
        led_update();
    }

    /* Parity/framing error: reply ACh and ignore data for 50 ms */
    if (rx_err) {
        rx_err = false;
        Serial.println("RX error");
        if (uart_mode) send1(0xAC);
        ignore_until = now_ms + 50;
        err_flash_until = now_ms + 1000;
        cmd_n = 0;
    }

    while (Ballast.available()) {
        uint8_t b = (uint8_t)Ballast.read();
        if ((int32_t)(ignore_until - now_ms) > 0) continue;

        if (!uart_mode) {
            log_bytes('<', &b, 1);
            if (b == 0x70) {
                enter_uart_mode();
                send1(0x70);
            }
            continue;
        }

        if (cmd_n == 0) cmd_t0 = now_ms;
        cmd[cmd_n++] = b;

        uint8_t need = cmd_len(cmd[0]);
        if (need == 0) {
            log_bytes('<', cmd, 1);
            send_err_echo(cmd, 1);
            cmd_n = 0;
        } else if (cmd_n >= need) {
            execute(cmd, cmd_n);
            cmd_n = 0;
        }
    }

    /* Incomplete command after 15 ms: clear and reply ABh */
    if (cmd_n && (now_ms - cmd_t0) > 15) {
        Serial.println("Timeout");
        send1(0xAB);
        err_flash_until = now_ms + 1000;
        cmd_n = 0;
    }
}
