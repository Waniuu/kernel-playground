package main

//go:generate go run github.com/cilium/ebpf/cmd/bpf2go bpf program.c

import (
	"encoding/binary"
	"log"
	"net"
	"time"

	"github.com/cilium/ebpf/link"
)

func main() {
	objs := bpfObjects{}
	if err := loadBpfObjects(&objs, nil); err != nil {
		log.Fatalf("Error loading eBPF objects: %v", err)
	}
	defer objs.Close()

	// Attach to the network interface (e.g., 'enp0s3', or 'lo' for local testing)
	ifaceName := "lo"
	iface, err := net.InterfaceByName(ifaceName)
	if err != nil {
		log.Fatalf("Interface not found: %v", err)
	}

	lnk, err := link.AttachXDP(link.XDPOptions{
		Program:   objs.DetectFlood,
		Interface: iface.Index,
	})
	if err != nil {
		log.Fatalf("Error attaching XDP program: %v", err)
	}
	defer lnk.Close()

	log.Printf("Anti-DDoS shield active on %s. Packet analysis started...", ifaceName)

	// Go map to store the packet counts from the previous second
	prevCounts := make(map[uint32]uint64)

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		var key uint32
		var value uint64
		entries := objs.IpCounters.Iterate()
		
		for entries.Next(&key, &value) {
			// Get the previous count (defaults to 0 if not present)
			prev := prevCounts[key]
			
			// Calculate the number of packets received in the current second
			packetsPerSec := value - prev
			
			// Save the current state for the next iteration
			prevCounts[key] = value

			if packetsPerSec > 100 {
				ipBytes := make([]byte, 4)
				binary.LittleEndian.PutUint32(ipBytes, key)
				readableIP := net.IP(ipBytes)

				log.Printf("\033[31m[ALARM] High-volume traffic detected! %s sent %d packets per second!\033[0m", readableIP.String(), packetsPerSec)
			}
		}
	}
}
