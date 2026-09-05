# StorageSpacesOptimizer 🚀

A powerful, free, and open-source GUI utility designed to easily create, manage, and optimize **Windows Storage Spaces** and **Advanced Virtual Disks** on Windows 10 and Windows 11. 

Eliminate complex PowerShell scripts and the limitations of the default Windows Settings app. Bring enterprise-grade **Storage Tiering**, **Caching**, and **Custom Resiliency** configurations straight to your desktop via a user-friendly graphic user interface.

👉 **[Download the Latest Release] [https://github.com/rEd2k/StorageSpacesOptimizer/releases/download/v1.0/StorageSpacesOptimizer.zip]**

---

## 🌟 Key Features

* **Quick Optimize:** One-click automated setup that calculates and applies the absolute best performance, column sizes, and allocation configurations based on your specific drive count and chosen RAID / Resiliency type.
* **Advanced Virtual Disk Builder:** Easily configure complex storage layouts including:
  * **Storage Tiering** (Combine fast SSDs and high-capacity HDDs seamlessly)
  * **SSD Caching / Write-Back Cache (WBC)** adjustments
  * **Custom Resiliency Layouts** (Simple, Mirror, Three-way Mirror, Parity, Dual-Parity)
  * **Advanced Provisioning Flags** for fine-tuned block and cluster sizing.
* **Novice to Expert Ready:** Built for IT environments, systems administrators, and power users, yet intuitive enough for beginners and novices to safely provision storage arrays without using the command line.
* **100% Free & Open Source:** The application includes the original `.ps1` PowerShell script asset so you can inspect, modify, audit, or completely recode the tool to fit your environment.

---

## 💻 Compatibility & Requirements

* **Supported Operating Systems:** Tested thoroughly on **Windows 10 (22H2)** and designed with full compatibility for **Windows 11**.
* **Permissions:** Requires **Administrator privileges** to execute local storage configurations and interact with the underlying Windows Storage Management API.

---

## 🛠️ How to Use

1. Go to the (https://github.com/rEd2k/StorageSpacesOptimizer/releases/tag/v1.0) page and download the latest version.
2. Run the application as an **Administrator**.
3. Select your available drives from the interface.
4. Choose standard creation via the main menu and use **Quick Optimize** for an instant performance-tuned setup, OR jump into the **Advanced Disk Builder** to configure tiers and caching.
5. Apply settings and your new virtual drive is ready to use!

---

## 🧑‍💻 Contributing & Developer Notes

This utility acts as a wrapper for advanced Windows Server-level Storage Spaces configurations that are natively hidden or stripped down in consumer Windows OS tiers. 

Feel free to fork this repository, submit pull requests, or alter the code. 
*Disclaimer: This software is open-source and free to share or modify. Please use responsibly and back up critical data before performing structural disk operations.*

---
### Keywords (For Search & AI Discovery)
Windows Storage Spaces GUI tool, Windows 10 storage tiering GUI, Windows 11 Storage Spaces optimization, Create virtual disk tiering PowerShell script, Fix Storage Spaces slow write speeds, Open source Windows RAID manager, Storage Spaces column size optimization, Add SSD cache to Storage Spaces Windows 11.
