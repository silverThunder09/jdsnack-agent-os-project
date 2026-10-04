$script:PathSelectedPrCheckNames = @(
    'Validate Agent OS docs'
    'Test and build backend'
    'Verify Flyway migrations on PostgreSQL'
    'Test and build frontend'
    'Build backend container'
    'Run compose smoke test'
    'Workflow CI'
)

function Test-SuccessfulConditionalPrCheckSkip {
    param(
        [string]$CheckName,
        [string]$Bucket
    )

    if ($Bucket -cne 'skipping') {
        return $false
    }
    return $CheckName -cin $script:PathSelectedPrCheckNames
}
