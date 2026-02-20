package toolkitcfg

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoad(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "toolkit.yaml")
	content := `
apiVersion: toolkit.llm-slo.dev/v1alpha1
kind: ToolkitConfig
signal_set:
  - dns_latency_ms
  - tcp_retransmits_total
sampling:
  events_per_second_limit: 500
  burst_limit: 1000
correlation:
  window_ms: 1500
otlp:
  endpoint: http://localhost:4317
safety:
  max_overhead_pct: 4
webhook:
  enabled: true
  url: https://hooks.example.dev/incident
  secret: test-secret
  format: opsgenie
  timeout_ms: 2500
cdgate:
  enabled: true
  prometheus_url: http://prometheus.monitoring:9090
  ttft_p95_ms: 900
  error_rate: 0.07
  burn_rate: 2.5
  fail_open: false
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write config: %v", err)
	}

	cfg, err := Load(path)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if cfg.Sampling.EventsPerSecondLimit != 500 {
		t.Fatalf("unexpected rate limit: %d", cfg.Sampling.EventsPerSecondLimit)
	}
	if cfg.Safety.MaxOverheadPct != 4 {
		t.Fatalf("unexpected overhead: %f", cfg.Safety.MaxOverheadPct)
	}
	if len(cfg.SignalSet) != 2 {
		t.Fatalf("unexpected signal count: %d", len(cfg.SignalSet))
	}
	if !cfg.Webhook.Enabled || cfg.Webhook.Format != "opsgenie" || cfg.Webhook.TimeoutMS != 2500 {
		t.Fatalf("unexpected webhook config: %+v", cfg.Webhook)
	}
	if !cfg.CDGate.Enabled || cfg.CDGate.PrometheusURL != "http://prometheus.monitoring:9090" {
		t.Fatalf("unexpected cdgate config: %+v", cfg.CDGate)
	}
	if cfg.CDGate.FailOpen {
		t.Fatalf("expected fail_open=false override to persist")
	}
}

func TestLoadDefaultsForV03Extensions(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "toolkit.yaml")
	content := `
apiVersion: toolkit.llm-slo.dev/v1alpha1
kind: ToolkitConfig
signal_set:
  - dns_latency_ms
sampling:
  events_per_second_limit: 10
  burst_limit: 20
correlation:
  window_ms: 200
otlp:
  endpoint: http://otel-collector:4317
safety:
  max_overhead_pct: 3
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write config: %v", err)
	}

	cfg, err := Load(path)
	if err != nil {
		t.Fatalf("load: %v", err)
	}

	if cfg.Webhook.Format != "generic" || cfg.Webhook.TimeoutMS != 5000 {
		t.Fatalf("unexpected webhook defaults: %+v", cfg.Webhook)
	}
	if cfg.CDGate.PrometheusURL != "http://prometheus:9090" {
		t.Fatalf("unexpected cdgate prometheus default: %+v", cfg.CDGate)
	}
	if cfg.CDGate.TTFTp95MS != 800 || cfg.CDGate.ErrorRate != 0.05 || cfg.CDGate.BurnRate != 2.0 || !cfg.CDGate.FailOpen {
		t.Fatalf("unexpected cdgate defaults: %+v", cfg.CDGate)
	}
	if len(Default().SignalSet) != 9 {
		t.Fatalf("default signal set expected 9, got %d", len(Default().SignalSet))
	}
}
