//go:build ignore

#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>

// Create an LRU_HASH map according to the project requirements.
// The key is the source IP address (32-bit), the value is the packet count (64-bit).
struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u64);
} ip_counters SEC(".maps");

SEC("xdp")
int detect_flood(struct xdp_md *ctx) {
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;

    // Verify the Ethernet header
    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;

    // We are only interested in IPv4 packets
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;

    // Parse the IP header
    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;

    __u32 saddr = ip->saddr;

    // Lookup the source IP address in the map
    __u64 *count = bpf_map_lookup_elem(&ip_counters, &saddr);
    
    if (count) {
        // If the IP is already in the map, safely increment the counter
        __sync_fetch_and_add(count, 1);
    } else {
        // If this is the first packet from this IP, initialize the counter to 1
        __u64 init_val = 1;
        bpf_map_update_elem(&ip_counters, &saddr, &init_val, BPF_ANY);
    }

    // As per the Basic level requirements, we do not drop traffic yet, just pass it
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
