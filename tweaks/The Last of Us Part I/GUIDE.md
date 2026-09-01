# How to run on NVIDIA

1. Switch to LTS Kernel (linux-cachyos-lts)
2. Downgrade to NVIDIA 580xx drivers
```bash
sudo pacman -S lib32-nvidia-580xx-utils lib32-opencl-nvidia-580xx libxnvctrl-580xx nvidia-580xx-dkms nvidia-580xx-settings nvidia-580xx-utils opencl-nvidia-580xx
```
3. Use Proton-CachyOS Latest (via ProtonPlus) with launch options