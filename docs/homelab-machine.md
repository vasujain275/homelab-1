# Homelab Machine — `homelab-1`

## Hardware

| Component | Spec |
|-----------|------|
| Model | Dell Inspiron 5000 |
| CPU | Intel i3-6006U (2 cores, 2.0 GHz) |
| RAM | 8 GB DDR4 |
| OS Drive | 512 GB SSD (`/dev/sda`) |
| Network | WiFi — VJ-Wifi-2.4G, static IP `192.168.1.75` |
| GPU | Intel HD Graphics 520 (integrated) |
| Keyboard | Dell backlit (`dell::kbd_backlight`) |

> Laptop running headless as a homelab server. Lid stays shut most of the time.

## OS

| Detail | Value |
|--------|-------|
| OS | Ubuntu Server 26.04 LTS (Resolute Raccoon) |
| Kernel | `7.0.0-27-generic` |
| User | `vasu` (sudoer, password stored in `~/homelab-pass.txt` on **local** machine) |
| SSH | `ssh vasu@192.168.1.75`, passwordless key auth |

---

## Applied Configuration

All changes applied on **2026-07-08**.

### 1. Cloud-init Disabled

- `/etc/cloud/cloud-init.disabled` — upstream disable file
- `systemctl mask cloud-init.target cloud-init.service cloud-init-local.service`

Cloud-init no longer runs at boot.

### 2. Sleep/Suspend Disabled

All `Handle*` switches in `/etc/systemd/logind.conf` set to `ignore`:

```ini
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleHybridSleepKey=ignore
```

Laptop **never sleeps** on lid close, power button, or idle. Confirmed: `sleep.target`, `suspend.target`, `hibernate.target` all `inactive`.

### 3. Keyboard Backlight — Always Off

Systemd oneshot service at `/etc/systemd/system/kbd-backlight-off.service`:

```ini
[Unit]
Description=Set keyboard backlight to 0
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 0 > /sys/class/leds/dell::kbd_backlight/brightness'
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

Enabled at boot. Keyboard LEDs never light up.

### 4. Display Blank After 5 Min (No Sleep)

Added to `/etc/default/grub`:

```
GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=300 pcie_aspm=off irqpoll"
```

- `consoleblank=300` → TTY display blanks after **300 seconds (5 min)** of no input.
- Any keypress wakes the display.
- System does **not** sleep — only the display powers off.
- Applies to all TTYs (`tty1`–`tty6`) including the login prompt.

### 5. Docker + Docker Compose v2

Installed from [Docker's official APT repo](https://docs.docker.com/engine/install/ubuntu/).

| Component | Version |
|-----------|---------|
| Docker Engine | `29.6.1` |
| Docker Compose | `v5.3.1` (plugin, `docker compose` command) |
| Docker Buildx | `0.35.0` |
| containerd | `2.2.5` |

- `vasu` added to `docker` group — no `sudo` needed for `docker` commands.
- Verify: `docker run hello-world`, `docker compose version`.

### 6. Wi-Fi Stability (ath10k PCIe Fix)

The Dell's Qualcomm Atheros `ath10k` Wi-Fi card drops connectivity when PCIe Active State Power Management (ASPM) kicks in during idle. This causes fatal PCIe bus errors and IRQ disablement — Wi-Fi dies until reboot.

Fix: disabled PCIe ASPM + enabled interrupt polling via kernel params:

```
pcie_aspm=off irqpoll
```

- `pcie_aspm=off` — prevents the Wi-Fi card from entering buggy low-power PCIe states
- `irqpoll` — fallback polling if hardware interrupts become unreliable
- Trade-off: negligible idle power increase (~1W), large stability gain

### 7. Bootloader

- GRUB timeout: `0` (no menu, boots directly)
- Kernel params: `consoleblank=300 pcie_aspm=off irqpoll crashkernel=2G-4G:320M,...`
- Drop-in: `/etc/default/grub.d/kdump-tools.cfg` (appends `crashkernel=`)

---

## Post-Reboot Verification

After reboot, all of the above persists. Quick checks:

```bash
# cloud-init disabled?
systemctl is-enabled cloud-init.service   # → masked

# lid ignored?
grep ^Handle /etc/systemd/logind.conf

# kb backlight off?
cat /sys/class/leds/dell::kbd_backlight/brightness   # → 0

# kernel params correct?
cat /proc/cmdline | grep -E "consoleblank|pcie_aspm|irqpoll"
# → consoleblank=300 pcie_aspm=off irqpoll

# docker working?
docker ps && docker compose version
```
