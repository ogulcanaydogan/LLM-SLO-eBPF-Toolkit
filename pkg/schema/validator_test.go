package schema

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"gopkg.in/yaml.v3"
)

func schemaPath(t *testing.T, rel string) string {
	t.Helper()
	_, filename, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("could not resolve caller")
	}
	root := filepath.Clean(filepath.Join(filepath.Dir(filename), "..", ".."))
	return filepath.Join(root, rel)
}

func TestValidateSLOEventSchema(t *testing.T) {
	event := SLOEvent{
		EventID:   "evt-1",
		Timestamp: time.Now().UTC(),
		Cluster:   "local",
		Namespace: "default",
		Workload:  "demo",
		Service:   "chat",
		RequestID: "req-1",
		SLIName:   "ttft_ms",
		SLIValue:  210,
		Unit:      "ms",
		Status:    "ok",
	}
	if err := ValidateAgainstSchema(schemaPath(t, "docs/contracts/v1/slo-event.schema.json"), event); err != nil {
		t.Fatalf("schema validation failed: %v", err)
	}
}

func TestValidateIncidentSchema(t *testing.T) {
	incident := IncidentAttribution{
		IncidentID:           "inc-1",
		Timestamp:            time.Now().UTC(),
		Cluster:              "local",
		Service:              "chat",
		PredictedFaultDomain: "provider_throttle",
		Confidence:           0.9,
		Evidence:             []Evidence{{Signal: "fault_label", Value: "provider_throttle", Source: "application"}},
		SLOImpact:            SLOImpact{SLI: "ttft_ms", BurnRate: 2.1, WindowMinutes: 5},
	}
	if err := ValidateAgainstSchema(schemaPath(t, "docs/contracts/v1/incident-attribution.schema.json"), incident); err != nil {
		t.Fatalf("schema validation failed: %v", err)
	}
}

func TestValidateProbeEventSchema(t *testing.T) {
	event := ProbeEventV1{
		TSUnixNano: time.Now().UTC().UnixNano(),
		Signal:     "dns_latency_ms",
		Node:       "kind-worker",
		Namespace:  "default",
		Pod:        "rag-service-0",
		Container:  "rag-service",
		PID:        1234,
		TID:        1234,
		ConnTuple: &ConnTuple{
			SrcIP:    "10.0.0.2",
			DstIP:    "10.0.0.53",
			SrcPort:  42424,
			DstPort:  53,
			Protocol: "udp",
		},
		Value:   23.5,
		Unit:    "ms",
		Status:  "ok",
		TraceID: "trace-123",
		SpanID:  "span-123",
	}
	if err := ValidateAgainstSchema(schemaPath(t, "docs/contracts/v1alpha1/probe-event.schema.json"), event); err != nil {
		t.Fatalf("schema validation failed: %v", err)
	}
}

func TestValidateToolkitConfigSchema(t *testing.T) {
	payloadBytes, err := os.ReadFile(schemaPath(t, "config/toolkit.yaml"))
	if err != nil {
		t.Fatalf("read toolkit yaml: %v", err)
	}
	var payload map[string]interface{}
	if err := yaml.Unmarshal(payloadBytes, &payload); err != nil {
		t.Fatalf("parse toolkit yaml: %v", err)
	}
	if err := ValidateAgainstSchema(schemaPath(t, "config/toolkit.schema.json"), payload); err != nil {
		t.Fatalf("toolkit config should validate: %v", err)
	}
}

func TestValidateToolkitConfigSchemaRejectsUnknownAndUnsupportedSignal(t *testing.T) {
	payload := map[string]interface{}{
		"apiVersion": "toolkit.llm-slo.dev/v1alpha1",
		"kind":       "ToolkitConfig",
		"signal_set": []interface{}{"dns_latency_ms", "not_supported_signal"},
		"sampling": map[string]interface{}{
			"events_per_second_limit": 1000,
			"burst_limit":             2000,
		},
		"correlation": map[string]interface{}{
			"window_ms": 2000,
		},
		"otlp": map[string]interface{}{
			"endpoint": "http://otel-collector:4317",
		},
		"safety": map[string]interface{}{
			"max_overhead_pct": 5,
		},
		"unexpected_section": map[string]interface{}{
			"enabled": true,
		},
	}
	err := ValidateAgainstSchema(schemaPath(t, "config/toolkit.schema.json"), payload)
	if err == nil {
		t.Fatalf("expected schema validation to fail")
	}
	if !strings.Contains(err.Error(), "unexpected_section") && !strings.Contains(err.Error(), "signal_set") {
		t.Fatalf("expected unknown key or signal validation errors, got: %v", err)
	}
}
