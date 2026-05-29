// Package nvml wraps NVIDIA Management Library device queries.
// On non-Linux hosts or hosts without an NVIDIA driver, all functions
// return ErrNotAvailable so callers can skip GPU probes gracefully.
package nvml

import (
	"errors"
	"fmt"
	"runtime"
)

// ErrNotAvailable is returned when NVML is not usable on the current host.
var ErrNotAvailable = errors.New("nvml: not available on this host")

// MemoryInfo holds instantaneous GPU memory metrics for a single device.
type MemoryInfo struct {
	// DeviceIndex is the NVML device ordinal (0-based).
	DeviceIndex int
	// UsedBytes is the amount of GPU memory currently allocated.
	UsedBytes uint64
	// TotalBytes is the total GPU memory capacity.
	TotalBytes uint64
	// BandwidthUtilPct is the memory-bandwidth utilisation percentage (0–100)
	// as reported by nvmlDeviceGetMemoryInfo or derived from NVML perf counters.
	BandwidthUtilPct float64
}

// Available reports whether NVML device queries can be made on this host.
// It checks the OS (must be Linux) as a fast pre-filter; actual driver
// availability is confirmed lazily by the first real NVML call.
func Available() bool {
	return runtime.GOOS == "linux"
}

// DeviceCount returns the number of NVIDIA GPU devices visible to NVML.
//
// Stub: real implementation calls nvml.Init() then nvml.DeviceGetCount().
// Replace this body with go-nvml calls on GPU hosts:
//
//	import "github.com/NVIDIA/go-nvml/pkg/nvml"
//	ret := nvml.Init(); if ret != nvml.SUCCESS { ... }
//	count, ret := nvml.DeviceGetCount(); ...
func DeviceCount() (int, error) {
	if !Available() {
		return 0, ErrNotAvailable
	}
	// Stub: no real NVML driver linked. Returns ErrNotAvailable even on Linux
	// until the real go-nvml binding is wired in.
	return 0, ErrNotAvailable
}

// QueryMemory returns memory metrics for the device at the given index.
//
// Stub: real implementation calls nvml.DeviceGetHandleByIndex then
// nvml.DeviceGetMemoryInfo. Bandwidth utilisation requires a separate
// nvml.DeviceGetFieldValues call on the NVML_FI_DEV_MEM_COPY_UTIL field.
func QueryMemory(deviceIndex int) (MemoryInfo, error) {
	if !Available() {
		return MemoryInfo{}, ErrNotAvailable
	}
	return MemoryInfo{}, fmt.Errorf("device %d: %w", deviceIndex, ErrNotAvailable)
}
