package toolkitcfg

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// ToolkitConfig mirrors config/toolkit.yaml.
type ToolkitConfig struct {
	APIVersion  string            `yaml:"apiVersion"`
	Kind        string            `yaml:"kind"`
	SignalSet   []string          `yaml:"signal_set"`
	Sampling    SamplingConfig    `yaml:"sampling"`
	Correlation CorrelationConfig `yaml:"correlation"`
	OTLP        OTLPConfig        `yaml:"otlp"`
	Safety      SafetyConfig      `yaml:"safety"`
	Webhook     WebhookConfig     `yaml:"webhook"`
	CDGate      CDGateConfig      `yaml:"cdgate"`
}

// SamplingConfig controls event-rate limiting.
type SamplingConfig struct {
	EventsPerSecondLimit int `yaml:"events_per_second_limit"`
	BurstLimit           int `yaml:"burst_limit"`
}

// CorrelationConfig contains join-window tuning.
type CorrelationConfig struct {
	WindowMS int `yaml:"window_ms"`
}

// OTLPConfig contains collector endpoint settings.
type OTLPConfig struct {
	Endpoint string `yaml:"endpoint"`
}

// SafetyConfig configures runtime overhead limits.
type SafetyConfig struct {
	MaxOverheadPct float64 `yaml:"max_overhead_pct"`
}

// WebhookConfig configures incident webhook delivery.
type WebhookConfig struct {
	Enabled   bool   `yaml:"enabled"`
	URL       string `yaml:"url"`
	Secret    string `yaml:"secret"`
	Format    string `yaml:"format"`
	TimeoutMS int    `yaml:"timeout_ms"`
}

// CDGateConfig configures the CD SLO gate.
type CDGateConfig struct {
	Enabled       bool    `yaml:"enabled"`
	PrometheusURL string  `yaml:"prometheus_url"`
	TTFTp95MS     float64 `yaml:"ttft_p95_ms"`
	ErrorRate     float64 `yaml:"error_rate"`
	BurnRate      float64 `yaml:"burn_rate"`
	FailOpen      bool    `yaml:"fail_open"`
}

// Default returns v1alpha1 defaults.
func Default() ToolkitConfig {
	return ToolkitConfig{
		APIVersion: "toolkit.llm-slo.dev/v1alpha1",
		Kind:       "ToolkitConfig",
		SignalSet: []string{
			"dns_latency_ms",
			"tcp_retransmits_total",
			"runqueue_delay_ms",
			"connect_latency_ms",
			"tls_handshake_ms",
			"cpu_steal_pct",
			"mem_reclaim_latency_ms",
			"disk_io_latency_ms",
			"syscall_latency_ms",
		},
		Sampling: SamplingConfig{
			EventsPerSecondLimit: 10000,
			BurstLimit:           20000,
		},
		Correlation: CorrelationConfig{
			WindowMS: 2000,
		},
		OTLP: OTLPConfig{
			Endpoint: "http://otel-collector:4317",
		},
		Safety: SafetyConfig{
			MaxOverheadPct: 5,
		},
		Webhook: WebhookConfig{
			Enabled:   false,
			URL:       "",
			Secret:    "",
			Format:    "generic",
			TimeoutMS: 5000,
		},
		CDGate: CDGateConfig{
			Enabled:       false,
			PrometheusURL: "http://prometheus:9090",
			TTFTp95MS:     800,
			ErrorRate:     0.05,
			BurnRate:      2.0,
			FailOpen:      true,
		},
	}
}

// Load parses and normalizes a toolkit config file.
func Load(path string) (ToolkitConfig, error) {
	cfg := Default()
	data, err := os.ReadFile(path)
	if err != nil {
		return cfg, fmt.Errorf("read config %s: %w", path, err)
	}

	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return cfg, fmt.Errorf("unmarshal config %s: %w", path, err)
	}
	normalize(&cfg)
	return cfg, nil
}

func normalize(cfg *ToolkitConfig) {
	defaults := Default()

	if len(cfg.SignalSet) == 0 {
		cfg.SignalSet = defaults.SignalSet
	}
	if cfg.Sampling.EventsPerSecondLimit <= 0 {
		cfg.Sampling.EventsPerSecondLimit = defaults.Sampling.EventsPerSecondLimit
	}
	if cfg.Sampling.BurstLimit <= 0 {
		cfg.Sampling.BurstLimit = defaults.Sampling.BurstLimit
	}
	if cfg.Correlation.WindowMS <= 0 {
		cfg.Correlation.WindowMS = defaults.Correlation.WindowMS
	}
	if cfg.OTLP.Endpoint == "" {
		cfg.OTLP.Endpoint = defaults.OTLP.Endpoint
	}
	if cfg.Safety.MaxOverheadPct <= 0 {
		cfg.Safety.MaxOverheadPct = defaults.Safety.MaxOverheadPct
	}
	if cfg.Webhook.Format == "" {
		cfg.Webhook.Format = defaults.Webhook.Format
	}
	if cfg.Webhook.TimeoutMS <= 0 {
		cfg.Webhook.TimeoutMS = defaults.Webhook.TimeoutMS
	}
	if cfg.CDGate.PrometheusURL == "" {
		cfg.CDGate.PrometheusURL = defaults.CDGate.PrometheusURL
	}
	if cfg.CDGate.TTFTp95MS <= 0 {
		cfg.CDGate.TTFTp95MS = defaults.CDGate.TTFTp95MS
	}
	if cfg.CDGate.ErrorRate <= 0 {
		cfg.CDGate.ErrorRate = defaults.CDGate.ErrorRate
	}
	if cfg.CDGate.BurnRate <= 0 {
		cfg.CDGate.BurnRate = defaults.CDGate.BurnRate
	}
	if cfg.APIVersion == "" {
		cfg.APIVersion = defaults.APIVersion
	}
	if cfg.Kind == "" {
		cfg.Kind = defaults.Kind
	}
}
