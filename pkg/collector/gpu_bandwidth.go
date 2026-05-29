package collector

import (
	"context"
	"fmt"
	"time"

	"github.com/ogulcanaydogan/llm-slo-ebpf-toolkit/pkg/nvml"
)

// GPUMetricSample holds a single GPU memory-bandwidth observation.
// It is emitted by GPUBandwidthSampler on each collection tick and can
// be forwarded to the attribution pipeline under fault-domain "gpu".
type GPUMetricSample struct {
	Timestamp        time.Time
	DeviceIndex      int
	BandwidthUtilPct float64
	MemUsedBytes     uint64
	MemTotalBytes    uint64
}

// FaultDomain returns the attribution domain label for GPU metrics.
func (GPUMetricSample) FaultDomain() string { return "gpu" }

// GPUBandwidthSampler polls NVIDIA GPU memory-bandwidth metrics via NVML
// at a fixed interval and sends observations to the provided channel.
//
// Start returns nvml.ErrNotAvailable when no NVIDIA driver is present so
// the caller can skip GPU probing on non-GPU hosts without crashing.
type GPUBandwidthSampler struct {
	interval time.Duration
}

// NewGPUBandwidthSampler creates a sampler with the given polling interval.
func NewGPUBandwidthSampler(interval time.Duration) *GPUBandwidthSampler {
	return &GPUBandwidthSampler{interval: interval}
}

// Start begins polling GPU memory-bandwidth metrics and sends samples to out.
// Blocking; call in a goroutine. Stops when ctx is cancelled.
// Returns nvml.ErrNotAvailable immediately when NVML is not present.
func (s *GPUBandwidthSampler) Start(ctx context.Context, out chan<- GPUMetricSample) error {
	if !nvml.Available() {
		return fmt.Errorf("gpu_bandwidth sampler: %w", nvml.ErrNotAvailable)
	}

	count, err := nvml.DeviceCount()
	if err != nil {
		return fmt.Errorf("gpu_bandwidth sampler: device count: %w", err)
	}
	if count == 0 {
		return fmt.Errorf("gpu_bandwidth sampler: no NVIDIA devices found")
	}

	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil
		case t := <-ticker.C:
			for i := range count {
				info, err := nvml.QueryMemory(i)
				if err != nil {
					continue
				}
				select {
				case out <- GPUMetricSample{
					Timestamp:        t,
					DeviceIndex:      i,
					BandwidthUtilPct: info.BandwidthUtilPct,
					MemUsedBytes:     info.UsedBytes,
					MemTotalBytes:    info.TotalBytes,
				}:
				case <-ctx.Done():
					return nil
				}
			}
		}
	}
}
