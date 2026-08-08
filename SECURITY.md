# Security Policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub's **Security → Report a vulnerability** flow. Do not open a public issue containing credentials, Honeybadger response data, or exploit details.

## Supported versions

Security fixes are provided for the latest tagged release.

## Credential handling

`hb-read` expects a Honeybadger personal authentication token in an environment variable. Never commit tokens to this repository or include them in issue reports, test fixtures, screenshots, or command transcripts.
