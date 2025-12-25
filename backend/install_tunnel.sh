#!/bin/bash
# Cloudflare Tunnel Auto-Install Script for Raspberry Pi

echo "Installing Cloudflared..."
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

sudo apt-get update
sudo apt-get install cloudflared -y

echo "Configuring Tunnel..."
sudo cloudflared service install eyJhIjoiM2ZkYzZkNjU5MTdjNDg1YjU4MDViYjU3YzcwOTNlYzciLCJ0IjoiZDJjYThkZDYtNWVkOC00YmJiLThkOTktZGEzZTk5NzZkNDA0IiwicyI6Ik9USmlNak5oTVdVdE1tWmlaQzAwTVRBMUxUazVaVFl0TnpnNE5UZzBaRFkyTURJNCJ9

echo "Done! Tunnel should be active."
