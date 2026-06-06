# Software Networks Project: E4 – High-Volume Traffic Detector (eBPF)

**Author:** Mateusz Winiecki (Index: 0383412)
**Level:** Basic Level
**Course:** Software Networks (2025-2026)

---

## Table of Contents

- [Project Overview](#1-project-overview)
- [Prerequisites](#2-prerequisites)
- [Installation & Setup](#3-installation--setup)
- [Project Structure](#4-project-structure)
- [Building the Project](#5-building-the-project)
- [Running the Detector](#6-running-the-detector)
- [Testing](#7-testing)

---

## 1. Project Overview

This project implements the **Basic Level** of the *High-Volume Traffic Detector* (E4) using **eBPF** and **XDP (eXpress Data Path)**. The core objective is to identify and log network sources that generate anomalous traffic volumes — specifically those exceeding **100 packets per second (pps)**.

The architecture relies on two main components:

| Component | Language | File name | Role |
|---|---|---|---|
| **Kernel-Space** | C | `program.c` | eBPF/XDP program — parses packets and counts per source IP |
| **User-Space** | Go | `main.go` | Daemon — polls the BPF map, computes rates, triggers alerts |

---

## 2. Prerequisites

### System Requirements

- **OS:** Linux kernel **5.15+** (Ubuntu 22.04 LTS or newer recommended)
- **Architecture:** x86_64
- **Privileges:** Root / `sudo` access required

### Verify Kernel Version

```bash
uname -r
```

The output should be `5.15` or higher. XDP and eBPF LRU maps require this minimum.

### Update Your System

Before installing any dependencies, make sure your system is fully up to date:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 3. Installation & Setup

### 3.1 Install Build Dependencies

Install the essential tools required for compiling and running the eBPF environment:

```bash
sudo apt install -y curl git golang clang llvm libbpf-dev linux-headers-$(uname -r) gcc-multilib
```

| Package | Purpose |
|---|---|
| `curl` | Downloading files and tools from the internet |
| `git` | Version control — cloning and managing the repository |
| `golang` | Go compiler and toolchain for building the user-space daemon |
| `clang` | C compiler used to compile the eBPF program to BPF bytecode |
| `llvm` | Backend toolchain required by Clang for the BPF target architecture |
| `libbpf-dev` | Development library for loading eBPF programs and interacting with BPF maps |
| `linux-headers-$(uname -r)` | Kernel headers matching the running kernel, needed for BPF type definitions |
| `gcc-multilib` | GCC with multilib support, required for cross-architecture includes used by Clang/BPF |



### 3.2 Clone the Repository

```bash
git clone git@github.com:Waniuu/kernel-playground.git
cd kernel-playground/E4-DDoS-Detector
```

---

## 4. Project Structure

```
E4-DDoS-Detector/
├── program.c             # eBPF kernel-space program (C)
├── main.go               # User-space daemon (Go)
├── go.mod                # Go module definition
├── go.sum                # Go dependency checksums
├── screenshot.png        # Visual evidence of the flood test
└── README.md             # This documentation file
```

---

## 5. Building the Project

### 5.1 Compile the eBPF Program

To compile the kernel-space C program into eBPF bytecode and automatically generate Go bindings using the bpf2go tool, run:

```bash
go generate
```

### 5.2 Build the Go Daemon

Once the bytecode is generated, compile the Go user-space application into an executable binary:


```bash
go build -o ddos_detector
```

---

## 6. Running the Detector

> **Root privileges are required** to attach eBPF programs to network interfaces. By default, the program attaches to the local loopback interface (lo) for safe testing.

### 6.1 Start the Detector

```bash
sudo ./ddos_detector
```

## 6.2 Example Output

```
 2026/06/05 18:36:07 Anti-DDoS shield active on lo. Packet analysis started...
```

To stop the detector and safely detach the XDP program, press `Ctrl+C`.

---

## 7. Testing

To verify the functionality, you need to generate a high volume of traffic. The loopback interface (lo) is used to simulate a local attack safely.

**Stimulate a volumetric attack** in a second terminal using the `ping` command with the flood `(-f)` flag:

```
 sudo ping -f -c 500 127.0.0.1
```


**Observe the alert** in the first terminal. The user-space daemon will detect the anomaly and print a red warning:

```
 2026/06/05 18:36:39 [ALARM] High-volume traffic detected! 127.0.0.1 sent 1000 packets per second
```

---



*Project submitted as part of the Software Networks course (2025–2026), Università degli Studi di Roma Tor Vergata .*
