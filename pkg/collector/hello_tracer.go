package collector

import (
	"context"
	"strings"
	"time"
)

// HelloEvent is a minimal evidence-grade tracer event exported by the agent.
type HelloEvent struct {
	Timestamp time.Time
	Comm      string
	Count     uint64
}

// HelloTracer emits periodic per-comm syscall activity events.
// This is a lightweight "hello-world" tracer path to prove end-to-end wiring.
type HelloTracer struct {
	targets  []string
	interval time.Duration
}

// NewHelloTracer creates a tracer for target process comm names.
func NewHelloTracer(targets []string, interval time.Duration) *HelloTracer {
	if interval <= 0 {
		interval = 2 * time.Second
	}
	return &HelloTracer{
		targets:  sanitizeTargets(targets),
		interval: interval,
	}
}

// Targets returns sanitized comm targets.
func (t *HelloTracer) Targets() []string {
	out := make([]string, len(t.targets))
	copy(out, t.targets)
	return out
}

// Start begins emitting hello events until context cancellation.
func (t *HelloTracer) Start(ctx context.Context, emit func(HelloEvent)) {
	if emit == nil || len(t.targets) == 0 {
		return
	}

	emitTick := func(ts time.Time) {
		for _, comm := range t.targets {
			emit(HelloEvent{
				Timestamp: ts.UTC(),
				Comm:      comm,
				Count:     1,
			})
		}
	}

	emitTick(time.Now().UTC())
	ticker := time.NewTicker(t.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case ts := <-ticker.C:
			emitTick(ts)
		}
	}
}

func sanitizeTargets(targets []string) []string {
	seen := map[string]struct{}{}
	out := make([]string, 0, len(targets))
	for _, t := range targets {
		v := strings.TrimSpace(t)
		if v == "" {
			continue
		}
		if _, ok := seen[v]; ok {
			continue
		}
		seen[v] = struct{}{}
		out = append(out, v)
	}
	return out
}
