# CachyOS Gaming Mode on NVIDIA Optimus Laptops (Intel + NVIDIA)

> **⚠️ Important Disclaimer**
> 
> These files are the result of a **strictly personal configuration** tailored to a specific hardware setup (HP Omen). They **may not work on other devices** out of the box. Proceed with caution and adapt the system paths (especially in the fan control service) to your specific hardware if necessary.
> 

**Dependency:** The `nv-run-gm` script requires the `intel-noturbo` service to manage CPU temperatures. You must install it from here before proceeding: [https://github.com/ShyVortex/intel-noturbo](https://github.com/ShyVortex/intel-noturbo).  

The 'gamemode' package is also required. You can install it via:
```bash
sudo pacman -S gamemode lib32-gamemode
```

Add your user to the gamemode user group, then reboot:
```bash
sudo usermod -aG gamemode $USER
```

## How To

This guide explains how to properly configure the **Gaming Mode (Gamescope)** on CachyOS (Deckify) for laptops equipped with NVIDIA Optimus hybrid graphics (Intel iGPU + NVIDIA dGPU), solving two common issues:
1. A black screen when launching Gaming Mode without an external monitor connected (caused by Gamescope trying to hook into the NVIDIA GPU).
2. Games incorrectly launching on the integrated Intel GPU, ignoring the `prime-run` command due to Proton's isolated containers (*pressure-vessel*).

The solution consists of forcing the Steam interface to run lightly on the Intel GPU (which physically controls the laptop's internal screen) and using custom wrapper commands to "wake up" the NVIDIA GPU, apply thermal protections, and inject the correct drivers only when launching a game.

This repository provides two distinct wrappers to avoid conflicts between Desktop Mode and Gaming Mode. Follow the instructions below to install them.

## Step 1: Force Gamescope on the Intel GPU

To prevent the Gamescope session from crashing or returning a black screen while looking for NVIDIA video outputs, we must tell the compositor to use the integrated graphics bus.

1. Open the terminal in the directory where you cloned or downloaded this repository.
2. Create the user environment variables directory (if it doesn't already exist):
   ```bash
   mkdir -p ~/.config/environment.d
   ```

3. Copy the provided configuration file into the new directory:
   ```bash
   cp 10-gamescope-session.conf ~/.config/environment.d/
   ```


4. Reboot your computer to apply the changes. Now, Gaming Mode will stably start on your laptop's internal screen.

## Step 2: Install Thermal Services, GPU Limits, and Sudoers Rules

The `nv-run-gm` script automatically disables CPU Turbo Boost, sets the fans to maximum speed, and sets custom GPU frequency/performance limits when a game launches in Gaming Mode.

1. Make sure you have installed the [intel-noturbo](https://github.com/ShyVortex/intel-noturbo) service.
2. Copy the systemd service files (`omen-maxfan.service` and `nvidia-limits.service` included in this repository) to the systemd folder:
   ```bash
   sudo cp omen-maxfan.service nvidia-limits.service /etc/systemd/system/
   ```
3. Reload the systemd daemon so it recognizes the new services:
   ```bash
   sudo systemctl daemon-reload
   ```
4. **Crucial:** To allow the wrappers to start/stop these services and run `nvidia-smi` without prompting for a password (which would break the Gaming Mode UI), you must configure `sudoers`. Run:
   ```bash
   sudo visudo -f /etc/sudoers.d/gaming-tweaks
   ```
5. Paste the following line exactly as it is, then save and exit:
   ```text
   %wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl start intel-noturbo.service, /usr/bin/systemctl stop intel-noturbo.service, /usr/bin/systemctl start omen-maxfan.service, /usr/bin/systemctl stop omen-maxfan.service, /usr/bin/systemctl start nvidia-limits.service, /usr/bin/systemctl stop nvidia-limits.service, /usr/bin/nvidia-smi
   ```



## Step 3: Install the Wrapper Commands

We use two separate scripts to avoid state conflicts:

* `nv-run`: Only injects NVIDIA drivers (Best for Desktop Mode).
* `nv-run-gm`: Injects NVIDIA drivers AND triggers thermal automation (Best for Gaming Mode).

1. From the terminal, copy both provided files to your system's binaries path:
   ```bash
   sudo cp nv-run nv-run-gm /usr/local/bin/
   ```
2. Make both scripts executable with the following command:
   ```bash
   sudo chmod +x /usr/local/bin/nv-run /usr/local/bin/nv-run-gm
   ```

## Step 4: How to use the wrappers in Steam

Now that the system is set up, you can dynamically decide which GPU and thermal profile to use for each individual game.

Go to the game's **Properties** -> **General** and scroll down to the **Launch Options** field.

* **For Gaming Mode (NVIDIA + Auto Thermals):** Enter `nv-run-gm %command%`
* **For Desktop Mode (NVIDIA only):** Enter `nv-run %command%` (assuming you are manually managing your fans via GUI).
* **For Battery Saving (Intel iGPU):** Leave the launch options empty. The game will automatically start on the integrated Intel GPU without triggering the dedicated graphics or loud fans.

## Step 5: Unlock the Hotspot for Other Devices when Docker Is Installed

If Docker is installed, its `DOCKER-USER` iptables chain and its default `FORWARD` policy can silently block the traffic of devices connected to your Wi-Fi hotspot (phone, tablet, console, etc.): the clients associate with the hotspot but get no internet access.

This repository provides a NetworkManager dispatcher script that, every time the Wi-Fi interface comes up, inserts the missing forwarding rules in the `DOCKER-USER` chain and sets the TTL/hop limit to `64` on outgoing traffic (which also avoids tethering detection by some carriers).

1. Copy the dispatcher script to the NetworkManager dispatcher directory:
   ```bash
   sudo cp etc/NetworkManager/dispatcher.d/90-hotspot /etc/NetworkManager/dispatcher.d/
   ```
2. Make it executable and owned by root (NetworkManager ignores non-executable dispatcher scripts):
   ```bash
   sudo chown root:root /etc/NetworkManager/dispatcher.d/90-hotspot
   sudo chmod +x /etc/NetworkManager/dispatcher.d/90-hotspot
   ```
3. Restart NetworkManager (or simply toggle the hotspot off and on) so the script runs:
   ```bash
   sudo systemctl restart NetworkManager
   ```

> **Note:** The script assumes the hotspot interface is `wlan0` and the upstream connection is `eno1`. Edit the interface names in `/etc/NetworkManager/dispatcher.d/90-hotspot` to match your hardware (`ip link` shows the available interfaces) before copying it, otherwise the rules will never match.

To verify that the rules were applied:
```bash
sudo iptables -S DOCKER-USER
sudo nft list table inet ttlfix
```

## Step 6: Fix Audio from a USB HDMI Capture Card (UGREEN)

When using an HDMI capture card to play a console on the laptop, Linux can detect the card as an audio input but deliver **silence**. On the UGREEN 15390, the ALSA capture switch `Digital In` is disabled by default (Windows enables it automatically).

The `scripts/setup-ugreen-audio.sh` script installs a udev rule that turns the capture switch on every time the card is plugged in, so no manual `amixer` command is needed after a reboot or a reconnection.

**Dependency:** The script requires `alsa-utils` (which provides `amixer`). Install it with:
```bash
sudo pacman -S alsa-utils
```

1. Run the script with root privileges from the repository directory:
   ```bash
   sudo bash scripts/setup-ugreen-audio.sh
   ```
2. If the card is already connected, the script enables `Digital In` immediately; otherwise the rule applies the next time you plug the card in.
3. If an application was already using the capture card, restart it so it picks up the new audio source.

> **Note:** For a different capture card, run `arecord -l` to find its ALSA id (the name after `card N:`) and `amixer -c N` to list its capture controls, then edit the `CARD_ID` and `CONTROL` variables at the top of `scripts/setup-ugreen-audio.sh` before running it.

## Step 7: Fix Random Audio Hitches (Intel 12th Gen, SOF Audio)

On this laptop (i7-12700H, Intel SOF audio driver), audio can hitch or stutter every now and then, on the speakers and on Bluetooth headphones alike, while the logs show no error.

PipeWire runs every output at the smallest buffer ("quantum") that any playing app asks for, and the default minimum is only 256 samples. As soon as one app requests low latency (a browser, an Electron app, a game, or a capture card's sound passthrough), every output drops to 5–10 ms buffers, which this hardware does not keep up with. Raising the minimum to 1024 samples (about 21 ms) fixes it. The same fix is reported for this CPU in [Bazzite issue #4283](https://github.com/ublue-os/bazzite/issues/4283).

1. Copy the configuration file:
   ```bash
   mkdir -p ~/.config/pipewire/pipewire.conf.d
   cp home/.config/pipewire/pipewire.conf.d/99-min-quantum.conf ~/.config/pipewire/pipewire.conf.d/
   ```
2. Restart PipeWire (or reboot):
   ```bash
   systemctl --user restart pipewire pipewire-pulse wireplumber
   ```
3. To check that it applied:
   ```bash
   pw-metadata -n settings | grep min-quantum
   ```
   It should show `1024`.

> **Note:** To try the fix without installing anything, run `pw-metadata -n settings 0 clock.min-quantum 1024`. It lasts until PipeWire restarts. The trade-off is about 21 ms of minimum audio latency, which is not noticeable for media and games.

---

*Note: This guide assumes that your hardware manager (e.g., envycontrol or supergfxctl) is set to **Hybrid** mode.*
