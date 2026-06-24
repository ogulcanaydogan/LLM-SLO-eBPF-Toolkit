package safety

import (
	"errors"
	"runtime"
	"testing"
)

// stubSampler returns a fixed sequence of CPU samples (or an error) so the
// overhead guard can be exercised without reading real /proc counters.
type stubSampler struct {
	samples []CPUSample
	err     error
	calls   int
}

func (s *stubSampler) Sample() (CPUSample, error) {
	if s.err != nil {
		return CPUSample{}, s.err
	}
	out := s.samples[s.calls]
	s.calls++
	return out, nil
}

func TestOverheadGuardNilSamplerReturnsError(t *testing.T) {
	g := NewOverheadGuardWithSampler(5.0, nil)
	_, trip, err := g.Evaluate()
	if err == nil {
		t.Fatal("expected error for nil sampler, got nil")
	}
	if trip {
		t.Error("nil sampler must not trip the guard")
	}
}

func TestOverheadGuardPropagatesSamplerError(t *testing.T) {
	sentinel := errors.New("sample failed")
	g := NewOverheadGuardWithSampler(5.0, &stubSampler{err: sentinel})
	if _, _, err := g.Evaluate(); !errors.Is(err, sentinel) {
		t.Fatalf("expected sampler error to propagate, got %v", err)
	}
}

func TestOverheadGuardFirstCallEstablishesBaseline(t *testing.T) {
	g := NewOverheadGuardWithSampler(5.0, &stubSampler{
		samples: []CPUSample{{ProcessTicks: 10, TotalTicks: 100}},
	})
	pct, trip, err := g.Evaluate()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if pct != 0 || trip {
		t.Errorf("first call should be a no-op baseline, got pct=%v trip=%v", pct, trip)
	}
}

func TestOverheadGuardTripsWhenOverThreshold(t *testing.T) {
	g := NewOverheadGuardWithSampler(5.0, &stubSampler{
		samples: []CPUSample{
			{ProcessTicks: 0, TotalTicks: 0},
			{ProcessTicks: 100, TotalTicks: 100},
		},
	})
	if _, _, err := g.Evaluate(); err != nil {
		t.Fatalf("baseline error: %v", err)
	}

	pct, trip, err := g.Evaluate()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// ratio 1.0 * 100 * NumCPU; independent of the host CPU count beyond scaling.
	want := 100.0 * float64(runtime.NumCPU())
	if pct != want {
		t.Errorf("expected pct=%v, got %v", want, pct)
	}
	if !trip {
		t.Error("expected guard to trip when overhead exceeds the max percentage")
	}
}

func TestOverheadGuardStaysUnderThreshold(t *testing.T) {
	g := NewOverheadGuardWithSampler(50.0, &stubSampler{
		samples: []CPUSample{
			{ProcessTicks: 5, TotalTicks: 100},
			{ProcessTicks: 5, TotalTicks: 200}, // host advanced, process did not
		},
	})
	if _, _, err := g.Evaluate(); err != nil {
		t.Fatalf("baseline error: %v", err)
	}

	pct, trip, err := g.Evaluate()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if pct != 0 {
		t.Errorf("expected 0%% overhead when the process did no work, got %v", pct)
	}
	if trip {
		t.Error("guard must not trip below the max percentage")
	}
}

func TestOverheadGuardIgnoresNonIncreasingTotalTicks(t *testing.T) {
	g := NewOverheadGuardWithSampler(5.0, &stubSampler{
		samples: []CPUSample{
			{ProcessTicks: 10, TotalTicks: 200},
			{ProcessTicks: 50, TotalTicks: 150}, // total counter went backwards
		},
	})
	if _, _, err := g.Evaluate(); err != nil {
		t.Fatalf("baseline error: %v", err)
	}

	pct, trip, err := g.Evaluate()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if pct != 0 || trip {
		t.Errorf("non-increasing total ticks must yield 0/false, got pct=%v trip=%v", pct, trip)
	}
}
