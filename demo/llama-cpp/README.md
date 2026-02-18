# llama.cpp Optional Backend (Fast Evidence)

This folder provides a minimal Kubernetes deployment for llama.cpp so `demo/rag-service` can run in `llama_cpp` backend mode.

## Deploy

```bash
kubectl apply -k demo/llama-cpp/k8s
kubectl -n default rollout status deployment/llama-cpp --timeout=600s
```

## Switch RAG Service Backend

```bash
kubectl -n default set env deployment/rag-service \
  LLM_BACKEND=llama_cpp \
  LLAMA_CPP_URL=http://llama-cpp.default.svc.cluster.local:8080
kubectl -n default rollout status deployment/rag-service --timeout=180s
```

## Notes
- CI should keep `LLM_BACKEND=stub` for deterministic performance tests.
- The model download URL in `deployment.yaml` is intentionally configurable; replace with a locally cached model mirror if needed.
