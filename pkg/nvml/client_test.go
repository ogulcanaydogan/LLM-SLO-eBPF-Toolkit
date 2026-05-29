package nvml_test

import (
	"errors"
	"runtime"
	"testing"

	"github.com/ogulcanaydogan/llm-slo-ebpf-toolkit/pkg/nvml"
)

func TestAvailableOnlyOnLinux(t *testing.T) {
	got := nvml.Available()
	want := runtime.GOOS == "linux"
	if got != want {
		t.Errorf("Available() = %v; want %v (GOOS=%s)", got, want, runtime.GOOS)
	}
}

func TestDeviceCountReturnsErrNotAvailableOnNonGPUHost(t *testing.T) {
	count, err := nvml.DeviceCount()
	if err == nil {
		// A real GPU host with go-nvml linked may succeed; skip in that case.
		t.Skipf("nvml.DeviceCount succeeded with count=%d; skipping stub test on GPU host", count)
	}
	if !errors.Is(err, nvml.ErrNotAvailable) {
		t.Errorf("DeviceCount error = %v; want to wrap nvml.ErrNotAvailable", err)
	}
}

func TestQueryMemoryReturnsErrNotAvailableOnNonGPUHost(t *testing.T) {
	_, err := nvml.QueryMemory(0)
	if err == nil {
		t.Skip("nvml.QueryMemory succeeded; skipping stub test on GPU host")
	}
	if !errors.Is(err, nvml.ErrNotAvailable) {
		t.Errorf("QueryMemory error = %v; want to wrap nvml.ErrNotAvailable", err)
	}
}
