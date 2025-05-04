#IP=localhost
#PORT=8000

IP=35.208.159.148
PORT=80

curl -i -X POST ${IP}:${PORT}/v1/completions -v \
-H 'Content-Type: application/json' \
-H 'Authorization: Bearer $(gcloud auth print-access-token)' \
-d '{ "model": "meta-llama/Meta-Llama-3-8B", "prompt": "why is the sky blue", "max_tokens": "128", "temperature": "1.0"  }'
