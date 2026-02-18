//go:build ignore

#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_core_read.h>
#include "llm_slo_event.h"

char LICENSE[] SEC("license") = "Dual BSD/GPL";

struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 1 << 24);
} events SEC(".maps");

#ifndef LLM_SLO_HELLO_WRITE
#define LLM_SLO_HELLO_WRITE 100
#endif

SEC("tracepoint/syscalls/sys_enter_write")
int handle_sys_enter_write(struct trace_event_raw_sys_enter *ctx) {
    struct llm_slo_event *event;
    struct task_struct *task;

    task = (struct task_struct *)bpf_get_current_task_btf();
    if (!task) {
        return 0;
    }

    event = bpf_ringbuf_reserve(&events, sizeof(*event), 0);
    if (!event) {
        return 0;
    }

    event->pid = (__u32)(bpf_get_current_pid_tgid() >> 32);
    event->tid = (__u32)bpf_get_current_pid_tgid();
    event->timestamp_ns = bpf_ktime_get_ns();
    event->signal_type = LLM_SLO_HELLO_WRITE;
    event->value_ns = 1;
    event->conn_src_port = 0;
    event->conn_dst_port = 0;
    event->conn_dst_ip = 0;
    event->errno_val = 0;

    bpf_ringbuf_submit(event, 0);
    return 0;
}
