package benchmark

import (
	"encoding/json"
	"encoding/csv"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGenerateArtifacts(t *testing.T) {
	tmp := t.TempDir()
	if err := GenerateArtifacts(tmp, "provider_throttle", "rag_mixed"); err != nil {
		t.Fatalf("generate artifacts: %v", err)
	}

	required := []string{
		"attribution_summary.json",
		"confusion-matrix.csv",
		"incident_predictions.csv",
		"collector_overhead.csv",
		"provenance.json",
		"report.md",
	}
	for _, name := range required {
		if _, err := os.Stat(filepath.Join(tmp, name)); err != nil {
			t.Fatalf("missing artifact %s: %v", name, err)
		}
	}
}

func TestGenerateArtifactsRejectsUnsupportedScenario(t *testing.T) {
	tmp := t.TempDir()
	if err := GenerateArtifacts(tmp, "not_a_scenario", "rag_mixed"); err == nil {
		t.Fatal("expected unsupported scenario error")
	}
}

func TestGenerateArtifactsMixedFaultScenario(t *testing.T) {
	tmp := t.TempDir()
	if err := GenerateArtifacts(tmp, "mixed_faults", "rag_mixed"); err != nil {
		t.Fatalf("generate artifacts: %v", err)
	}

	rows := readCSVRows(t, filepath.Join(tmp, "confusion-matrix.csv"))
	content := strings.Join(rows, "|")
	if !strings.Contains(content, "network_dns") {
		t.Fatal("expected network_dns in confusion matrix")
	}
	if !strings.Contains(content, "provider_throttle") {
		t.Fatal("expected provider_throttle in confusion matrix")
	}
}

func TestGenerateArtifactsWithInputFixture(t *testing.T) {
	tmp := t.TempDir()
	inputPath := filepath.Join("testdata", "mixed_fault_samples.jsonl")
	if err := GenerateArtifactsWithInput(tmp, "provider_throttle", "rag_mixed", inputPath); err != nil {
		t.Fatalf("generate artifacts with input: %v", err)
	}

	rows := readCSVRows(t, filepath.Join(tmp, "incident_predictions.csv"))
	if len(rows) != 5 {
		t.Fatalf("expected 5 rows including header, got %d", len(rows))
	}
}

func TestGenerateArtifactsMixedMultiScenario(t *testing.T) {
	tmp := t.TempDir()
	if err := GenerateArtifacts(tmp, "mixed_multi", "rag_mixed"); err != nil {
		t.Fatalf("generate artifacts: %v", err)
	}

	required := []string{
		"attribution_summary.json",
		"confusion-matrix.csv",
		"incident_predictions.csv",
		"collector_overhead.csv",
		"provenance.json",
		"report.md",
	}
	for _, name := range required {
		if _, err := os.Stat(filepath.Join(tmp, name)); err != nil {
			t.Fatalf("missing artifact %s: %v", name, err)
		}
	}

	// mixed_multi should produce samples with multi-fault expected domains
	rows := readCSVRows(t, filepath.Join(tmp, "incident_predictions.csv"))
	if len(rows) < 2 {
		t.Fatal("expected at least 2 rows (header + data) in incident_predictions.csv")
	}
}

func TestGenerateArtifactsDefaultsReleaseGradeFromRunnerMode(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("RUNNER_MODE", "full-self-hosted-ebpf")
	t.Setenv("RELEASE_GRADE", "")
	if err := GenerateArtifacts(tmp, "provider_throttle", "rag_mixed"); err != nil {
		t.Fatalf("generate artifacts: %v", err)
	}

	summaryPath := filepath.Join(tmp, "attribution_summary.json")
	summaryBytes, err := os.ReadFile(summaryPath)
	if err != nil {
		t.Fatalf("read summary: %v", err)
	}
	var summary map[string]any
	if err := json.Unmarshal(summaryBytes, &summary); err != nil {
		t.Fatalf("unmarshal summary: %v", err)
	}
	if summary["runner_mode"] != "full-self-hosted-ebpf" {
		t.Fatalf("unexpected runner_mode: %v", summary["runner_mode"])
	}
	if summary["release_grade"] != true {
		t.Fatalf("expected release_grade=true, got %v", summary["release_grade"])
	}

	provenancePath := filepath.Join(tmp, "provenance.json")
	provBytes, err := os.ReadFile(provenancePath)
	if err != nil {
		t.Fatalf("read provenance: %v", err)
	}
	var provenance map[string]any
	if err := json.Unmarshal(provBytes, &provenance); err != nil {
		t.Fatalf("unmarshal provenance: %v", err)
	}
	if provenance["runner_mode"] != "full-self-hosted-ebpf" {
		t.Fatalf("unexpected provenance runner_mode: %v", provenance["runner_mode"])
	}
	if provenance["release_grade"] != true {
		t.Fatalf("expected provenance release_grade=true, got %v", provenance["release_grade"])
	}
}

func TestGenerateArtifactsReleaseGradeEnvOverride(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("RUNNER_MODE", "fallback-synthetic-no-self-hosted-ebpf")
	t.Setenv("RELEASE_GRADE", "true")
	if err := GenerateArtifacts(tmp, "provider_throttle", "rag_mixed"); err != nil {
		t.Fatalf("generate artifacts: %v", err)
	}

	summaryPath := filepath.Join(tmp, "attribution_summary.json")
	summaryBytes, err := os.ReadFile(summaryPath)
	if err != nil {
		t.Fatalf("read summary: %v", err)
	}
	var summary map[string]any
	if err := json.Unmarshal(summaryBytes, &summary); err != nil {
		t.Fatalf("unmarshal summary: %v", err)
	}
	if summary["runner_mode"] != "fallback-synthetic-no-self-hosted-ebpf" {
		t.Fatalf("unexpected runner_mode: %v", summary["runner_mode"])
	}
	if summary["release_grade"] != true {
		t.Fatalf("expected release_grade=true override, got %v", summary["release_grade"])
	}
}

func readCSVRows(t *testing.T, path string) []string {
	t.Helper()
	file, err := os.Open(path)
	if err != nil {
		t.Fatalf("open csv: %v", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	records, err := reader.ReadAll()
	if err != nil {
		t.Fatalf("read csv: %v", err)
	}

	rows := make([]string, 0, len(records))
	for _, record := range records {
		rows = append(rows, strings.Join(record, ","))
	}
	return rows
}
