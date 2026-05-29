package collector_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/ogulcanaydogan/llm-slo-ebpf-toolkit/pkg/collector"
	"github.com/ogulcanaydogan/llm-slo-ebpf-toolkit/pkg/nvml"
)

func TestGPUMetricSampleFaultDomain(t *testing.T) {
	s := collector.GPUMetricSample{}
	if s.FaultDomain() != "gpu" {
		t.Errorf("FaultDomain() = %q; want %q", s.FaultDomain(), "gpu")
	}
}

func TestGPUBandwidthSamplerUnavailableOnNonGPUHost(t *testing.T) {
	sampler := collector.NewGPUBandwidthSampler(100 * time.Millisecond)
	out := make(chan collector.GPUMetricSample, 1)
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()

	err := sampler.Start(ctx, out)
	if err == nil {
		t.Skip("NVML available on this host; skipping unavailability test")
	}
	if !errors.Is(err, nvml.ErrNotAvailable) {
		t.Errorf("Start error = %v; want to wrap nvml.ErrNotAvailable", err)
	}
}
