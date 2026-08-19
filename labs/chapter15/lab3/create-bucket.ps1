# The gcs backend does not create the bucket: "The bucket must exist prior to
# configuring the backend."
param([string]$Bucket = "tf-state-lab")

$endpoint = if ($env:FLOCI_GCP_ENDPOINT) { $env:FLOCI_GCP_ENDPOINT } else { "http://127.0.0.1:4588" }
$body = @{ name = $Bucket } | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri "$endpoint/storage/v1/b?project=floci-local" `
    -ContentType "application/json" -Body $body | Out-Null
Write-Host "created $Bucket"
