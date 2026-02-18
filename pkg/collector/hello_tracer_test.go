package collector

import (
	"context"
	"testing"
	"time"
)

func TestHelloTracerSanitizeTargets(t *testing.T) {
	tr := NewHelloTracer([]string{"rag-service", "", "rag-service", "llama-server"}, time.Second)
	got := tr.Targets()
	if len(got) != 2 {
		t.Fatalf("expected 2 unique targets, got %d", len(got))
	}
	if got[0] != "rag-service" || got[1] != "llama-server" {
		t.Fatalf("unexpected targets: %#v", got)
	}
}

func TestHelloTracerStartEmits(t *testing.T) {
	tr := NewHelloTracer([]string{"rag-service"}, 20*time.Millisecond)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	events := make(chan HelloEvent, 4)
	go tr.Start(ctx, func(ev HelloEvent) {
		events <- ev
	})

	select {
	case ev := <-events:
		if ev.Comm != "rag-service" {
			t.Fatalf("unexpected comm %q", ev.Comm)
		}
	case <-time.After(200 * time.Millisecond):
		t.Fatalf("expected hello event")
	}
}
