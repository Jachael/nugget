# Privacy & Data Handling

## Principles

Nugget is built with privacy-first principles:

1. **Minimal Data Collection** - Only collect what's necessary
2. **User Control** - Users own their data
3. **Transparency** - Clear about what we collect and why
4. **Security** - Industry-standard encryption and security practices

## Data We Collect

### User Authentication
- Apple ID subject identifier (appleSub)
- Internal user ID (generated)
- No email, name, or other PII from Apple

### User Content
- URLs and content users explicitly save
- Summaries and analysis (generated, not shared)
- Usage patterns (streak, session history)

### Technical Data
- API request logs (temporary, for debugging)
- Error logs (anonymized)

## Data We DO NOT Collect

- Precise location data
- Device identifiers (beyond what's implicit in standard logs)
- Browsing history outside of saved content
- Contacts or calendar data
- Photos or media (unless explicitly saved)

## Data Storage

- User data: DynamoDB (AWS eu-west-1)
- Authentication tokens: Keychain (iOS)
- All data encrypted at rest and in transit

## Data Sharing

- We do not sell or share user data
- LLM processing (AWS Bedrock) for summarization only
- No third-party analytics or tracking

## Data Retention

- User data retained while account is active
- Deleted accounts: data removed within 30 days
- Logs: retained for 90 days maximum

## User Rights

Users can:
- Export their data (future feature)
- Delete their account and all data
- Control what content they save

## Compliance

- GDPR considerations for EU users
- Following Apple App Store guidelines
- Regular security audits (planned)

## Contact

For privacy concerns: [Add contact email]
