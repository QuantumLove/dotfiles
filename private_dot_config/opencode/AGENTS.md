# Global agent rules

## AWS authentication

When an AWS command fails with missing or expired credentials, do NOT ask the user
to log in. Run `aws-sso-login` (staging, default) or `aws-sso-login production`. In
headless/SSH environments it prints a device-authorization URL with the code
pre-filled — give that URL to the user and ask them to open it and approve the
sign-in; that is their only step. After approval the active profile is
`<env>-device`, so retry the failed command with `--profile <env>-device` (e.g.
`staging-device`).
